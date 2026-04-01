/// 倒计时控制按钮（共享组件）
///
/// 56×56 圆形按钮，外围带进度环，内部显示倒计时秒数，
/// 右下角显示暂停/恢复小徽章。点击可暂停/恢复倒计时。
///
/// 可选 [onFastForward]：传入后在右侧显示快进按钮。
library;

import 'package:flutter/material.dart';
import 'tappable_wrapper.dart';

/// 倒计时控制按钮
///
/// 圆形按钮，外围带进度环，内部显示倒计时秒数，点击可暂停/恢复。
/// 传入 [onFastForward] 时右侧显示快进按钮。
class CountdownChip extends StatelessWidget {
  /// 倒计时剩余时间
  final Duration remaining;

  /// 倒计时总时长
  final Duration total;

  /// 是否已暂停
  final bool isPaused;

  /// 点击倒计时圆环回调（暂停/恢复）
  final VoidCallback onTap;

  /// 快进回调（可选，传入后显示快进按钮）
  final VoidCallback? onFastForward;

  const CountdownChip({
    super.key,
    required this.remaining,
    required this.total,
    required this.isPaused,
    required this.onTap,
    this.onFastForward,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalMs = total.inMilliseconds;
    final remainingMs = remaining.inMilliseconds;
    final progress = totalMs > 0 ? 1.0 - (remainingMs / totalMs) : 1.0;
    final seconds = (remainingMs / 1000).ceil();

    final chip = TappableWrapper(
      onTap: onTap,
      feedbackType: TapFeedback.scale,
      scaleDown: 0.90,
      child: SizedBox(
        width: 56,
        height: 56,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                strokeWidth: 3,
                strokeCap: StrokeCap.round,
                backgroundColor: theme.colorScheme.primary.withValues(
                  alpha: 0.12,
                ),
                valueColor: AlwaysStoppedAnimation(
                  theme.colorScheme.primary.withValues(alpha: 0.6),
                ),
              ),
            ),
            // 倒计时数字始终居中显示
            Text(
              '$seconds',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            // 右下角状态徽章：暂停时 play，倒计时中 pause
            Positioned(
              right: 2,
              bottom: 2,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primaryContainer,
                  border: Border.all(color: theme.colorScheme.surface),
                ),
                child: Icon(
                  isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  size: 12,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (onFastForward == null || isPaused) return chip;

    // 倒计时居中，快进按钮在右侧
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        chip,
        Positioned(
          right: -80,
          child: GestureDetector(
            onTap: onFastForward,
            child: Icon(
              Icons.fast_forward_rounded,
              size: 32,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
      ],
    );
  }
}
