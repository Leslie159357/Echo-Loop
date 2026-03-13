/// AI 句子翻译与解析结果模型
///
/// 用于存储后端 AI 返回的翻译和语法/词汇/用法解析结果。
/// 两个模型都支持从 JSON 反序列化。
library;

/// AI 翻译结果
class SentenceTranslation {
  /// 翻译文本
  final String translation;

  const SentenceTranslation({required this.translation});

  /// 从 API 响应 JSON 反序列化
  factory SentenceTranslation.fromJson(Map<String, dynamic> json) =>
      SentenceTranslation(translation: json['translation'] as String);
}

/// AI 解析结果
class SentenceAnalysis {
  /// 语法分析
  final String grammar;

  /// 词汇分析
  final String vocabulary;

  /// 听力分析（连读、弱读、缩读等语音现象）
  final String listening;

  const SentenceAnalysis({
    required this.grammar,
    required this.vocabulary,
    required this.listening,
  });

  /// 从 API 响应 JSON 反序列化
  ///
  /// 期望格式：`{ "analysis": { "grammar": "...", "vocabulary": "...", "listening": "..." } }`
  factory SentenceAnalysis.fromJson(Map<String, dynamic> json) {
    final analysis = json['analysis'] as Map<String, dynamic>;
    return SentenceAnalysis(
      grammar: analysis['grammar'] as String,
      vocabulary: analysis['vocabulary'] as String,
      listening: analysis['listening'] as String,
    );
  }
}
