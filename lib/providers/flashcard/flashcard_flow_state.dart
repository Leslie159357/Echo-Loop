/// 闪卡流程状态（不可变数据类）
///
/// 由 [FlashcardFlowEngine] 管理，通过 [onStateChanged] 通知外部。
/// [FlashcardNotifier] 将此状态合并到 UI 层的 [FlashcardState] 中。
library;

import 'flashcard_flow_phase.dart';

/// 闪卡流程状态
class FlashcardFlowState {
  /// 当前阶段
  final FlashcardFlowPhase phase;

  /// 是否正在显示背面
  final bool isShowingBack;

  /// 用户手动播放例句是否进行中（UI 显示播放/停止图标用）
  final bool isSentencePlaying;

  /// 流程令牌（异步回调校验用，切卡/翻转/中断时递增）
  final int flowToken;

  const FlashcardFlowState({
    this.phase = const FlashcardIdle(),
    this.isShowingBack = false,
    this.isSentencePlaying = false,
    this.flowToken = 0,
  });

  FlashcardFlowState copyWith({
    FlashcardFlowPhase? phase,
    bool? isShowingBack,
    bool? isSentencePlaying,
    int? flowToken,
  }) {
    return FlashcardFlowState(
      phase: phase ?? this.phase,
      isShowingBack: isShowingBack ?? this.isShowingBack,
      isSentencePlaying: isSentencePlaying ?? this.isSentencePlaying,
      flowToken: flowToken ?? this.flowToken,
    );
  }

  // ========== 便捷 getter ==========

  /// 是否显示倒计时
  bool get showCountdown => phase is FlashcardCountdown;

  /// 倒计时剩余时间（非倒计时阶段返回 Duration.zero）
  Duration get countdownRemaining => switch (phase) {
    FlashcardCountdown(:final remaining) => remaining,
    _ => Duration.zero,
  };

  /// 倒计时总时长（非倒计时阶段返回 Duration.zero）
  Duration get countdownTotal => switch (phase) {
    FlashcardCountdown(:final total) => total,
    _ => Duration.zero,
  };

  /// 是否在等待用户操作
  bool get isWaitingForUser => phase is FlashcardWaitingForUser;

  /// 是否已完成
  bool get isCompleted => phase is FlashcardSessionCompleted;
}
