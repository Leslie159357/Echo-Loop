/// 确认操作通用对话框
///
/// 合并了删除音频、删除合集、退出确认、字幕替换确认等场景。
/// 支持普通确认和危险操作（红色按钮）两种样式。
library;

import 'package:flutter/material.dart';

/// 显示确认对话框
///
/// 返回 `true` 表示用户确认，`false` 或 `null` 表示取消。
///
/// [title] 对话框标题。
/// [message] 提示消息。
/// [icon] 标题栏图标（可选）。
/// [isDestructive] 是否为破坏性操作（确认按钮变红）。
/// [confirmLabel] 确认按钮文本。
/// [cancelLabel] 取消按钮文本。
Future<bool?> showConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  IconData? icon,
  bool isDestructive = false,
  required String confirmLabel,
  required String cancelLabel,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return AlertDialog(
        icon: icon != null
            ? Icon(
                icon,
                color: isDestructive ? theme.colorScheme.error : null,
                size: 32,
              )
            : null,
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(cancelLabel),
          ),
          if (isDestructive)
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
              child: Text(confirmLabel),
            )
          else
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(confirmLabel),
            ),
        ],
      );
    },
  );
}
