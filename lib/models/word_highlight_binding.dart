import 'dart:async';

/// iOS seek 后位置流短暂回退时仍视作句首的最大误差。
const wordHighlightSeekRollbackTolerance = Duration(milliseconds: 250);

/// 逐词高亮对应的播放生命周期。
enum WordHighlightPlaybackStatus {
  /// 播放尚未开始，或播放器已停止。
  idle,

  /// 音频正在播放。
  playing,

  /// 播放开始后被暂停或定位。
  paused,

  /// 播放自然结束。
  completed;

  /// 当前状态是否保留时间轴上的逐词高亮。
  bool get allowsHighlight =>
      this == WordHighlightPlaybackStatus.playing ||
      this == WordHighlightPlaybackStatus.paused;
}

/// 播放位置来源；由页面把当前任务实际使用的播放器注入字幕展示层。
class WordHighlightSource {
  /// 对应词级时间戳所属的音频。
  final String audioItemId;

  /// 音频绝对时间位置流。
  final Stream<Duration> positionStream;

  /// 订阅位置流前的当前绝对位置。
  final Duration currentPosition;

  /// 当前播放器的生命周期状态。
  final WordHighlightPlaybackStatus playbackStatus;

  /// 播放器生命周期状态流。
  final Stream<WordHighlightPlaybackStatus> playbackStatusStream;

  /// 可选诊断标签；仅用于在特定播放页面追踪词高亮转换。
  final String? debugLabel;

  const WordHighlightSource({
    required this.audioItemId,
    required this.positionStream,
    required this.currentPosition,
    required this.playbackStatus,
    required this.playbackStatusStream,
    this.debugLabel,
  });
}

/// 当前句子与播放时间轴的绑定。
class WordHighlightBinding {
  /// 当前句子的原音位置来源。
  final WordHighlightSource source;

  /// 句子起止时间（毫秒）。
  final int sentenceStartMs;
  final int sentenceEndMs;

  /// 当前区间播放起点；起点之前的位置事件不属于本次播放时间轴。
  ///
  /// seek 后播放器可能短暂发出起点之前的位置。没有此约束时，
  /// 句子范围内的上一个词仍会被解析成活动词。
  final int? activeRangeStartMs;

  /// 用户点选全文句子后，允许将句首前短暂回退的位置样本映射回句首。
  ///
  /// 仅在 [wordHighlightSeekRollbackTolerance] 范围内修正；较远的旧位置仍按
  /// 原时间轴解析，避免 seek 尚未到达目标时提前高亮句首。
  final int? positionRollbackFloorMs;

  const WordHighlightBinding({
    required this.source,
    required this.sentenceStartMs,
    required this.sentenceEndMs,
    this.activeRangeStartMs,
    this.positionRollbackFloorMs,
  });
}
