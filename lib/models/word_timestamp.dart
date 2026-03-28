/// 词级时间戳模型
///
/// 存储后端转录引擎（Deepgram/AssemblyAI）返回的每个单词的精确时间范围。
/// 用于意群播放时间映射。
library;

/// 单词时间戳
class WordTimestamp {
  /// 单词文本
  final String word;

  /// 开始时间
  final Duration startTime;

  /// 结束时间
  final Duration endTime;

  /// 置信度 (0.0 ~ 1.0)
  final double confidence;

  const WordTimestamp({
    required this.word,
    required this.startTime,
    required this.endTime,
    required this.confidence,
  });

  /// 从后端 JSON 创建
  ///
  /// 后端 startTime / endTime 单位为秒（浮点数），需转换为 Duration。
  factory WordTimestamp.fromJson(Map<String, dynamic> json) {
    return WordTimestamp(
      word: json['word'] as String,
      startTime: Duration(
        milliseconds: ((json['startTime'] as num) * 1000).round(),
      ),
      endTime: Duration(
        milliseconds: ((json['endTime'] as num) * 1000).round(),
      ),
      confidence: (json['confidence'] as num).toDouble(),
    );
  }

  /// 序列化为 JSON
  Map<String, dynamic> toJson() => {
    'word': word,
    'startTime': startTime.inMilliseconds / 1000.0,
    'endTime': endTime.inMilliseconds / 1000.0,
    'confidence': confidence,
  };
}
