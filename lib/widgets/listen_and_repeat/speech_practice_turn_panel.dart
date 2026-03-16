/// 跟读回合状态面板（共享组件）
///
/// 录音状态面板：状态文字 + 录音按钮 + reviewCountdown 倒计时。
/// 跟读页面和难句补练页面共用。
library;

import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/listen_and_repeat_turn_controller_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/countdown_chip.dart';
import '../../widgets/listen_and_repeat/speech_record_button.dart';

/// 跟读回合状态面板。
class SpeechPracticeTurnPanel extends StatelessWidget {
  final AppLocalizations l10n;
  final ListenAndRepeatTurnState turnState;
  final bool isRecordingCurrent;
  final VoidCallback onRecordTap;
  final VoidCallback onFastForward;
  final VoidCallback onCountdownTap;

  const SpeechPracticeTurnPanel({
    super.key,
    required this.l10n,
    required this.turnState,
    required this.isRecordingCurrent,
    required this.onRecordTap,
    required this.onFastForward,
    required this.onCountdownTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // reviewCountdown：倒计时按钮居中（与录音按钮同位置同大小），右侧快进图标
    if (turnState.phase == ListenAndRepeatTurnPhase.reviewCountdown) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 24 + AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 左侧占位，与右侧快进按钮等宽，保持倒计时居中
              const SizedBox(width: 32),
              const SizedBox(width: 48),
              CountdownChip(
                remaining: turnState.reviewCountdownRemaining,
                total: const Duration(seconds: 5),
                isPaused: turnState.isReviewCountdownPaused,
                onTap: onCountdownTap,
              ),
              const SizedBox(width: 48),
              // 与下方"下一句"按钮同列对齐
              GestureDetector(
                onTap: onFastForward,
                child: Icon(
                  Icons.fast_forward_rounded,
                  size: 32,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // 其余阶段统一布局：状态文字 + 录音按钮
    final statusText = _statusText(turnState.phase);
    final isProcessing =
        turnState.phase == ListenAndRepeatTurnPhase.processing;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 状态区：固定高度，显示当前状态文字
        SizedBox(
          height: 24,
          child: statusText != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isProcessing)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    Text(
                      statusText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                )
              : null,
        ),
        const SizedBox(height: AppSpacing.xs),
        // 录音按钮：processing 时禁用（灰显），其他阶段正常
        IgnorePointer(
          ignoring: isProcessing,
          child: Opacity(
            opacity: isProcessing ? 0.45 : 1.0,
            child: SpeechRecordButton(
              phase: switch (turnState.phase) {
                // idle / processing 显示蓝色待录音态
                // 只有 awaitingSpeech / speaking 才显示红色录音态
                ListenAndRepeatTurnPhase.idle ||
                ListenAndRepeatTurnPhase.processing =>
                  ListenAndRepeatTurnPhase.waitingForUser,
                final p => p,
              },
              onTap: onRecordTap,
            ),
          ),
        ),
      ],
    );
  }

  /// 根据阶段返回状态文字，null 表示不显示。
  String? _statusText(ListenAndRepeatTurnPhase phase) {
    return switch (phase) {
      ListenAndRepeatTurnPhase.idle => l10n.listenAndRepeatTapToRecord,
      ListenAndRepeatTurnPhase.awaitingSpeech =>
        l10n.listenAndRepeatRecordingInProgress,
      ListenAndRepeatTurnPhase.speaking =>
        l10n.listenAndRepeatRecordingInProgress,
      ListenAndRepeatTurnPhase.processing => l10n.listenAndRepeatAnalyzing,
      ListenAndRepeatTurnPhase.waitingForUser =>
        l10n.listenAndRepeatTapToRecord,
      ListenAndRepeatTurnPhase.reviewCountdown => null,
    };
  }
}
