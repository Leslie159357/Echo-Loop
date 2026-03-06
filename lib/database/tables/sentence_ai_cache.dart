import 'package:drift/drift.dart';

/// AI 翻译/解析结果缓存表
///
/// 作为三级缓存的 L2 层（SQLite），存储后端返回的 AI 结果 JSON。
/// 通过 (textHash, type) 唯一键查找，支持按访问时间清理过期缓存。
class SentenceAiCache extends Table {
  /// 自增主键
  IntColumn get id => integer().autoIncrement()();

  /// 句子文本的 SHA-256 哈希值（归一化后）
  TextColumn get textHash => text()();

  /// 结果类型：'translation' 或 'analysis'
  TextColumn get type => text()();

  /// API 返回的 JSON 字符串
  TextColumn get result => text()();

  /// 创建时间
  DateTimeColumn get createdAt => dateTime()();

  /// 最后访问时间（用于 LRU 清理）
  DateTimeColumn get lastAccessedAt => dateTime()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {textHash, type},
  ];
}
