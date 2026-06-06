import '../../models/sentence.dart';
import '../../models/word_timestamp.dart';

/// 句子可拖动的边界端。
enum BoundaryEdge {
  /// 起始边界。
  start,

  /// 结束边界。
  end,
}

/// 波形上一条可绘制 / 可拖动的单词边界。
///
/// 句子的起止边界即首词起点 / 末词终点，故统一用单词边界表达，不再单列句子边界。
/// - [globalIndex]：映射回全篇词列表；`-1` 表示与文本 token 暂不同步（只绘制、不可拖动）。
/// - [word]：句区间内、已贴合句界的显示值。
/// - [primary]：true 为当前选中句（主样式大把手），false 为相邻句（次样式小把手）。
/// - [isSentenceStart] / [isSentenceEnd]：该词是否为所在句的首词起点 / 末词终点
///   （即句子的起止边界）。
typedef WaveformWordBoundary = ({
  int globalIndex,
  WordTimestamp word,
  bool primary,
  bool isSentenceStart,
  bool isSentenceEnd,
});

/// 字幕编辑纯逻辑。
///
/// 目前只支持句子级结构操作。所有方法都会返回新的句子列表并重新编号，
/// 让 UI 和持久化层不必各自维护 index 连续性。
class SubtitleEditEngine {
  const SubtitleEditEngine();

  /// 将 [index] 对应句子与下一句合并。
  List<Sentence> mergeWithNext(List<Sentence> sentences, int index) {
    if (index < 0 || index >= sentences.length - 1) {
      return sentences;
    }

    final next = [...sentences];
    final current = next[index];
    final following = next[index + 1];
    next[index] = current.copyWith(
      text: _joinSentenceText(current.text, following.text),
      endTime: following.endTime,
      isBookmarked: current.isBookmarked || following.isBookmarked,
    );
    next.removeAt(index + 1);
    return _reindex(next);
  }

  /// 删除指定句子；不允许删除到空字幕。
  List<Sentence> deleteSentence(List<Sentence> sentences, int index) {
    if (sentences.length <= 1 || index < 0 || index >= sentences.length) {
      return sentences;
    }

    final next = [...sentences]..removeAt(index);
    return _reindex(next);
  }

  List<Sentence> _reindex(List<Sentence> sentences) {
    return [
      for (final (index, sentence) in sentences.indexed)
        sentence.copyWith(index: index),
    ];
  }

  String _joinSentenceText(String first, String second) {
    final left = first.trim();
    final right = second.trim();
    if (left.isEmpty) return right;
    if (right.isEmpty) return left;
    return '$left $right';
  }
}
