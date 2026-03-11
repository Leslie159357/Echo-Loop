/// 环形学习进度图标
///
/// 根据学习进度显示不同状态：
/// - 未学习：音频图标 + 灰色背景
/// - 进行中：环形进度 + 蓝色音频图标
/// - 已完成：满环 + 绿色对勾
library;

import 'package:flutter/material.dart';
import '../models/learning_progress.dart';

/// 环形学习进度图标组件
///
/// 用于 [AudioListTile] 和学习页面 [_TaskCard] 等位置，
/// 统一展示音频的学习进度状态。
class LearningProgressIcon extends StatelessWidget {
  /// 学习进度数据，为 null 表示未学习
  final LearningProgress? progress;

  /// 图标整体尺寸
  final double size;

  /// 中央图标尺寸
  final double iconSize;

  /// 环形进度条宽度
  final double strokeWidth;

  const LearningProgressIcon({
    super.key,
    this.progress,
    this.size = 40.0,
    this.iconSize = 20.0,
    this.strokeWidth = 3.0,
  });

  /// 已完成状态的绿色
  static const completedColor = Color(0xFF4CAF50);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 未学习状态
    if (progress == null || !progress!.isStarted) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: theme.colorScheme.surfaceContainerHighest,
        ),
        child: Icon(
          Icons.audiotrack,
          size: iconSize,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    // 已完成状态
    if (progress!.isCompleted) {
      return SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                value: 1.0,
                strokeWidth: strokeWidth,
                color: completedColor,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
            Icon(Icons.check, size: iconSize, color: completedColor),
          ],
        ),
      );
    }

    // 进行中状态
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: progress!.progressPercent,
              strokeWidth: strokeWidth,
              color: theme.colorScheme.primary,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          Icon(
            Icons.audiotrack,
            size: iconSize,
            color: theme.colorScheme.primary,
          ),
        ],
      ),
    );
  }
}
