/// 自由练习完成通用对话框
///
/// 合并了盲听、精听、跟读、难句补练等多个页面的自由练习完成对话框。
/// 简单的两按钮布局：「完成」和「再来一遍」。
///
/// 点击外部区域可关闭弹窗（返回 null），不会导致父路由被 pop。
/// 实现方式：使用 [Overlay] 替代 [Navigator]，同 [showStepCompleteDialog]。
library;

import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import 'overlay_dialog.dart';

/// 显示自由练习完成对话框
///
/// 返回 `true` 表示完成退出，`false` 表示再来一遍，`null` 表示点击外部关闭。
///
/// [title] 对话框标题。
/// [message] 完成消息（可选，如句数统计）。
/// [replayLabel] 自定义"再来一遍"按钮文本（默认使用 l10n.listenAgain）。
/// [doneLabel] 自定义"完成"按钮文本（默认使用 l10n.done）。
Future<bool?> showFreePlayCompleteDialog({
  required BuildContext context,
  required String title,
  String? message,
  String? replayLabel,
  String? doneLabel,
}) {
  // 使用 Overlay 替代 Navigator 显示弹窗，完全绕过 GoRouter 路由栈
  return showOverlayDialog<bool>(
    context: context,
    builder: (onResult) => FreePlayCompleteDialog(
      onResult: onResult,
      title: title,
      message: message,
      replayLabel: replayLabel,
      doneLabel: doneLabel,
    ),
  );
}

/// 自由练习完成对话框组件
class FreePlayCompleteDialog extends StatelessWidget {
  /// 对话框标题
  final String title;

  /// 完成消息（可选）
  final String? message;

  /// 自定义"再来一遍"按钮文本
  final String? replayLabel;

  /// 自定义"完成"按钮文本
  final String? doneLabel;

  /// 结果回调，替代 Navigator.pop 传递结果
  final void Function(bool?) onResult;

  const FreePlayCompleteDialog({
    super.key,
    required this.onResult,
    required this.title,
    this.message,
    this.replayLabel,
    this.doneLabel,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.s),
            Flexible(child: Text(title)),
          ],
        ),
        content: message != null
            ? Text(message!, style: theme.textTheme.bodyMedium)
            : null,
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => onResult(true),
                  child: Text(doneLabel ?? l10n.done),
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: FilledButton(
                  onPressed: () => onResult(false),
                  child: Text(replayLabel ?? l10n.listenAgain),
                ),
              ),
            ],
          ),
        ],
    );
  }
}
