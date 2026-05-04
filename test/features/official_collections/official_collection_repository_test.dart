import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:echo_loop/database/app_database.dart';
import 'package:echo_loop/features/official_collections/data/official_catalog_service.dart';
import 'package:echo_loop/features/official_collections/data/official_collection_repository.dart';
import 'package:echo_loop/features/official_collections/models/catalog.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/catalog_fixtures.dart';

/// 假 catalog service，可注入 cached 与 hasInitialized 状态。
class _FakeCatalogService extends OfficialCatalogService {
  CatalogSnapshot? _injectedCached;
  bool _hasInit = false;

  _FakeCatalogService()
      : super.withDio(
          dio: Dio(),
          resolveDir: () async => Directory.systemTemp,
        );

  void seed(CatalogSnapshot snapshot) {
    _injectedCached = snapshot;
    _hasInit = true;
  }

  void markInitializedEmpty() {
    _injectedCached = null;
    _hasInit = true;
  }

  @override
  CatalogSnapshot? get cached => _injectedCached;

  @override
  bool get hasInitialized => _hasInit;
}

void main() {
  late AppDatabase db;
  late _FakeCatalogService fakeCatalog;
  late OfficialCollectionRepository repo;
  late Directory tmpDir;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    fakeCatalog = _FakeCatalogService();
    tmpDir = await Directory.systemTemp.createTemp('repo_test_');
    repo = OfficialCollectionRepository(
      database: db,
      catalog: fakeCatalog,
      docsDir: () async => tmpDir,
    );
  });

  tearDown(() async {
    await db.close();
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  group('enroll', () {
    test('catalog 未初始化 → 抛 CatalogNotInitializedError', () async {
      // hasInitialized=false 时
      expect(
        () => repo.enroll('r1'),
        throwsA(isA<CatalogNotInitializedError>()),
      );
    });

    test('catalog 已初始化但找不到 remoteId → 抛 OfficialCollectionNotFoundInCatalog',
        () async {
      fakeCatalog.markInitializedEmpty();
      expect(
        () => repo.enroll('r-missing'),
        throwsA(isA<OfficialCollectionNotFoundInCatalog>()),
      );
    });

    test('从 catalog 读 detail 落库：collections + audio_items + junction', () async {
      fakeCatalog.seed(makeSnapshot(collections: [
        makeCatalogCollection(id: 'r1', name: 'TED', audios: [
          makeCatalogAudio(id: 'a1', sortOrder: 0),
          makeCatalogAudio(id: 'a2', sortOrder: 1),
        ]),
      ]));

      final localId = await repo.enroll('r1');

      final coll = await db.collectionDao.getById(localId);
      expect(coll?.name, 'TED');
      expect(coll?.source, 'official');
      expect(coll?.remoteId, 'r1');

      final audioIds = await db.collectionDao.getAudioIds(localId);
      expect(audioIds, hasLength(2));

      for (final aid in audioIds) {
        final row = await db.audioItemDao.getById(aid);
        // enroll 不预置 path，等下载完成写入
        expect(row?.audioPath, isNull);
        expect(row?.transcriptPath, isNull);
        expect(row?.remoteAudioId, isIn(['a1', 'a2']));
      }
    });

    test('重复 enroll 同一 remoteId → 抛 AlreadyEnrolledError', () async {
      fakeCatalog.seed(makeSnapshot(collections: [
        makeCatalogCollection(id: 'r1', audios: [makeCatalogAudio(id: 'a1')]),
      ]));
      final firstLocalId = await repo.enroll('r1');

      expect(
        () => repo.enroll('r1'),
        throwsA(isA<AlreadyEnrolledError>().having(
          (e) => e.localId,
          'localId',
          firstLocalId,
        )),
      );
    });

    test('软删后可再次 enroll', () async {
      fakeCatalog.seed(makeSnapshot(collections: [
        makeCatalogCollection(id: 'r1', audios: [makeCatalogAudio(id: 'a1')]),
      ]));
      final firstId = await repo.enroll('r1');
      await db.collectionDao.softDelete(firstId);

      final secondId = await repo.enroll('r1');
      expect(secondId, isNot(firstId));
    });
  });

  group('remove（彻底清空）', () {
    test('删 collections + audio_items + junction + 关联表 + 文件', () async {
      fakeCatalog.seed(makeSnapshot(collections: [
        makeCatalogCollection(id: 'r1', audios: [
          makeCatalogAudio(id: 'a1', sha256: 'sha-a1'),
        ]),
      ]));
      final localId = await repo.enroll('r1');
      final audioIds = await db.collectionDao.getAudioIds(localId);
      final audioIdForProgress = audioIds.first;

      // 写入学习进度 + 书签模拟用户已学
      await db.into(db.learningProgresses).insert(
            LearningProgressesCompanion.insert(
              audioItemId: audioIdForProgress,
              updatedAt: DateTime.now(),
              currentStage: const Value('firstLearning'),
              currentSubStage: const Value('blindListen'),
            ),
          );
      await db.into(db.bookmarks).insert(
            BookmarksCompanion.insert(
              audioItemId: audioIdForProgress,
              sentenceIndex: 0,
              sentenceText: 'hello',
              startTime: 0.0,
              endTime: 1.0,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      // 模拟下载完成：DB 写入 path + 文件落盘
      final relativeAudioPath = 'audios/official/sha-a1.m4a';
      final relativeTranscriptPath =
          'transcripts/official_${audioIds.first}.srt';
      await (db.update(db.audioItems)
            ..where((t) => t.id.equals(audioIdForProgress)))
          .write(
            AudioItemsCompanion(
              audioPath: Value(relativeAudioPath),
              transcriptPath: Value(relativeTranscriptPath),
              updatedAt: Value(DateTime.now()),
            ),
          );
      final audioFile = File('${tmpDir.path}/$relativeAudioPath');
      await audioFile.parent.create(recursive: true);
      await audioFile.writeAsString('fake-audio');
      final srtFile = File('${tmpDir.path}/$relativeTranscriptPath');
      await srtFile.parent.create(recursive: true);
      await srtFile.writeAsString('fake-srt');

      await repo.remove(localId);

      expect(await db.collectionDao.getById(localId), isNull);
      for (final aid in audioIds) {
        expect(await db.audioItemDao.getById(aid), isNull);
      }
      final progressRows = await db.select(db.learningProgresses).get();
      expect(progressRows, isEmpty);
      final bookmarkRows = await db.select(db.bookmarks).get();
      expect(bookmarkRows, isEmpty);
      expect(await audioFile.exists(), isFalse);
      expect(await srtFile.exists(), isFalse);
    });
  });
}
