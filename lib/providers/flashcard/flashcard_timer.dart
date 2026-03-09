/// Flashcard 倒计时工具类
///
/// 纯 Dart 实现，不依赖 Flutter/Riverpod。
/// 每秒回调一次，支持暂停/恢复/重置。
library;

import 'dart:async';

/// 倒计时到期回调
typedef TimerExpiredCallback = void Function();

/// 倒计时每秒 tick 回调（剩余秒数）
typedef TimerTickCallback = void Function(int remaining);

/// Flashcard 倒计时器
class FlashcardTimer {
  Timer? _timer;
  int _remaining = 0;
  int _total = 0;
  bool _isPaused = false;

  /// 当前剩余秒数
  int get remaining => _remaining;

  /// 总倒计时秒数
  int get total => _total;

  /// 是否正在运行
  bool get isRunning => _timer != null && _timer!.isActive && !_isPaused;

  /// 是否已暂停
  bool get isPaused => _isPaused;

  /// 启动倒计时
  ///
  /// [seconds] 倒计时总秒数
  /// [onTick] 每秒回调
  /// [onExpired] 到期回调
  void start({
    required int seconds,
    required TimerTickCallback onTick,
    required TimerExpiredCallback onExpired,
  }) {
    cancel();
    _total = seconds;
    _remaining = seconds;
    _isPaused = false;

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _remaining--;
      onTick(_remaining);
      if (_remaining <= 0) {
        cancel();
        onExpired();
      }
    });
  }

  /// 暂停倒计时
  void pause() {
    if (_timer == null || _isPaused) return;
    _isPaused = true;
    _timer?.cancel();
    _timer = null;
  }

  /// 恢复倒计时
  void resume({
    required TimerTickCallback onTick,
    required TimerExpiredCallback onExpired,
  }) {
    if (!_isPaused || _remaining <= 0) return;
    _isPaused = false;

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _remaining--;
      onTick(_remaining);
      if (_remaining <= 0) {
        cancel();
        onExpired();
      }
    });
  }

  /// 取消倒计时
  void cancel() {
    _timer?.cancel();
    _timer = null;
    _isPaused = false;
  }

  /// 重置倒计时（不自动开始）
  void reset() {
    cancel();
    _remaining = 0;
    _total = 0;
  }
}
