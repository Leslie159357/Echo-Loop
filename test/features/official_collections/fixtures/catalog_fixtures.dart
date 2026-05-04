import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Value;
import 'package:echo_loop/database/app_database.dart';
import 'package:echo_loop/features/official_collections/models/catalog.dart';

/// 构造 [CatalogAudio] 便于注入。
CatalogAudio makeCatalogAudio({
  String id = 'r-a1',
  String title = 'Track 1',
  int durationSec = 60,
  int sortOrder = 0,
  String? sha256,
  DateTime? originalDate,
}) {
  return CatalogAudio(
    id: id,
    title: title,
    durationSec: durationSec,
    sortOrder: sortOrder,
    sha256: sha256 ?? 'sha-$id',
    originalDate: originalDate,
  );
}

/// 构造 [CatalogCollection] 便于注入。
CatalogCollection makeCatalogCollection({
  String id = 'r-collA',
  String name = 'Daily English',
  String? description = '日常英语',
  String? coverUrl = 'https://cdn/c.png',
  DateTime? publishedAt,
  List<CatalogAudio> audios = const [],
}) {
  return CatalogCollection(
    id: id,
    name: name,
    description: description,
    coverUrl: coverUrl,
    publishedAt: publishedAt ?? DateTime(2026, 4, 1),
    audios: audios,
  );
}

/// 构造完整 [CatalogSnapshot]。`contentHash` 默认基于 collections 内容生成，
/// 与 service 的 sha256 对比逻辑兼容。
CatalogSnapshot makeSnapshot({
  required List<CatalogCollection> collections,
  String? contentHash,
  DateTime? fetchedAt,
}) {
  // 对应 service 中 sha256(utf8(jsonBody))；测试里用一个稳定的近似值即可
  final hash = contentHash ??
      sha256.convert(utf8.encode(jsonEncode({
        'serverTime': '2026-04-19T00:00:00.000Z',
        'collections': collections.map((c) => {
              'id': c.id,
              'name': c.name,
              'description': c.description,
              'coverUrl': c.coverUrl,
              'publishedAt': c.publishedAt.toIso8601String(),
              'audios': c.audios
                  .map((a) => {
                        'id': a.id,
                        'title': a.title,
                        'durationSec': a.durationSec,
                        'sortOrder': a.sortOrder,
                        'sha256': a.sha256,
                      })
                  .toList(),
            }).toList(),
      }))).toString();
  return CatalogSnapshot(
    collections: collections,
    contentHash: hash,
    fetchedAt: fetchedAt ?? DateTime(2026, 4, 19),
  );
}

/// 把 [CatalogSnapshot] 转为后端响应同形态的 JSON 字符串（service 解析它）。
String snapshotToBody(CatalogSnapshot s) {
  return jsonEncode({
    'serverTime': '2026-04-19T00:00:00.000Z',
    'collections': s.collections
        .map((c) => {
              'id': c.id,
              'name': c.name,
              'description': c.description,
              'coverUrl': c.coverUrl,
              'publishedAt': c.publishedAt.toIso8601String(),
              'audios': c.audios
                  .map((a) => {
                        'id': a.id,
                        'title': a.title,
                        'durationSec': a.durationSec,
                        'sortOrder': a.sortOrder,
                        'sha256': a.sha256,
                      })
                  .toList(),
            })
        .toList(),
  });
}

/// 在测试 db 中 seed 一个本地"已加入"的官方合集。
///
/// 返回本地 collectionId。
Future<String> seedEnrolledCollection(
  AppDatabase db, {
  String remoteId = 'r-collA',
  String name = 'Daily English',
  String? coverUrl,
  String? description,
  List<({String remoteAudioId, String sha256, int sortOrder, bool downloaded})>
      audios = const [],
}) async {
  final localId = 'local-$remoteId';
  final now = DateTime(2026, 4, 19);
  await db.collectionDao.upsert(
    CollectionsCompanion(
      id: Value(localId),
      name: Value(name),
      createdDate: Value(now),
      isPinned: const Value(false),
      updatedAt: Value(now),
      source: const Value('official'),
      remoteId: Value(remoteId),
      coverUrl: Value(coverUrl),
      description: Value(description),
    ),
  );
  for (final a in audios) {
    final localAudioId = 'local-${a.remoteAudioId}';
    // 单一真实来源：下载完成 ↔ 两个 path 非 null；未下载 ↔ 两个 path 皆为 null
    final audioPath = a.downloaded
        ? Value<String?>('audios/official/${a.sha256}.m4a')
        : const Value<String?>(null);
    final transcriptPath = a.downloaded
        ? Value<String?>('transcripts/official_$localAudioId.srt')
        : const Value<String?>(null);
    await db.audioItemDao.upsert(
      AudioItemsCompanion(
        id: Value(localAudioId),
        name: Value('Track ${a.remoteAudioId}'),
        audioPath: audioPath,
        transcriptPath: transcriptPath,
        addedDate: Value(now),
        totalDuration: Value(60),
        sentenceCount: const Value(0),
        wordCount: const Value(0),
        isPinned: const Value(false),
        remoteAudioId: Value(a.remoteAudioId),
        audioSha256: Value(a.sha256),
        updatedAt: Value(now),
      ),
    );
    await db.collectionDao.addAudio(localId, localAudioId);
  }
  return localId;
}
