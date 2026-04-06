/// 闪卡流程阶段状态机
///
/// 表达闪卡复习流程的顶层阶段，每个阶段互斥。
/// 流程：Idle → PlayingTts → Countdown → flip/next → 循环
///
/// 每个阶段携带该阶段特有的数据，编译期保证不会在错误阶段访问错误数据。
library;

/// 闪卡流程阶段
sealed class FlashcardFlowPhase {
  const FlashcardFlowPhase();
}

/// 空闲（未开始或过渡态）
class FlashcardIdle extends FlashcardFlowPhase {
  const FlashcardIdle();
}

/// 自动播放单词 TTS 中
class FlashcardPlayingTts extends FlashcardFlowPhase {
  const FlashcardPlayingTts();
}

/// 自动播放例句中
class FlashcardPlayingSentence extends FlashcardFlowPhase {
  const FlashcardPlayingSentence();
}

/// 倒计时中（正面到期 → 翻转；背面到期 → 下一张）
class FlashcardCountdown extends FlashcardFlowPhase {
  /// 倒计时剩余时间
  final Duration remaining;

  /// 倒计时总时长
  final Duration total;

  const FlashcardCountdown({required this.remaining, required this.total});

  FlashcardCountdown copyWith({Duration? remaining, Duration? total}) {
    return FlashcardCountdown(
      remaining: remaining ?? this.remaining,
      total: total ?? this.total,
    );
  }
}

/// 等待用户操作（无倒计时，用户必须点击 next 恢复自动）
class FlashcardWaitingForUser extends FlashcardFlowPhase {
  /// 等待原因
  final FlashcardWaitingReason reason;

  const FlashcardWaitingForUser(this.reason);
}

/// 等待用户的原因
enum FlashcardWaitingReason {
  /// 手动模式 — 始终等待
  manualMode,

  /// 用户点击播放词汇 TTS
  userPlayedWord,

  /// 用户点击播放例句
  userPlayedSentence,

  /// 用户中途停止例句播放
  userStoppedPlayback,

  /// 用户手动翻转卡片
  userFlippedCard,

  /// 用户打开设置
  userOpenedSettings,

  /// 用户点击倒计时
  userTappedCountdown,

  /// App 切到后台
  appBackgrounded,
}

/// 整个会话完成（所有卡片复习完毕）
class FlashcardSessionCompleted extends FlashcardFlowPhase {
  const FlashcardSessionCompleted();
}
