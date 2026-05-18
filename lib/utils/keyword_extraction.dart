/// 关键词提取算法
///
/// 从段落句子中随机选取非停用词作为关键词提示。
library;

import 'dart:math';

import '../models/retell_settings.dart';
import '../models/sentence.dart';
import 'stopwords.dart';

/// 分词分隔符正则：仅按空白字符拆分，保留标点附着在单词上
final _wordSplitPattern = RegExp(r'\s+');

/// 从句子列表中提取关键词
///
/// [sentences] 句子列表
/// [ratio] 关键词比例（默认 medium，40%）
/// [random] 可选随机数生成器（便于测试）
///
/// 返回 `Map<int, Set<int>>`，键为 [Sentence.index]（全局索引），
/// 值为该句中被选为关键词的词索引集合。
///
/// 算法：对每个句子独立计算——按该句总词数 × ratio 得出目标数，
/// 从非停用词候选中随机选取。
Map<int, Set<int>> extractKeywords(
  List<Sentence> sentences, {
  KeywordRatio ratio = KeywordRatio.medium,
  Random? random,
}) {
  final rng = random ?? Random();

  if (sentences.isEmpty) return {};

  final result = <int, Set<int>>{};

  for (final sentence in sentences) {
    final words = _tokenize(sentence.text);
    if (words.isEmpty) continue;

    // 收集候选词索引（非停用词且长度 > 2）
    final candidateIndices = <int>[
      for (var wi = 0; wi < words.length; wi++)
        if (words[wi].length > 2 && !isStopword(words[wi])) wi,
    ];

    if (candidateIndices.isEmpty) continue;

    // 按该句总词数计算目标数量，上限为候选词数
    final targetCount = (words.length * ratio.value).round().clamp(
      1,
      candidateIndices.length,
    );

    // 随机选取
    candidateIndices.shuffle(rng);
    result[sentence.index] = candidateIndices.take(targetCount).toSet();
  }

  return result;
}

/// 将句子文本分词为单词列表
List<String> tokenize(String text) => _tokenize(text);

/// 内部分词实现
List<String> _tokenize(String text) {
  return text.split(_wordSplitPattern).where((w) => w.isNotEmpty).toList();
}
