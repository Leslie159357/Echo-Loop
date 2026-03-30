/// 意群快捷操作工具条
///
/// 浮动在 badge 上方，简洁的图标按钮样式。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 意群快捷操作工具条
///
/// 方形圆角深色背景，横排图标按钮（收藏 + 复制）。
class SenseGroupActionBar extends StatelessWidget {
  /// 是否已收藏
  final bool isSaved;

  /// 收藏/取消收藏回调
  final VoidCallback onToggleSave;

  /// 复制回调
  final VoidCallback onCopy;

  const SenseGroupActionBar({
    super.key,
    required this.isSaved,
    required this.onToggleSave,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = theme.colorScheme.inverseSurface;
    final fgColor = theme.colorScheme.onInverseSurface;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ActionIcon(
              icon: isSaved
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_outline_rounded,
              color: isSaved ? Colors.amber : fgColor,
              onTap: onToggleSave,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(8),
              ),
            ),
            SizedBox(
              height: 20,
              child: VerticalDivider(
                width: 1,
                color: fgColor.withValues(alpha: 0.2),
              ),
            ),
            _ActionIcon(
              icon: Icons.copy_rounded,
              color: fgColor,
              onTap: onCopy,
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 工具条内的单个图标按钮
class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final BorderRadius borderRadius;

  const _ActionIcon({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: borderRadius,
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}
