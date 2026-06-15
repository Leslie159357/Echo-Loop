// SRT 字幕格式生成工具
//
// 将后端返回的 sentences 数据转为标准 SRT 格式。
// 后端负责分句逻辑，此工具仅做格式转换。

/// 转录句子数据
class TranscriptSentence {
  /// 句子文本
  final String text;

  /// 开始时间
  final Duration startTime;

  /// 结束时间
  final Duration endTime;

  /// 句子在全文 words 数组中的起始词索引（含）
  final int? startWordIndex;

  /// 句子在全文 words 数组中的结束词索引（含）
  final int? endWordIndex;

  const TranscriptSentence({
    required this.text,
    required this.startTime,
    required this.endTime,
    this.startWordIndex,
    this.endWordIndex,
  });

  /// 从后端 JSON 创建
  ///
  /// 后端 startTime / endTime 单位为秒（浮点数），需转换为 Duration。
  /// startWordIndex / endWordIndex 由后端 SentenceTimestamp 提供。
  factory TranscriptSentence.fromJson(Map<String, dynamic> json) {
    return TranscriptSentence(
      text: json['text'] as String,
      startTime: Duration(
        milliseconds: ((json['startTime'] as num) * 1000).round(),
      ),
      endTime: Duration(
        milliseconds: ((json['endTime'] as num) * 1000).round(),
      ),
      startWordIndex: json['startWordIndex'] as int?,
      endWordIndex: json['endWordIndex'] as int?,
    );
  }
}

/// 将句子列表转为 SRT 格式字符串
///
/// SRT 格式：
/// ```
/// 1
/// 00:00:01,500 --> 00:00:04,000
/// Hello world
///
/// 2
/// 00:00:04,500 --> 00:00:07,000
/// Second sentence
/// ```
String generateSrtContent(List<TranscriptSentence> sentences) {
  if (sentences.isEmpty) return '';
  final buffer = StringBuffer();
  for (var i = 0; i < sentences.length; i++) {
    if (i > 0) buffer.writeln();
    final s = sentences[i];
    buffer.writeln(i + 1);
    buffer.writeln(
      '${_formatSrtTime(s.startTime)} --> ${_formatSrtTime(s.endTime)}',
    );
    buffer.writeln(s.text);
  }
  return buffer.toString();
}

/// 格式化 Duration 为 SRT 时间格式 HH:MM:SS,mmm
String _formatSrtTime(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  final ms = d.inMilliseconds.remainder(1000);
  return '${h.toString().padLeft(2, '0')}:'
      '${m.toString().padLeft(2, '0')}:'
      '${s.toString().padLeft(2, '0')},'
      '${ms.toString().padLeft(3, '0')}';
}
