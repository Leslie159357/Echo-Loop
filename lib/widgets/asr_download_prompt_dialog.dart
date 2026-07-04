/// 录音入口前置弹窗：在进入录音页面前阻塞式检查本地 ASR 是否就绪。
///
/// 本文件只负责“是否允许继续进入录音流程”的前置判断；
/// 真正进入录音页面后，不再额外弹本地 ASR 守卫 UI。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/enums.dart';
import '../l10n/app_localizations.dart';
import '../providers/learning_settings_provider.dart';
import '../providers/offline_asr_settings_provider.dart';
import '../services/asr/asr_model_manager.dart';
import '../services/download/download_failure.dart';
import '../utils/download_failure_message.dart';

/// 判断某个学习子阶段是否会进入依赖本地 ASR 的录音流程。
bool requiresAsrBeforeEnteringSubStage(
  SubStageType subStage, {
  bool listenAndRepeatRatingEnabled = true,
  bool retellRatingEnabled = true,
}) {
  return switch (subStage) {
    SubStageType.listenAndRepeat => listenAndRepeatRatingEnabled,
    SubStageType.reviewDifficultPractice => listenAndRepeatRatingEnabled,
    SubStageType.retell => retellRatingEnabled,
    SubStageType.reviewRetellParagraph => retellRatingEnabled,
    SubStageType.reviewRetellSummary => retellRatingEnabled,
    _ => false,
  };
}

/// 在进入语音练习前检查本地 ASR 是否已就绪。
///
/// 返回：
/// - `true`：允许继续原本的进入动作
/// - `false`：用户取消，本次停留在当前页
Future<bool> ensureAsrReadyBeforeSpeechPractice(
  BuildContext context,
  WidgetRef ref,
) async {
  final state = ref.read(offlineAsrSettingsProvider);

  // 非 offline 后端 → 不需要检查 Whisper 模型。
  if (state.backend != AsrBackend.offline) {
    return true;
  }

  if (state.downloadStatus == AsrModelDownloadStatus.downloaded) {
    // 后台异步加载引擎，不阻塞进入学习页面
    unawaited(_ensureEngineLoaded(ref));
    return true;
  }

  if (state.isDownloading) {
    return _showDownloadProgressDialog(context, ref, startDownload: false);
  }

  if (state.downloadStatus == AsrModelDownloadStatus.failed) {
    return _showRepairPrompt(context, ref);
  }

  return _showEnableDownloadPrompt(context, ref);
}

/// 仅在目标子阶段依赖本地 ASR 时执行前置检查。
Future<bool> ensureAsrReadyForSubStage(
  BuildContext context,
  WidgetRef ref,
  SubStageType subStage,
) async {
  final settings = ref.read(learningSettingsProvider);
  if (!requiresAsrBeforeEnteringSubStage(
    subStage,
    listenAndRepeatRatingEnabled: settings.listenAndRepeatRatingEnabled,
    retellRatingEnabled: settings.retellRatingEnabled,
  )) {
    return true;
  }
  return ensureAsrReadyBeforeSpeechPractice(context, ref);
}

/// 后台加载引擎（fire-and-forget，不阻塞 UI）。
Future<void> _ensureEngineLoaded(WidgetRef ref) async {
  final state = ref.read(offlineAsrSettingsProvider);
  if (state.backend == AsrBackend.offline &&
      state.downloadStatus == AsrModelDownloadStatus.downloaded &&
      !state.engineReady) {
    await ref.read(offlineAsrSettingsProvider.notifier).loadEngine();
  }
}

Future<bool> _showEnableDownloadPrompt(
  BuildContext context,
  WidgetRef ref,
) async {
  final shouldDownload = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => const _EnableDownloadPromptDialog(),
  );

  if (shouldDownload == true && context.mounted) {
    return _showDownloadProgressDialog(context, ref, startDownload: true);
  }

  // 用户选择"暂不启用"：仅阻止本次进入，不修改设置。
  // 下次进入练习时会再次提示下载。
  return false;
}

Future<bool> _showRepairPrompt(BuildContext context, WidgetRef ref) async {
  final state = ref.read(offlineAsrSettingsProvider);
  final shouldDownload = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _RepairPromptDialog(
      isFailed: state.downloadStatus == AsrModelDownloadStatus.failed,
    ),
  );

  if (shouldDownload != true || !context.mounted) return false;
  return _showDownloadProgressDialog(context, ref, startDownload: true);
}

/// 下载进度弹窗（阻塞式）。
Future<bool> _showDownloadProgressDialog(
  BuildContext context,
  WidgetRef ref, {
  required bool startDownload,
}) async {
  final notifier = ref.read(offlineAsrSettingsProvider.notifier);
  if (startDownload) {
    notifier.enable();
  }

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => const _DownloadProgressDialog(),
  );

  if (result == true) {
    await _ensureEngineLoaded(ref);
    return true;
  }
  return false;
}

class _EnableDownloadPromptDialog extends ConsumerWidget {
  const _EnableDownloadPromptDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      titlePadding: EdgeInsets.zero,
      title: _DialogTitle(
        title: l10n.speechRecognitionRequiredTitle,
        onClose: () => Navigator.of(context).pop(),
      ),
      content: Text(l10n.speechRecognitionRequiredMessage),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.downloadNow),
        ),
      ],
    );
  }
}

class _RepairPromptDialog extends ConsumerWidget {
  final bool isFailed;

  const _RepairPromptDialog({required this.isFailed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      titlePadding: EdgeInsets.zero,
      title: _DialogTitle(
        title: isFailed
            ? l10n.speechModelDownloadFailed
            : l10n.speechModelRepairTitle,
        onClose: () => Navigator.of(context).pop(),
      ),
      content: Text(
        isFailed
            ? l10n.speechModelRepairMessage
            : l10n.speechModelRepairMessage,
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(isFailed ? l10n.retryDownload : l10n.downloadNow),
        ),
      ],
    );
  }
}

class _DownloadProgressDialog extends ConsumerWidget {
  const _DownloadProgressDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(offlineAsrSettingsProvider);

    if (state.isOfflineReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).pop(true);
      });
    }

    final isFailed = state.downloadStatus == AsrModelDownloadStatus.failed;

    return AlertDialog(
      titlePadding: EdgeInsets.zero,
      title: _DialogTitle(
        title: isFailed
            ? l10n.speechModelDownloadFailed
            : l10n.downloadingSpeechModel,
        onClose: () => Navigator.of(context).pop(),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isFailed)
            Text(
              l10n.speechRecognitionRequiredMessage,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          if (state.isDownloading) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(value: state.downloadProgress),
            const SizedBox(height: 8),
            Text(
              '${(state.downloadProgress * 100).toStringAsFixed(0)}%',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          // 标题已是通用「下载失败」，仅当原因确定时再补一行具体指引（unknown 不重复）。
          if (isFailed &&
              state.downloadError != null &&
              state.downloadError != DownloadFailureKind.unknown) ...[
            const SizedBox(height: 8),
            Text(
              downloadFailureMessage(l10n, state.downloadError),
              style: const TextStyle(color: Colors.red),
            ),
          ],
        ],
      ),
      actions: state.downloadStatus == AsrModelDownloadStatus.failed
          ? [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.notNow),
              ),
              FilledButton(
                onPressed: () => ref
                    .read(offlineAsrSettingsProvider.notifier)
                    .retryDownload(),
                child: Text(l10n.retryDownload),
              ),
            ]
          : const [],
    );
  }
}

class _DialogTitle extends StatelessWidget {
  final String title;
  final VoidCallback onClose;

  const _DialogTitle({required this.title, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 标题文字，右侧留出关闭按钮的空间
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 48, 0),
          child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
        ),
        // 关闭按钮固定在右上角
        Positioned(
          top: 8,
          right: 8,
          child: IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close, size: 20),
            style: IconButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(32, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          ),
        ),
      ],
    );
  }
}
