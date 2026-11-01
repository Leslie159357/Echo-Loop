import 'dart:async';

import '../models/word_highlight_binding.dart';

/// 将播放器事件转换为逐词高亮需要的生命周期状态。
class WordHighlightPlaybackStatusTracker {
  WordHighlightPlaybackStatus _status = WordHighlightPlaybackStatus.idle;
  bool _hasPlaybackStarted = false;
  bool _ignoreCurrentCompletion = false;
  final StreamController<WordHighlightPlaybackStatus> _statuses =
      StreamController<WordHighlightPlaybackStatus>.broadcast();

  /// 当前播放生命周期状态。
  WordHighlightPlaybackStatus get status => _status;

  /// 播放生命周期状态流。
  Stream<WordHighlightPlaybackStatus> get stream => _statuses.stream;

  /// 根据播放器当前状态区分自然结束与暂停。
  void observePlayerState({
    required bool isPlaying,
    required bool isCompleted,
  }) {
    if (isPlaying) {
      _ignoreCurrentCompletion = false;
      markPlaying();
      return;
    }
    if (isCompleted) {
      if (!_ignoreCurrentCompletion) markCompleted();
      return;
    }
    _ignoreCurrentCompletion = false;
    if (_status == WordHighlightPlaybackStatus.playing) {
      markPaused();
    }
  }

  /// 标记播放开始。
  void markPlaying() {
    _hasPlaybackStarted = true;
    _ignoreCurrentCompletion = false;
    _setStatus(WordHighlightPlaybackStatus.playing);
  }

  /// 标记手动暂停；completed 状态不会被播放器的迟到 pause 覆盖。
  void markPaused() {
    if (!_hasPlaybackStarted ||
        _status == WordHighlightPlaybackStatus.completed) {
      return;
    }
    _setStatus(WordHighlightPlaybackStatus.paused);
  }

  /// 用户显式定位后允许显示目标位置的词。
  void markPositionSelected({bool ignoreCurrentCompletion = false}) {
    _hasPlaybackStarted = true;
    _ignoreCurrentCompletion = ignoreCurrentCompletion;
    if (_status != WordHighlightPlaybackStatus.playing) {
      _setStatus(WordHighlightPlaybackStatus.paused);
    }
  }

  /// 开始配置新的播放区间时暂时关闭高亮，但保留“曾经开始播放”的事实。
  void prepareForPlayback() {
    _ignoreCurrentCompletion = false;
    _setStatus(WordHighlightPlaybackStatus.idle);
  }

  /// 标记自然播放结束。
  void markCompleted() {
    _hasPlaybackStarted = true;
    _ignoreCurrentCompletion = false;
    _setStatus(WordHighlightPlaybackStatus.completed);
  }

  /// 停止或切换材料时清除当前播放生命周期。
  void reset() {
    _hasPlaybackStarted = false;
    _ignoreCurrentCompletion = false;
    _setStatus(WordHighlightPlaybackStatus.idle);
  }

  /// 释放生命周期状态流。
  Future<void> dispose() => _statuses.close();

  void _setStatus(WordHighlightPlaybackStatus next) {
    if (_status == next) return;
    _status = next;
    if (!_statuses.isClosed) _statuses.add(next);
  }
}
