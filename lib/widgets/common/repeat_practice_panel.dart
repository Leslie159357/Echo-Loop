/// 跟读/复述页面共享的底部操作面板
///
/// 布局从上到下：
/// 1. 评分 badge（可选，点击播放录音）
/// 2. 中间区域（固定高度）：倒计时 / 录音按钮+状态标签 / 加载动画（互斥）
///    - 若提供 [fastForwardButton]，自动对齐到 PlaybackControls 的 next 按钮正上方
/// 3. 播放控制栏（上一个/播放暂停/下一个）
/// 4. 遍数 + 模式标签
///
/// 纯布局组件，不包含任何业务逻辑。
/// 用于跟读、难句补练、收藏复习、复述页面。
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import 'playback_controls.dart';
import '../practice/practice_play_count_label.dart';

/// 录音/倒计时区域固定高度（录音面板最高：24 状态 + 4 间距 + 56 按钮 + 16 底部 = 100）
const double kTurnAreaHeight = 100;

/// PlaybackControls 内部间距常量（prev 32 + gap 48 + center 56 + gap 48 = 184）
/// 用于将快进按钮与 next 按钮对齐。
const double _kPlaybackLeftSpacing = 32 + 48 + 56 + 48;

/// next 按钮宽度
const double _kNavButtonSize = 32;

/// 跟读/复述页面共享的底部操作面板
class RepeatPracticePanel extends StatelessWidget {
  /// 评分 badge（可选，显示在中间区域上方）
  final Widget? ratingBadge;

  /// 中间区域内容（录音按钮 / 倒计时 / 加载动画，由调用方决定显示哪个）
  final Widget centerContent;

  /// 快进按钮（可选，显示在 centerContent 右侧，与 next 按钮垂直对齐）
  final Widget? fastForwardButton;

  /// 是否可以返回上一个
  final bool canGoPrev;

  /// 是否为最后一个
  final bool isLast;

  /// 中间按钮图标（播放/暂停）
  final IconData centerIcon;

  /// 上一个回调
  final VoidCallback onPrevious;

  /// 下一个回调
  final VoidCallback onNext;

  /// 播放/暂停回调
  final VoidCallback onCenter;

  /// 预格式化的遍数文本（如 "第 1/3 遍"）
  final String playCountText;

  /// 是否为手动模式
  final bool isManualMode;

  /// 本地化
  final AppLocalizations l10n;

  /// 主题
  final ThemeData theme;

  const RepeatPracticePanel({
    super.key,
    this.ratingBadge,
    required this.centerContent,
    this.fastForwardButton,
    required this.canGoPrev,
    required this.isLast,
    required this.centerIcon,
    required this.onPrevious,
    required this.onNext,
    required this.onCenter,
    required this.playCountText,
    required this.isManualMode,
    required this.l10n,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.l,
        right: AppSpacing.l,
        bottom: AppSpacing.m,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 评分 badge
          if (ratingBadge != null)
            Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.s,
                bottom: AppSpacing.xs,
              ),
              child: Center(child: ratingBadge),
            ),

          // 中间区域（固定高度，避免布局跳动）
          SizedBox(
            height: kTurnAreaHeight,
            child: fastForwardButton != null
                ? _buildCenterWithFastForward()
                : centerContent,
          ),

          // 播放控制栏
          PlaybackControls(
            canGoPrev: canGoPrev,
            isLast: isLast,
            centerIcon: centerIcon,
            onPrevious: onPrevious,
            onNext: onNext,
            onCenter: onCenter,
          ),

          // 遍数 + 模式标签
          PracticePlayCountLabel(
            isManualMode: isManualMode,
            playCountText: playCountText,
            l10n: l10n,
            theme: theme,
          ),
        ],
      ),
    );
  }

  /// 倒计时居中 + 快进按钮与 PlaybackControls 的 next 按钮垂直对齐
  Widget _buildCenterWithFastForward() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // 倒计时/录音区域居中
        centerContent,
        // 快进按钮：用相同间距的 Row 让它落在 next 按钮正上方
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: _kPlaybackLeftSpacing),
            SizedBox(
              width: _kNavButtonSize,
              height: _kNavButtonSize,
              child: fastForwardButton,
            ),
          ],
        ),
      ],
    );
  }
}
