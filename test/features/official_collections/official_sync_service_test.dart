import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:echo_loop/database/app_database.dart';
import 'package:echo_loop/features/official_collections/data/official_catalog_service.dart';
import 'package:echo_loop/features/official_collections/data/official_sync_service.dart';
import 'package:echo_loop/features/official_collections/models/catalog.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/catalog_fixtures.dart';

/// 假 catalog service：可控注入 outcome / snapshot。
class _FakeCatalogService extends OfficialCatalogService {
  CatalogRefreshOutcome nextOutcome = const CatalogThrottled();
  int refreshCallCount = 0;
  bool _hasInit = false;
  CatalogSnapshot? _injectedCached;

  _FakeCatalogService()
      : super.withDio(
          dio: Dio(),
          resolveDir: () async => Directory.systemTemp,
        );

  void seed(CatalogSnapshot snapshot) {
    _injectedCached = snapshot;
    _hasInit = true;
  }

  @override
  CatalogSnapshot? get cached => _injectedCached;

  @override
  bool get hasInitialized => _hasInit;

  @override
  Future<CatalogRefreshOutcome> refresh({bool force = false}) async {
    refreshCallCount++;
    final outcome = nextOutcome;
    // 模拟 service 内部：updated 时同步更新 cached
    if (outcome is CatalogUpdated) {
      _injectedCached = outcome.snapshot;
      _hasInit = true;
    }
    return outcome;
  }
}

void main() {
  late AppDatabase db;
  late _FakeCatalogService fakeCatalog;
  late OfficialSyncService sync;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    fakeCatalog = _FakeCatalogService();
    sync = OfficialSyncService(database: db, catalog: fakeCatalog);
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> _junctionCount() async {
    final rows = await db.select(db.collectionAudioItems).get();
    return rows.length;
  }

  Future<int> _audioRowCount() async {
    final rows = await db.select(db.audioItems).get();
    return rows.length;
  }

  group('outcome ≠ updated → 整链路全跳过（行数 0 变化）', () {
    test('throttled → 不动 DB', () async {
      await seedEnrolledCollection(
        db,
        remoteId: 'r1',
        audios: [
          (remoteAudioId: 'a1', sha256: 'sha-a1', sortOrder: 0, downloaded: false),
        ],
      );
      final juncBefore = await _junctionCount();
      final audiosBefore = await _audioRowCount();

      fakeCatalog.nextOutcome = const CatalogThrottled();
      final stats = await sync.syncAll();

      expect(stats.outcome, isA<CatalogThrottled>());
      expect(await _junctionCount(), juncBefore);
      expect(await _audioRowCount(), audiosBefore);
      expect(stats.audiosAdded, 0);
      expect(stats.collectionsDeprecated, 0);
    });

    test('unchanged → 不动 DB', () async {
      await seedEnrolledCollection(db);
      final juncBefore = await _junctionCount();

      fakeCatalog.nextOutcome = const CatalogUnchanged();
      final stats = await sync.syncAll();

      expect(stats.outcome, isA<CatalogUnchanged>());
      expect(await _junctionCount(), juncBefore);
    });

    test('failed → 不动 DB', () async {
      await seedEnrolledCollection(db);
      final juncBefore = await _junctionCount();

      fakeCatalog.nextOutcome = CatalogFailed(StateError('network'));
      final stats = await sync.syncAll();

      expect(stats.outcome, isA<CatalogFailed>());
      expect(await _junctionCount(), juncBefore);
    });
  });

  group('outcome=updated → 应用 diff', () {
    test('用例 1：catalog 为空 → 已加入合集 markDeprecated', () async {
      final localId = await seedEnrolledCollection(db, remoteId: 'r1');
      fakeCatalog.nextOutcome = CatalogUpdated(makeSnapshot(collections: const []));

      final stats = await sync.syncAll();
      expect(stats.collectionsDeprecated, 1);

      final row = await db.collectionDao.getById(localId);
      expect(row?.deprecatedAt, isNotNull);
    });

    test('用例 2：远端新增音频 → audio_items + junction 各 +1', () async {
      final localId = await seedEnrolledCollection(
        db,
        remoteId: 'r1',
        audios: [
          (remoteAudioId: 'a1', sha256: 'sha-a1', sortOrder: 0, downloaded: false),
        ],
      );
      fakeCatalog.nextOutcome = CatalogUpdated(makeSnapshot(collections: [
        makeCatalogCollection(id: 'r1', audios: [
          makeCatalogAudio(id: 'a1', sortOrder: 0),
          makeCatalogAudio(id: 'a2', sortOrder: 1),
        ]),
      ]));

      final stats = await sync.syncAll();
      expect(stats.audiosAdded, 1);

      final ids = await db.collectionDao.getAudioIds(localId);
      expect(ids, hasLength(2));
    });

    test('用例 3：远端移除音频，本地未下载 → 删 audio_items + junction', () async {
      final localId = await seedEnrolledCollection(
        db,
        remoteId: 'r1',
        audios: [
          (remoteAudioId: 'a1', sha256: 'sha-a1', sortOrder: 0, downloaded: false),
          (remoteAudioId: 'a2', sha256: 'sha-a2', sortOrder: 1, downloaded: false),
        ],
      );
      fakeCatalog.nextOutcome = CatalogUpdated(makeSnapshot(collections: [
        makeCatalogCollection(id: 'r1', audios: [
          makeCatalogAudio(id: 'a1', sortOrder: 0),
        ]),
      ]));

      final stats = await sync.syncAll();
      expect(stats.audiosRemoved, 1);
      expect(stats.audiosKeptAsOrphan, 0);

      final ids = await db.collectionDao.getAudioIds(localId);
      expect(ids, hasLength(1));
    });

    test('用例 4：远端移除音频，本地已下载 → 保留（行数不变）', () async {
      final localId = await seedEnrolledCollection(
        db,
        remoteId: 'r1',
        audios: [
          (remoteAudioId: 'a1', sha256: 'sha-a1', sortOrder: 0, downloaded: false),
          (remoteAudioId: 'a2', sha256: 'sha-a2', sortOrder: 1, downloaded: true),
        ],
      );
      fakeCatalog.nextOutcome = CatalogUpdated(makeSnapshot(collections: [
        makeCatalogCollection(id: 'r1', audios: [
          makeCatalogAudio(id: 'a1', sortOrder: 0),
        ]),
      ]));

      final stats = await sync.syncAll();
      expect(stats.audiosRemoved, 0);
      expect(stats.audiosKeptAsOrphan, 1);

      final ids = await db.collectionDao.getAudioIds(localId);
      expect(ids, hasLength(2), reason: '已下载的 a2 必须保留（本地不变性）');
    });

    test('用例 5：合集元信息变更 → 本地 name 被更新', () async {
      final localId = await seedEnrolledCollection(
        db,
        remoteId: 'r1',
        name: 'Old Name',
      );
      fakeCatalog.nextOutcome = CatalogUpdated(makeSnapshot(collections: [
        makeCatalogCollection(id: 'r1', name: 'New Name'),
      ]));

      await sync.syncAll();
      final row = await db.collectionDao.getById(localId);
      expect(row?.name, 'New Name');
    });

    test('用例 5b：远端音频 title 变更 → 本地 audio name 被更新', () async {
      final localId = await seedEnrolledCollection(
        db,
        remoteId: 'r1',
        audios: [
          (remoteAudioId: 'a1', sha256: 'sha-a1', sortOrder: 0, downloaded: false),
          (remoteAudioId: 'a2', sha256: 'sha-a2', sortOrder: 1, downloaded: true),
        ],
      );
      // catalog 把两条音频的 title 改了
      fakeCatalog.nextOutcome = CatalogUpdated(makeSnapshot(collections: [
        makeCatalogCollection(id: 'r1', audios: [
          makeCatalogAudio(id: 'a1', title: 'Renamed A1', sortOrder: 0),
          makeCatalogAudio(id: 'a2', title: 'Renamed A2', sortOrder: 1),
        ]),
      ]));

      await sync.syncAll();

      final a1 = await db.audioItemDao.getById('local-a1');
      final a2 = await db.audioItemDao.getById('local-a2');
      expect(a1?.name, 'Renamed A1', reason: '未下载音频也要同步 title');
      expect(a2?.name, 'Renamed A2', reason: '已下载音频同样要同步 title');
      // 不应影响 collection 数量或 junction
      expect(await _audioRowCount(), 2);
      expect(await _junctionCount(), 2);
      // 同时不应破坏已下载音频的 audioPath
      expect(a2?.audioPath, isNotNull);
      // 防回归：localId 仍然存在
      expect((await db.collectionDao.getById(localId))?.id, localId);
    });

    test('用例 6：合集 deprecate → republish（可逆性）', () async {
      final localId = await seedEnrolledCollection(db, remoteId: 'r1');
      // 手动标 deprecated
      await (db.update(db.collections)..where((t) => t.id.equals(localId))).write(
        CollectionsCompanion(
          deprecatedAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ),
      );
      // catalog 中重新出现
      fakeCatalog.nextOutcome = CatalogUpdated(makeSnapshot(collections: [
        makeCatalogCollection(id: 'r1'),
      ]));

      final stats = await sync.syncAll();
      expect(stats.collectionsUndeprecated, 1);

      final row = await db.collectionDao.getById(localId);
      expect(row?.deprecatedAt, isNull, reason: 'deprecate 应该被清空');
    });

    test('用例 7：sortOrder 变化 → junction sortOrder 被 update', () async {
      final localId = await seedEnrolledCollection(
        db,
        remoteId: 'r1',
        audios: [
          (remoteAudioId: 'a1', sha256: 'sha-a1', sortOrder: 0, downloaded: false),
          (remoteAudioId: 'a2', sha256: 'sha-a2', sortOrder: 1, downloaded: false),
        ],
      );
      // catalog 翻转 sortOrder
      fakeCatalog.nextOutcome = CatalogUpdated(makeSnapshot(collections: [
        makeCatalogCollection(id: 'r1', audios: [
          makeCatalogAudio(id: 'a1', sortOrder: 1),
          makeCatalogAudio(id: 'a2', sortOrder: 0),
        ]),
      ]));

      await sync.syncAll();
      // 拿出 junction 的 sortOrder
      final juncs = await (db.select(db.collectionAudioItems)
            ..where((t) => t.collectionId.equals(localId)))
          .get();
      final byAudioId = {for (final j in juncs) j.audioItemId: j.sortOrder};
      expect(byAudioId['local-a1'], 1);
      expect(byAudioId['local-a2'], 0);
    });

    test('用例 8：catalog 含未加入合集 → 仅已加入的被 diff，未加入的不写 DB', () async {
      // seed 1 已加入合集
      await seedEnrolledCollection(db, remoteId: 'r1');
      final collsBefore = (await db.select(db.collections).get()).length;

      // catalog 含 r1 + r2（r2 未加入）
      fakeCatalog.nextOutcome = CatalogUpdated(makeSnapshot(collections: [
        makeCatalogCollection(id: 'r1'),
        makeCatalogCollection(id: 'r2', name: 'Brand New'),
      ]));

      await sync.syncAll();
      final collsAfter = (await db.select(db.collections).get()).length;
      expect(collsAfter, collsBefore, reason: '不应给未加入的 r2 创建本地行');
    });
  });

  test('refresh 实际被调用一次（force / non-force 都会到 refresh）', () async {
    fakeCatalog.nextOutcome = const CatalogThrottled();
    await sync.syncAll();
    await sync.syncAll(force: true);
    expect(fakeCatalog.refreshCallCount, 2);
  });

  group('并发 syncAll 去重（inflight）', () {
    test('两个并发 syncAll 共享同一次执行，新发布音频不重复插入', () async {
      // 本地已加入合集，已有 r-a1 / r-a2
      await seedEnrolledCollection(
        db,
        remoteId: 'r-collA',
        audios: [
          (
            remoteAudioId: 'r-a1',
            sha256: 'sha-a1',
            sortOrder: 0,
            downloaded: false
          ),
          (
            remoteAudioId: 'r-a2',
            sha256: 'sha-a2',
            sortOrder: 1,
            downloaded: false
          ),
        ],
      );
      expect(await _audioRowCount(), 2);
      expect(await _junctionCount(), 2);

      // catalog 新增 r-a3 / r-a4
      final snapshot = makeSnapshot(collections: [
        makeCatalogCollection(id: 'r-collA', audios: [
          makeCatalogAudio(id: 'r-a1', sortOrder: 0),
          makeCatalogAudio(id: 'r-a2', sortOrder: 1),
          makeCatalogAudio(id: 'r-a3', sortOrder: 2),
          makeCatalogAudio(id: 'r-a4', sortOrder: 3),
        ]),
      ]);
      fakeCatalog.nextOutcome = CatalogUpdated(snapshot);

      // 并发触发两次 syncAll（模拟冷启动 3s trigger + initState 兜底重叠）
      await Future.wait([sync.syncAll(), sync.syncAll()]);

      // inflight 让底层 refresh 只被调用一次
      expect(fakeCatalog.refreshCallCount, 1);

      // 总行数 = 2 既有 + 2 新发布（各一次），junction 同
      expect(await _audioRowCount(), 4);
      expect(await _junctionCount(), 4);

      // 新发布音频每个只存一行
      final a3Rows = await (db.select(db.audioItems)
            ..where((t) => t.remoteAudioId.equals('r-a3')))
          .get();
      expect(a3Rows.length, 1);
      final a4Rows = await (db.select(db.audioItems)
            ..where((t) => t.remoteAudioId.equals('r-a4')))
          .get();
      expect(a4Rows.length, 1);
    });

    test('inflight 完成后可以重新触发新一轮 syncAll', () async {
      await seedEnrolledCollection(db, remoteId: 'r-collA');

      fakeCatalog.nextOutcome = CatalogUpdated(
        makeSnapshot(collections: [makeCatalogCollection(id: 'r-collA')]),
      );
      await sync.syncAll();
      expect(fakeCatalog.refreshCallCount, 1);

      // 上一轮结束后，再次触发应发起新的 refresh（不是复用旧 inflight）
      await sync.syncAll();
      expect(fakeCatalog.refreshCallCount, 2);
    });
  });
}
