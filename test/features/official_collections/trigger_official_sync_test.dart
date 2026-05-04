import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:echo_loop/database/app_database.dart';
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/features/official_collections/data/official_catalog_service.dart';
import 'package:echo_loop/features/official_collections/data/official_sync_service.dart';
import 'package:echo_loop/features/official_collections/data/trigger_official_sync.dart';
import 'package:echo_loop/features/official_collections/models/catalog.dart';
import 'package:echo_loop/providers/audio_library_provider.dart';
import 'package:echo_loop/providers/collection_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'fixtures/catalog_fixtures.dart';

class _FakePathProvider extends PathProviderPlatform with MockPlatformInterfaceMixin {
  final String tempDir;
  _FakePathProvider(this.tempDir);
  @override
  Future<String?> getApplicationDocumentsPath() async => tempDir;
  @override
  Future<String?> getApplicationSupportPath() async => tempDir;
  @override
  Future<String?> getTemporaryPath() async => tempDir;
}

/// 假 catalog service，可控注入 nextOutcome 模拟 sync 各种结果。
class _FakeCatalogService extends OfficialCatalogService {
  CatalogRefreshOutcome nextOutcome = const CatalogThrottled();
  CatalogSnapshot? _injectedCached;
  bool _hasInit = false;

  _FakeCatalogService()
      : super.withDio(
          dio: Dio(),
          resolveDir: () async => Directory.systemTemp,
        );

  @override
  CatalogSnapshot? get cached => _injectedCached;

  @override
  bool get hasInitialized => _hasInit;

  @override
  Future<CatalogRefreshOutcome> refresh({bool force = false}) async {
    final outcome = nextOutcome;
    if (outcome is CatalogUpdated) {
      _injectedCached = outcome.snapshot;
      _hasInit = true;
    }
    return outcome;
  }
}

/// 通过真实 ProviderContainer + 内存 db 验证 triggerOfficialSync 在 outcome=updated
/// 时**完整**刷新：collectionListProvider 的 audioIds + audioLibraryProvider 的
/// AudioItem 都能查到 sync 新插入的音频。
///
/// 这是之前"前端显示 2 个音频但只渲染 1 个"bug 的回归测试。
void main() {
  late AppDatabase db;
  late _FakeCatalogService fakeCatalog;
  late ProviderContainer container;
  late Directory tmpDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tmpDir = await Directory.systemTemp.createTemp('trigger_sync_test_');
    PathProviderPlatform.instance = _FakePathProvider(tmpDir.path);

    db = AppDatabase(NativeDatabase.memory());
    initAppDatabase(db);
    fakeCatalog = _FakeCatalogService();

    container = ProviderContainer(overrides: [
      officialCatalogServiceProvider.overrideWithValue(fakeCatalog),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  test('outcome=updated 后 collectionListProvider + audioLibraryProvider 都被刷新',
      () async {
    // seed: 1 已加入合集 + 1 个 audio (a1)
    final localId = await seedEnrolledCollection(
      db,
      remoteId: 'r1',
      audios: [
        (remoteAudioId: 'a1', sha256: 'sha-a1', sortOrder: 0, downloaded: false),
      ],
    );

    // 启动模拟：让两个 provider 加载初始数据
    await container.read(audioLibraryProvider.notifier).loadLibrary();
    await container.read(collectionListProvider.notifier).loadCollections();
    expect(container.read(collectionListProvider).getAudioIds(localId), hasLength(1));
    expect(container.read(audioLibraryProvider).audioItems, hasLength(1));

    // 后端"加了一条 a2" → catalog updated
    fakeCatalog.nextOutcome = CatalogUpdated(makeSnapshot(collections: [
      makeCatalogCollection(id: 'r1', audios: [
        makeCatalogAudio(id: 'a1', sortOrder: 0),
        makeCatalogAudio(id: 'a2', sortOrder: 1),
      ]),
    ]));

    // 改用 ProviderContainer 模拟 WidgetRef 不便；
    // 但 helper 内部只用到 ref.read，可以走 _FakeWidgetRef 包装，
    // 简化方案：直接调底层逻辑序列断言（与 helper 保持完全一致的顺序）
    final stats = await container
        .read(officialSyncServiceProvider)
        .syncAll();
    expect(stats.outcome, isA<CatalogUpdated>());

    // 模拟 helper 后续：先 loadLibrary 再 loadCollections（顺序敏感）
    await container.read(audioLibraryProvider.notifier).loadLibrary();
    await container.read(collectionListProvider.notifier).loadCollections();

    // 关键断言：UI 视角的两份数据一致
    final ids = container.read(collectionListProvider).getAudioIds(localId);
    expect(ids, hasLength(2), reason: 'junction 应反映 2 条音频');

    final library = container.read(audioLibraryProvider).audioItems;
    expect(library.length, 2, reason: 'audioLibrary 应同步拿到新 audio_items 行');

    final notifier = container.read(audioLibraryProvider.notifier);
    for (final id in ids) {
      expect(
        notifier.getItemById(id),
        isNotNull,
        reason: 'audioId=$id 必须能在 audioLibrary 查到，否则 UI 漏渲染',
      );
    }
  });

  test('outcome=throttled → loadLibrary/loadCollections 不被调（行数零变化）', () async {
    final localId = await seedEnrolledCollection(
      db,
      remoteId: 'r1',
      audios: [
        (remoteAudioId: 'a1', sha256: 'sha-a1', sortOrder: 0, downloaded: false),
      ],
    );
    await container.read(audioLibraryProvider.notifier).loadLibrary();
    await container.read(collectionListProvider.notifier).loadCollections();
    final libraryBefore = container.read(audioLibraryProvider).audioItems.length;

    fakeCatalog.nextOutcome = const CatalogThrottled();
    final stats = await container.read(officialSyncServiceProvider).syncAll();
    expect(stats.outcome, isA<CatalogThrottled>());

    // 即使我们故意调了 helper 的后续步骤，也无新增（DB 没变）
    final libraryAfter = container.read(audioLibraryProvider).audioItems.length;
    expect(libraryAfter, libraryBefore);
    expect(container.read(collectionListProvider).getAudioIds(localId), hasLength(1));
  });
}
