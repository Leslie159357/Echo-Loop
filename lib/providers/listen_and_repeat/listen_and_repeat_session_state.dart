/// 跟读会话状态（不可变）
///
/// UI 只读这一个状态对象，Controller 是唯一写入者。
/// 包含所有 UI 渲染需要的信息，不包含业务逻辑。
///
/// 阶段特有数据在 [ListenAndRepeatPhase] 的各子类中，
/// 会话级数据在此 State 中。
library;

import 'listen_and_repeat_phase.dart';

/// 跟读会话状态
class ListenAndRepeatSessionState {
  /// 当前阶段（携带阶段特有数据）
  final ListenAndRepeatPhase phase;

  /// 当前句子索引（0-based）
  final int sentenceIndex;

  /// 句子总数
  final int totalSentences;

  /// 当前遍数（0-based，"第 repeatIndex+1 遍"）
  final int repeatIndex;

  /// 总遍数
  final int totalRepeats;

  /// 遍间倒计时总时长（配置值，用于创建 WaitingInterval）
  final Duration intervalDuration;

  /// 最新录音文件路径（跨阶段保留，用于评分 badge 和回放）
  final String? recordingPath;

  /// 最新录音评分（跨阶段保留，用于评分 badge 和倒计时触发判断）
  final double? recordingScore;

  /// 流程令牌（每次切句/重置递增，异步回调校验用）
  final int flowToken;

  /// 是否为自由练习模式
  final bool isFreePlay;

  const ListenAndRepeatSessionState({
    this.phase = const Idle(),
    this.sentenceIndex = 0,
    this.totalSentences = 0,
    this.repeatIndex = 0,
    this.totalRepeats = 3,
    this.intervalDuration = Duration.zero,
    this.recordingPath,
    this.recordingScore,
    this.flowToken = 0,
    this.isFreePlay = false,
  });

  ListenAndRepeatSessionState copyWith({
    ListenAndRepeatPhase? phase,
    int? sentenceIndex,
    int? totalSentences,
    int? repeatIndex,
    int? totalRepeats,
    Duration? intervalDuration,
    Object? recordingPath = _noChange,
    Object? recordingScore = _noChange,
    int? flowToken,
    bool? isFreePlay,
  }) {
    return ListenAndRepeatSessionState(
      phase: phase ?? this.phase,
      sentenceIndex: sentenceIndex ?? this.sentenceIndex,
      totalSentences: totalSentences ?? this.totalSentences,
      repeatIndex: repeatIndex ?? this.repeatIndex,
      totalRepeats: totalRepeats ?? this.totalRepeats,
      intervalDuration: intervalDuration ?? this.intervalDuration,
      recordingPath: identical(recordingPath, _noChange)
          ? this.recordingPath
          : recordingPath as String?,
      recordingScore: identical(recordingScore, _noChange)
          ? this.recordingScore
          : recordingScore as double?,
      flowToken: flowToken ?? this.flowToken,
      isFreePlay: isFreePlay ?? this.isFreePlay,
    );
  }

  // ========== 便捷 getter ==========

  /// 是否为最后一句
  bool get isLastSentence => sentenceIndex >= totalSentences - 1;

  /// 是否为第一句
  bool get isFirstSentence => sentenceIndex <= 0;

  /// 是否为最后一遍
  bool get isLastRepeat => repeatIndex >= totalRepeats - 1;

  /// 是否在倒计时中
  bool get isCountingDown => phase is WaitingInterval;

  /// 是否在等待用户操作
  bool get isWaitingForUser => phase is WaitingForUser;

  /// 是否处于停顿状态（录音/等待/倒计时）
  bool get isInPause =>
      phase is WaitingInterval ||
      phase is WaitingForUser ||
      phase is Recording;

  /// 是否已完成
  bool get isCompleted =>
      phase is SentenceCompleted || phase is SessionCompleted;
}

const _noChange = Object();
