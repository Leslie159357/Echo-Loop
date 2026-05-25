/// 问卷单选项卡片。
///
/// 左对齐布局：可选 emoji + 标签 + 选中态尾部 ✓ 标记。
/// 选中态用 #E8F1FB 柔和背景 + 2px primary 边框 + primary 色文字四重区分。
library;

import 'package:flutter/material.dart';

class SurveyChoiceTile extends StatelessWidget {
  const SurveyChoiceTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.leading,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// 选项左侧的可选装饰 Widget（emoji / 品牌图标等）。为 null 时不渲染该 slot。
  final Widget? leading;

  static const _borderColor = Color(0xFFE2E8F0);
  static const _selectedBg = Color(0xFFE8F1FB);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final bgColor = selected ? _selectedBg : colorScheme.surface;
    final borderColor = selected ? colorScheme.primary : _borderColor;
    final textColor = selected ? colorScheme.primary : colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            constraints: const BoxConstraints(minHeight: 60),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: selected ? 2 : 1),
            ),
            child: Row(
              children: [
                if (leading != null) ...[
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Center(child: leading),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    label,
                    style: textTheme.bodyLarge?.copyWith(
                      fontSize: 16,
                      height: 1.3,
                      color: textColor,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
                if (selected)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
