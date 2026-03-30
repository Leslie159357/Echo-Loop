/// 练习页面共享的遍数标签
///
/// 显示当前遍数/目标遍数。
/// 手动模式下 Opacity 隐藏（保留占位），盲听单遍也显示。
/// 用于难句补练和收藏复习。
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/learning_session/review_difficult_practice_provider.dart';
import '../../theme/app_theme.dart';

/// 遍数标签
class PracticePlayCountLabel extends StatelessWidget {
  /// 播放状态
  final ReviewDifficultPracticeState playerState;

  /// 本地化
  final AppLocalizations l10n;

  /// 主题
  final ThemeData theme;

  const PracticePlayCountLabel({
    super.key,
    required this.playerState,
    required this.l10n,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final targetCount = playerState.isAnnotationMode
        ? playerState.targetRepeatCount
        : (playerState.isManualMode
              ? 1
              : playerState.settings.blindListenRepeatCount);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.m),
      child: Opacity(
        opacity: playerState.isManualMode ? 0 : 1,
        child: Text(
          l10n.listenAndRepeatPlayCount(
            playerState.currentPlayCount,
            targetCount,
          ),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}
