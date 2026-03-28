// SRT 字幕格式生成工具
//
// 将后端返回的 sentences 数据转为标准 SRT 格式。
// 后端负责分句逻辑，此工具仅做格式转换。
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:universal_io/io.dart';

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

/// 保存 SRT 内容到 transcripts/ 目录
///
/// [audioId] 音频唯一 ID，用于确保文件名唯一。
/// [srtContent] SRT 格式内容。
/// 返回相对于应用文档目录的路径（如 `transcripts/{audioId}_ai.srt`）。
Future<String> saveSrtFile(String audioId, String srtContent) async {
  final docDir = await getApplicationDocumentsDirectory();
  final transcriptsDir = p.join(docDir.path, 'transcripts');
  await _ensureDirectoryExists(transcriptsDir);

  // 使用 audioId 确保文件名唯一，避免同名音频覆盖
  final fileName = '${audioId}_ai.srt';
  final relativePath = p.join('transcripts', fileName);
  final fullPath = p.join(docDir.path, relativePath);

  final file = await _writeFile(fullPath, srtContent);
  // 确保文件写入成功
  if (!await file.exists()) {
    throw StateError('Failed to write SRT file: $fullPath');
  }
  return relativePath;
}

/// 确保目录存在
Future<void> _ensureDirectoryExists(String path) async {
  final dir = Directory(path);
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
}

/// 写入文件
Future<File> _writeFile(String path, String content) async {
  final file = File(path);
  return file.writeAsString(content);
}
