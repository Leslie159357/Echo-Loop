/// 屏幕常亮 Mixin（含空闲超时自动关屏）
///
/// 用于学习播放器页面，防止用户学习时屏幕自动熄灭。
/// 混入到 State 后，页面显示时自动启用常亮，页面销毁时自动关闭。
///
/// 空闲超时机制：
/// - 默认 10 分钟无用户触摸 → 关闭常亮 → 系统自动熄屏
/// - 用户再次触摸时自动恢复常亮
/// - 可通过 [shortenIdleTimeout] 缩短超时（如学习完成后设为 5 分钟）
///
/// 使用方法：
/// 1. `class _MyScreenState extends State<MyScreen> with WakelockMixin`
/// 2. 在 `build()` 中用 `wakelockBody(child: ...)` 包裹内容
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// 屏幕常亮 Mixin（含空闲超时自动关屏）
///
/// 在 [initState] 时启用屏幕常亮，在 [dispose] 时关闭。
/// 每 30 秒检查一次空闲状态，超时后自动关闭常亮。
mixin WakelockMixin<T extends StatefulWidget> on State<T> {
  /// 空闲检查定时器
  Timer? _idleCheckTimer;

  /// 最后一次用户触摸时间
  DateTime _lastActivityTime = DateTime.now();

  /// 是否因空闲已关闭常亮
  bool _wakelockDisabledByIdle = false;

  /// 默认空闲超时（分钟）
  static const _defaultIdleTimeoutMinutes = 10;

  /// 空闲检查间隔（秒）
  static const _idleCheckIntervalSeconds = 30;

  /// 当前空闲超时（分钟），可通过 [shortenIdleTimeout] 缩短
  int _currentIdleTimeoutMinutes = _defaultIdleTimeoutMinutes;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _lastActivityTime = DateTime.now();
    _idleCheckTimer = Timer.periodic(
      const Duration(seconds: _idleCheckIntervalSeconds),
      (_) => _checkIdle(),
    );
  }

  @override
  void dispose() {
    _idleCheckTimer?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  /// 缩短空闲超时（如学习完成后设为 5 分钟加速关屏）
  void shortenIdleTimeout(int minutes) {
    _currentIdleTimeoutMinutes = minutes;
  }

  /// 包裹 Screen 内容，检测触摸以重置空闲计时
  ///
  /// 使用 [Listener] 而非 [GestureDetector]，不拦截子 widget 手势。
  /// 在 `build()` 中调用：`return wakelockBody(child: yourContent);`
  Widget wakelockBody({required Widget child}) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _onUserActivity(),
      child: child,
    );
  }

  /// 用户触摸时重置空闲计时，若已因空闲关闭则重新开启常亮
  void _onUserActivity() {
    _lastActivityTime = DateTime.now();
    if (_wakelockDisabledByIdle) {
      _wakelockDisabledByIdle = false;
      WakelockPlus.enable();
    }
  }

  /// 检查空闲状态，超时则关闭常亮
  void _checkIdle() {
    if (_wakelockDisabledByIdle) return;
    final idleMinutes = DateTime.now().difference(_lastActivityTime).inMinutes;
    if (idleMinutes >= _currentIdleTimeoutMinutes) {
      _wakelockDisabledByIdle = true;
      WakelockPlus.disable();
    }
  }
}
