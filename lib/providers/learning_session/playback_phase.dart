/// 播放阶段状态机（sealed class）
///
/// 用类型安全的 sealed class 替代布尔标志组合，
/// 使无效状态在类型层面不可表达。
///
/// 每个子类代表播放器的一个**互斥阶段**，只携带该阶段相关的数据。
/// UI 层通过 pattern matching 处理各阶段，Dart exhaustive switch 保证不遗漏。
///
/// 使用示例：
/// ```dart
/// switch (state.phase) {
///   case IdlePhase(:final stepFinished): ...
///   case PlayingPhase(:final playCount): ...
///   case RepeatPausePhase(:final countdown): ...
///   case AdvancePausePhase(:final countdown): ...
///   case PostEvalPausePhase(:final countdown): ...
/// }
/// ```
library;

/// 倒计时状态
///
/// 嵌入在带有倒计时的阶段中，集中管理倒计时相关字段。
class CountdownState {
  /// 剩余时间
  final Duration remaining;

  /// 总时长
  final Duration total;

  /// 是否暂停中（用户主动点击暂停按钮）
  final bool isPaused;

  /// 是否快进中（10 倍速）
  final bool isFastForward;

  /// 是否因用户交互临时挂起（不显示倒计时，交互结束后重新开始）
  ///
  /// 与 isPaused 的区别：
  /// - isPaused：用户主动暂停，倒计时 UI 仍显示
  /// - isSuspended：交互触发的临时隐藏，倒计时 UI 不显示
  final bool isSuspended;

  const CountdownState({
    this.remaining = Duration.zero,
    this.total = Duration.zero,
    this.isPaused = false,
    this.isFastForward = false,
    this.isSuspended = false,
  });

  CountdownState copyWith({
    Duration? remaining,
    Duration? total,
    bool? isPaused,
    bool? isFastForward,
    bool? isSuspended,
  }) {
    return CountdownState(
      remaining: remaining ?? this.remaining,
      total: total ?? this.total,
      isPaused: isPaused ?? this.isPaused,
      isFastForward: isFastForward ?? this.isFastForward,
      isSuspended: isSuspended ?? this.isSuspended,
    );
  }
}

/// 播放阶段基类
sealed class PlaybackPhase {
  const PlaybackPhase();
}

/// 空闲阶段：未播放，等待启动或已完成
class IdlePhase extends PlaybackPhase {
  /// 当前步骤是否自然完成（所有句子播完）
  final bool stepFinished;

  const IdlePhase({this.stepFinished = false});
}

/// 播放中阶段：音频正在播放
class PlayingPhase extends PlaybackPhase {
  /// 当前遍数（1-based，"第N遍"）
  final int playCount;

  const PlayingPhase({required this.playCount});
}

/// 遍间停顿阶段：同一句子的两次播放之间
///
/// 跟读场景中，用户在此阶段进行跟读录音。
class RepeatPausePhase extends PlaybackPhase {
  /// 已完成的遍数
  final int completedPlayCount;

  /// 倒计时状态
  final CountdownState countdown;

  const RepeatPausePhase({
    required this.completedPlayCount,
    this.countdown = const CountdownState(),
  });

  RepeatPausePhase copyWith({
    int? completedPlayCount,
    CountdownState? countdown,
  }) {
    return RepeatPausePhase(
      completedPlayCount: completedPlayCount ?? this.completedPlayCount,
      countdown: countdown ?? this.countdown,
    );
  }
}

/// 句间停顿阶段：当前句子所有遍数播完，等待推进到下一句
class AdvancePausePhase extends PlaybackPhase {
  /// 倒计时状态
  final CountdownState countdown;

  const AdvancePausePhase({this.countdown = const CountdownState()});

  AdvancePausePhase copyWith({CountdownState? countdown}) {
    return AdvancePausePhase(countdown: countdown ?? this.countdown);
  }
}

/// 评估后停顿阶段：录音评估完成后的 review 倒计时
///
/// 仅用于跟读模式，评估完成后给用户 5 秒查看结果，
/// 倒计时结束后自动推进到下一句。
class PostEvalPausePhase extends PlaybackPhase {
  /// 是否处于句间停顿上下文（true=句间推进，false=遍间推进）
  ///
  /// 用于 completePausedTurn() 判断倒计时结束后是推进到下一句还是下一遍。
  final bool isSentencePause;

  /// 倒计时状态
  final CountdownState countdown;

  const PostEvalPausePhase({
    this.isSentencePause = false,
    this.countdown = const CountdownState(),
  });

  PostEvalPausePhase copyWith({
    bool? isSentencePause,
    CountdownState? countdown,
  }) {
    return PostEvalPausePhase(
      isSentencePause: isSentencePause ?? this.isSentencePause,
      countdown: countdown ?? this.countdown,
    );
  }
}
