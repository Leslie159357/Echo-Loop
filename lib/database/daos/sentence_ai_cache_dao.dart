import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/sentence_ai_cache.dart';

part 'sentence_ai_cache_dao.g.dart';

/// AI 缓存 DAO
///
/// 提供句子翻译/解析结果的 SQLite 缓存操作。
/// 读取时自动更新 lastAccessedAt，支持按时间清理过期缓存。
@DriftAccessor(tables: [SentenceAiCache])
class SentenceAiCacheDao extends DatabaseAccessor<AppDatabase>
    with _$SentenceAiCacheDaoMixin {
  SentenceAiCacheDao(super.db);

  /// 根据哈希和类型查找缓存
  ///
  /// 命中时自动更新 [lastAccessedAt]，返回 JSON 字符串；未命中返回 null。
  Future<String?> getByHash(String hash, String type) async {
    final query = select(sentenceAiCache)
      ..where((t) => t.textHash.equals(hash) & t.type.equals(type));
    final row = await query.getSingleOrNull();
    if (row == null) return null;

    // 更新最后访问时间
    (update(sentenceAiCache)..where((t) => t.id.equals(row.id))).write(
      SentenceAiCacheCompanion(lastAccessedAt: Value(DateTime.now())),
    );

    return row.result;
  }

  /// 插入或更新缓存
  ///
  /// 以 (textHash, type) 为唯一键，冲突时更新 result 和时间戳。
  Future<void> upsert(String hash, String type, String resultJson) {
    final now = DateTime.now();
    return into(sentenceAiCache).insert(
      SentenceAiCacheCompanion.insert(
        textHash: hash,
        type: type,
        result: resultJson,
        createdAt: now,
        lastAccessedAt: now,
      ),
      onConflict: DoUpdate(
        (old) => SentenceAiCacheCompanion(
          result: Value(resultJson),
          lastAccessedAt: Value(now),
        ),
        target: [sentenceAiCache.textHash, sentenceAiCache.type],
      ),
    );
  }

  /// 根据哈希和类型删除单条缓存
  ///
  /// 用于缓存格式不兼容时清除旧数据。
  Future<int> deleteByHash(String hash, String type) {
    return (delete(
      sentenceAiCache,
    )..where((t) => t.textHash.equals(hash) & t.type.equals(type))).go();
  }

  /// 删除超过指定时间未访问的缓存
  ///
  /// 用于定期清理，避免数据库无限增长。
  Future<int> deleteOlderThan(Duration age) {
    final threshold = DateTime.now().subtract(age);
    return (delete(
      sentenceAiCache,
    )..where((t) => t.lastAccessedAt.isSmallerThanValue(threshold))).go();
  }

  /// 清空所有 AI 缓存
  ///
  /// 用于用户手动清理缓存，不影响其他用户数据。
  Future<int> deleteAll() {
    return delete(sentenceAiCache).go();
  }
}
