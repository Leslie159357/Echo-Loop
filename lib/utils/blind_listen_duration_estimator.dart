/// 盲听会话总时长估算
///
/// 与播放器的"自动跳过静音"开关耦合：
/// - 开启跳过 → 用字幕有效时长（句子 endTime - startTime 之和），剔除大段空白
/// - 关闭跳过 → 用完整音频时长（含静音），与用户耳朵实际听到的等长
///
/// 不计入段间停顿——盲听 briefing sheet 现有口径就是"显示音频时长"，
/// 切换跳过开关后只切换"被空白污染的总时长" vs "纯说话时长"，
/// 不引入段间停顿这个第三维度，以免数字波动让用户困惑。
library;

import '../models/sentence.dart';

/// 估算盲听会话总时长。
///
/// [sentences] 字幕句子列表
/// [fullAudioDuration] 音频总时长（含所有静音），跳过关闭时返回此值
/// [skipSilenceEnabled] 用户的"自动跳过静音"开关
///
/// 返回 null：跳过开启但字幕为空，且无法回退；或两个输入都缺失。
Duration? estimateBlindListenSessionDuration({
  required List<Sentence> sentences,
  required Duration? fullAudioDuration,
  required bool skipSilenceEnabled,
}) {
  if (skipSilenceEnabled) {
    if (sentences.isEmpty) return fullAudioDuration;
    return sentences.fold<Duration>(
      Duration.zero,
      (sum, s) => sum + s.duration,
    );
  }
  return fullAudioDuration;
}
