/// Overlay 弹窗工具
///
/// 使用 [Overlay] 替代 [Navigator] 显示弹窗，完全绕过 GoRouter 路由栈。
/// 解决 GoRouter + showDialog/showGeneralDialog 中 pop 弹窗时
/// 错误地将 pop 传递到底层 GoRoute 页面的问题。
library;

import 'dart:async';

import 'package:flutter/material.dart';

/// 使用 Overlay 显示弹窗
///
/// 弹窗的关闭通过移除 overlay entry + [Completer] 传递结果，
/// 完全绕过 GoRouter 路由栈。
///
/// [builder] 接收一个 `onResult` 回调，弹窗内部通过调用该回调返回结果并关闭。
/// [barrierDismissible] 为 true 时，点击外部区域关闭弹窗（返回 null）。
Future<T?> showOverlayDialog<T>({
  required BuildContext context,
  required Widget Function(void Function(T?) onResult) builder,
  bool barrierDismissible = true,
}) {
  final completer = Completer<T?>();
  late OverlayEntry entry;
  final overlay = Overlay.of(context);

  entry = OverlayEntry(
    builder: (_) => _OverlayDialogWrapper<T>(
      completer: completer,
      entry: entry,
      barrierDismissible: barrierDismissible,
      dialogBuilder: builder,
    ),
  );

  overlay.insert(entry);
  return completer.future;
}

/// Overlay 弹窗内部包装组件
///
/// 管理 fade 动画、barrier 点击、结果传递。
class _OverlayDialogWrapper<T> extends StatefulWidget {
  final Completer<T?> completer;
  final OverlayEntry entry;
  final bool barrierDismissible;
  final Widget Function(void Function(T?) onResult) dialogBuilder;

  const _OverlayDialogWrapper({
    required this.completer,
    required this.entry,
    required this.barrierDismissible,
    required this.dialogBuilder,
  });

  @override
  State<_OverlayDialogWrapper<T>> createState() =>
      _OverlayDialogWrapperState<T>();
}

class _OverlayDialogWrapperState<T> extends State<_OverlayDialogWrapper<T>>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;

  /// 是否已关闭，防止重复调用
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 关闭弹窗并传递结果
  ///
  /// 立即移除 overlay entry 并返回结果，不等淡出动画。
  /// 因为 caller 可能在收到结果后立刻 context.pop() 导航走，
  /// 若延迟移除，overlay entry 会残留在 root Overlay 上。
  void _close(T? result) {
    if (_closed) return;
    _closed = true;

    widget.entry.remove();
    if (!widget.completer.isCompleted) {
      widget.completer.complete(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: GestureDetector(
        // barrier 点击：关闭弹窗返回 null
        onTap: widget.barrierDismissible ? () => _close(null) : null,
        behavior: HitTestBehavior.opaque,
        child: ColoredBox(
          color: Colors.black54,
          child: Center(
            // 内层：阻止对话框区域的点击冒泡到 barrier
            child: GestureDetector(
              onTap: () {}, // 阻止冒泡
              child: widget.dialogBuilder(_close),
            ),
          ),
        ),
      ),
    );
  }
}
