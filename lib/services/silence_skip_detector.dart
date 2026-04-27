/// 字幕驱动的静音段检测器
///
/// 根据当前播放位置和字幕时间戳判定是否处于"应跳过的静音段"。
/// 不依赖任何音频波形检测——纯字幕时间算术。
///
/// 三种分支：
/// - 中间 gap：相邻字幕之间间隔 ≥ threshold
///   触发条件 prevEnd+1s ≤ position < next.start-1s
///   skipTo = next.start - 1s（用户体验为：1s 自然 + 1s 缓冲 = 2s 静音）
/// - 开头：position 在第一句之前，first.start ≥ threshold/2
///   skipTo = first.start - 1s（开头不需要前置缓冲）
/// - 末尾：position 越过最后一句 + 1s，playbackEnd - last.end ≥ threshold/2
///   skipTo = playbackEnd（让播放自然结束）
library;

import '../models/sentence.dart';

/// 静音跳过检测结果
class SilenceSkipResult {
  /// 跳转目标位置
  final Duration skipTo;

  /// 检测到的静音 gap 总时长（用于 snackbar 展示）
  final Duration gapDuration;

  /// 去重 key：开头=0，中间=currentIdx，末尾=sentences.length
  ///
  /// 调用方记下上次跳过的 key，相同则跳过本次（防止位置流抖动重复触发）。
  final int dedupKey;

  const SilenceSkipResult({
    required this.skipTo,
    required this.gapDuration,
    required this.dedupKey,
  });
}

/// 字幕驱动的静音跳过检测器（纯函数）
class SilenceSkipDetector {
  /// 静音跳过检测。
  ///
  /// [position] 当前绝对播放位置。
  /// [sentences] 当前段落字幕列表（必须按 startTime 升序，且非空）。
  /// [currentIdx] 来自调用方现有的 `_findSentenceIndex(sentences, position)`：
  /// - position 落在第 i-1 句结束与第 i 句开始之间时，currentIdx == i
  /// - position 越过最后一句结束后，currentIdx == sentences.length
  /// - 注意：调用方的 `_findSentenceIndex` 通过 `clamp` 永远返回 [0, length-1]，
  ///   末尾分支的判定改用 `position >= last.endTime` 显式判断。
  /// [thresholdSeconds] 中间 gap 阈值（秒）。首尾用 threshold/2（向上取整）。
  /// [playbackEnd] 当前 clip / 音频末尾位置，用于末尾静音判定。
  static SilenceSkipResult? detect({
    required Duration position,
    required List<Sentence> sentences,
    required int currentIdx,
    required int thresholdSeconds,
    required Duration playbackEnd,
  }) {
    if (sentences.isEmpty) return null;
    const oneSec = Duration(seconds: 1);
    final boundaryThreshold = (thresholdSeconds + 1) ~/ 2; // 向上取整

    final last = sentences.last;
    // 末尾：position 越过最后一句 endTime（_findSentenceIndex 会 clamp 到 length-1，
    // 所以这里用 position 而非 currentIdx 判断）
    if (position >= last.endTime) {
      final tailGap = playbackEnd - last.endTime;
      if (tailGap.inSeconds < boundaryThreshold) return null;
      if (position < last.endTime + oneSec) return null;
      if (playbackEnd <= position) return null;
      return SilenceSkipResult(
        skipTo: playbackEnd,
        gapDuration: tailGap,
        dedupKey: sentences.length,
      );
    }

    // 开头：position 在第一句之前
    final first = sentences.first;
    if (position < first.startTime) {
      if (first.startTime.inSeconds < boundaryThreshold) return null;
      if (first.startTime - position <= oneSec) return null;
      return SilenceSkipResult(
        skipTo: first.startTime - oneSec,
        gapDuration: first.startTime,
        dedupKey: 0,
      );
    }

    // 中间 gap：position 在某句之内或之后，next = sentences[currentIdx]
    if (currentIdx <= 0 || currentIdx >= sentences.length) return null;
    final next = sentences[currentIdx];
    if (position >= next.startTime) return null; // 已在 next 区间内，不是 gap
    final prevEnd = sentences[currentIdx - 1].endTime;
    if (position < prevEnd) return null; // 还在 prev 区间内（防御性）

    final gap = next.startTime - prevEnd;
    if (gap.inSeconds < thresholdSeconds) return null;

    final pastBuffer = position >= prevEnd + oneSec;
    final stillRoom = next.startTime - position > oneSec;
    if (!pastBuffer || !stillRoom) return null;

    return SilenceSkipResult(
      skipTo: next.startTime - oneSec,
      gapDuration: gap,
      dedupKey: currentIdx,
    );
  }
}
