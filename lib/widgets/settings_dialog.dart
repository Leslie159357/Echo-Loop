/// 自由练习（全能播放器）播放设置面板
///
/// 底部弹窗，即时生效并持久化（非会话级）。
/// 设置项：自动播放下一句 + 句子重复（重复次数/间隔时间）+ 音频循环（循环次数）。
/// UI 风格与盲听 / 精听设置面板保持一致。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../providers/listening_practice/listening_practice_provider.dart';
import '../theme/app_theme.dart';

/// 显示自由练习播放设置面板（底部弹窗）。
Future<void> showSettingsSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => const SettingsSheet(),
  );
}

/// 设置面板内容组件（与盲听设置面板结构一致）。
class SettingsSheet extends ConsumerWidget {
  const SettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final playerState = ref.watch(listeningPracticeProvider);
    final controller = ref.read(listeningPracticeProvider.notifier);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l,
          AppSpacing.s,
          AppSpacing.l,
          AppSpacing.l,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 拖拽指示条
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.m),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.4,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // 标题
              Text(
                l10n.settings,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.l),

              _buildSentenceRepeatSettings(
                context,
                l10n,
                theme,
                playerState,
                controller,
              ),
              const SizedBox(height: AppSpacing.l),
              _buildAudioLoopSettings(
                context,
                l10n,
                theme,
                playerState,
                controller,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 自动播放下一句 + 句子重复设置区块。
  Widget _buildSentenceRepeatSettings(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    ListeningPracticeState playerState,
    ListeningPractice controller,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 自动播放下一句
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.autoPlayNextSentence,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Switch(
              value: playerState.settings.autoPlayNextSentenceEnabled,
              onChanged: (value) {
                controller.updateSettings(
                  playerState.settings.copyWith(
                    autoPlayNextSentenceEnabled: value,
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.l),

        // 句子重复
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.sentenceRepeat,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Switch(
              value: playerState.settings.loopEnabled,
              onChanged: (value) {
                controller.updateSettings(
                  playerState.settings.copyWith(loopEnabled: value),
                );
              },
            ),
          ],
        ),
        if (playerState.settings.loopEnabled)
          _buildSubSettingsGroup(theme, [
            // 重复次数
            _buildDropdownRow<int>(
              theme: theme,
              label: l10n.repeatCount,
              value: playerState.settings.loopCount,
              items: List.generate(20, (i) => i + 1)
                  .map(
                    (count) => DropdownMenuItem(
                      value: count,
                      child: Text('$count ${l10n.times}'),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  controller.updateSettings(
                    playerState.settings.copyWith(loopCount: value),
                  );
                }
              },
            ),
            const SizedBox(height: AppSpacing.s),
            // 间隔时间
            _buildDropdownRow<int>(
              theme: theme,
              label: l10n.intervalTime,
              value: playerState.settings.pauseInterval.inSeconds,
              items: List.generate(31, (i) => i)
                  .map(
                    (seconds) => DropdownMenuItem(
                      value: seconds,
                      child: Text('$seconds ${l10n.seconds}'),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  controller.updateSettings(
                    playerState.settings.copyWith(
                      pauseInterval: Duration(seconds: value),
                    ),
                  );
                }
              },
            ),
          ]),
      ],
    );
  }

  /// 音频循环设置区块。
  Widget _buildAudioLoopSettings(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    ListeningPracticeState playerState,
    ListeningPractice controller,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.audioLoop,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Switch(
              value: playerState.settings.loopAudioEnabled,
              onChanged: (value) {
                controller.updateSettings(
                  playerState.settings.copyWith(loopAudioEnabled: value),
                );
              },
            ),
          ],
        ),
        if (playerState.settings.loopAudioEnabled)
          _buildSubSettingsGroup(theme, [
            _buildDropdownRow<int>(
              theme: theme,
              label: l10n.loopTimes,
              value: playerState.settings.loopAudio,
              items: [
                ...List.generate(10, (i) => i + 1).map(
                  (count) => DropdownMenuItem(
                    value: count,
                    child: Text('$count ${l10n.times}'),
                  ),
                ),
                DropdownMenuItem(value: 0, child: Text(l10n.infiniteLoop)),
              ],
              onChanged: (value) {
                if (value != null) {
                  controller.updateSettings(
                    playerState.settings.copyWith(loopAudio: value),
                  );
                }
              },
            ),
          ]),
      ],
    );
  }

  /// 子设置项缩进容器：左缩进 + 左侧竖向连接线，表达从属于上方开关。
  ///
  /// 子项与顶层开关用相同的"标签 + 控件"行形态，仅靠缩进 + 竖线 + 标签降级
  /// 区分层级，避免引入卡片/背景色块破坏与盲听/精听面板的一致性。
  Widget _buildSubSettingsGroup(ThemeData theme, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.m),
      padding: const EdgeInsets.only(left: AppSpacing.m),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: theme.colorScheme.outlineVariant, width: 2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  /// 统一的"标签 + 下拉框"行（与盲听设置面板的下拉风格一致：无下划线）。
  ///
  /// 标签用 [TextTheme.bodyMedium] 常规字重，与顶层开关行的 titleSmall/w600
  /// 拉开视觉层级，配合缩进容器表达从属关系。
  Widget _buildDropdownRow<T>({
    required ThemeData theme,
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.bodyMedium),
        DropdownButton<T>(
          value: value,
          underline: const SizedBox.shrink(),
          menuMaxHeight: 300,
          items: items,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
