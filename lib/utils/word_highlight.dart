/// 按播放位置把词级时间戳映射到字幕词序号。
library;

import '../models/word_timestamp.dart';
import 'text_normalize.dart';

final RegExp _textWordPattern = RegExp(r'\S+');

/// 返回当前播放位置对应的字幕词序号；没有可信的一一匹配时返回 null。
///
/// 句子按中点归属到半开区间 `[sentenceStart, sentenceEnd)`。字幕与时间戳
/// 按顺序逐词归一化匹配，标点和大小写差异会被忽略；出现词语缺失或顺序差异时
/// 整句不高亮，避免把播放位置错误地标到另一个词上。
int? resolveActiveWordIndex({
  required String text,
  required List<WordTimestamp> timestamps,
  required Duration sentenceStart,
  required Duration sentenceEnd,
  required Duration position,
}) {
  if (text.trim().isEmpty || sentenceEnd <= sentenceStart) return null;

  final textWords = _textWordPattern
      .allMatches(text)
      .map((match) => normalizeWord(match.group(0) ?? ''))
      .where((word) => word.isNotEmpty)
      .toList(growable: false);
  if (textWords.isEmpty) return null;

  final sentenceWords = timestamps
      .where((word) {
        if (word.endTime <= word.startTime) return false;
        final midpointUs =
            (word.startTime.inMicroseconds + word.endTime.inMicroseconds) ~/ 2;
        return midpointUs >= sentenceStart.inMicroseconds &&
            midpointUs < sentenceEnd.inMicroseconds;
      })
      .toList(growable: false);
  if (sentenceWords.length != textWords.length) return null;

  for (var i = 0; i < sentenceWords.length; i++) {
    if (normalizeWord(sentenceWords[i].word) != textWords[i]) return null;
    if (position >= sentenceWords[i].startTime &&
        position < sentenceWords[i].endTime) {
      return i;
    }
  }
  return null;
}
