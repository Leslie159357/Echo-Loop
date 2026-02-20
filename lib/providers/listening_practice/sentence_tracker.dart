import '../../models/sentence.dart';

/// 句子追踪器
/// 负责根据播放位置定位当前句子
class SentenceTracker {
  /// 二分查找：根据播放位置查找对应的句子索引
  static int findSentenceIndexByPosition(
    List<Sentence> sentences,
    Duration position,
  ) {
    if (sentences.isEmpty) return -1;

    // 特殊情况：位置在第一个句子之前
    if (position < sentences.first.startTime) return 0;

    // 特殊情况：位置在最后一个句子之后
    if (position >= sentences.last.endTime) return sentences.length - 1;

    // 二分查找
    int left = 0;
    int right = sentences.length - 1;

    while (left <= right) {
      int mid = (left + right) ~/ 2;
      final sentence = sentences[mid];

      if (position >= sentence.startTime && position < sentence.endTime) {
        // 找到目标句子
        return mid;
      } else if (position < sentence.startTime) {
        right = mid - 1;
      } else {
        left = mid + 1;
      }
    }

    // 如果没有精确匹配（在句子间隙），返回最接近的句子
    // 优先返回即将播放的下一个句子
    if (left < sentences.length) return left;
    if (right >= 0) return right;

    return -1;
  }
  
  /// 找到最接近的书签句子
  static int? findClosestBookmark(
    List<Sentence> bookmarkedSentences,
    Duration position,
  ) {
    if (bookmarkedSentences.isEmpty) return null;
    
    int closestIdx = bookmarkedSentences.first.index;
    Duration closestDiff = (bookmarkedSentences.first.startTime - position).abs();
    
    for (var s in bookmarkedSentences) {
      final diff = (s.startTime - position).abs();
      if (diff < closestDiff) {
        closestDiff = diff;
        closestIdx = s.index;
      }
    }
    
    return closestIdx;
  }
}
