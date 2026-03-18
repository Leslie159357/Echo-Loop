/// 基于 embedding 的文本语义相似度计算。
library;

import 'dart:math' as math;

import 'text_embedding_platform.dart';

/// 使用 [TextEmbeddingBackend] 计算两段文本的语义相似度。
class EmbeddingSimilarity {
  /// embedding 后端实现。
  final TextEmbeddingBackend _backend;

  /// 创建 [EmbeddingSimilarity] 实例。
  ///
  /// [backend] 为 embedding 计算后端，默认使用平台实现。
  EmbeddingSimilarity({TextEmbeddingBackend? backend})
    : _backend = backend ?? TextEmbeddingPlatform.instance;

  /// 当前平台是否支持 embedding 计算。
  bool get isSupported => _backend.isSupported;

  /// 计算两段文本的 embedding cosine similarity。
  ///
  /// 返回值范围 [0.0, 1.0]，1.0 表示完全相同，0.0 表示无关。
  /// 当平台不支持时返回 0.0。
  Future<double> computeSimilarity(String textA, String textB) async {
    if (!_backend.isSupported) {
      return 0.0;
    }
    final normalizedA = _removePunctuation(textA);
    final normalizedB = _removePunctuation(textB);
    final results = await Future.wait([
      _backend.embed(normalizedA),
      _backend.embed(normalizedB),
    ]);
    return cosineSimilarity(results[0], results[1]);
  }

  static final _punctuationPattern = RegExp(r'''[.,!?;:"()\[\]{}\-—–…/\\]''');

  /// 移除标点符号并压缩多余空格，使 ASR 结果与原文对比更公平。
  static String _removePunctuation(String text) {
    return text
        .replaceAll(_punctuationPattern, ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// 计算两个向量的 cosine similarity。
  ///
  /// 返回值范围 [-1.0, 1.0]。若任一向量为空或维度不匹配，返回 0.0。
  static double cosineSimilarity(List<double> a, List<double> b) {
    if (a.isEmpty || b.isEmpty || a.length != b.length) {
      return 0.0;
    }

    var dotProduct = 0.0;
    var normA = 0.0;
    var normB = 0.0;

    for (var i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    final denominator = math.sqrt(normA) * math.sqrt(normB);
    if (denominator == 0.0) {
      return 0.0;
    }

    return dotProduct / denominator;
  }
}
