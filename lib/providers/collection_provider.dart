import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../analytics/analytics_providers.dart';
import '../analytics/models/event_names.dart';
import '../database/app_database.dart' as db;
import '../database/providers.dart';
import '../models/collection.dart';
import '../services/app_logger.dart';
import 'audio_library_provider.dart';

part 'collection_provider.g.dart';

enum CollectionSortType { nameAsc, nameDesc, dateAsc, dateDesc }

class CollectionState {
  final List<Collection> rawCollections;
  final bool isLoading;
  final CollectionSortType sortType;

  /// 缓存每个合集的音频 ID 列表（从 junction 表加载）
  final Map<String, List<String>> audioIdsMap;

  const CollectionState({
    this.rawCollections = const [],
    this.isLoading = false,
    this.sortType = CollectionSortType.dateDesc,
    this.audioIdsMap = const {},
  });

  bool get isEmpty => rawCollections.isEmpty;

  /// 获取合集的音频 ID 列表
  List<String> getAudioIds(String collectionId) {
    return audioIdsMap[collectionId] ?? [];
  }

  /// 获取合集的音频数量
  int getAudioCount(String collectionId) {
    return audioIdsMap[collectionId]?.length ?? 0;
  }

  /// 反向索引：audioId -> 所属合集 ID 列表
  Map<String, List<String>> get audioToCollectionsMap {
    final result = <String, List<String>>{};
    for (final entry in audioIdsMap.entries) {
      for (final audioId in entry.value) {
        (result[audioId] ??= []).add(entry.key);
      }
    }
    return result;
  }

  /// 排序后的合集列表（置顶项始终在前）
  List<Collection> get collections {
    final sorted = List<Collection>.from(rawCollections);
    switch (sortType) {
      case CollectionSortType.nameAsc:
        sorted.sort((a, b) => a.name.compareTo(b.name));
      case CollectionSortType.nameDesc:
        sorted.sort((a, b) => b.name.compareTo(a.name));
      case CollectionSortType.dateAsc:
        sorted.sort((a, b) => a.createdDate.compareTo(b.createdDate));
      case CollectionSortType.dateDesc:
        sorted.sort((a, b) => b.createdDate.compareTo(a.createdDate));
    }
    // 置顶项始终排在最前面（稳定排序保持原有顺序）
    sorted.sort((a, b) {
      if (a.isPinned == b.isPinned) return 0;
      return a.isPinned ? -1 : 1;
    });
    return sorted;
  }

  CollectionState copyWith({
    List<Collection>? rawCollections,
    bool? isLoading,
    CollectionSortType? sortType,
    Map<String, List<String>>? audioIdsMap,
  }) {
    return CollectionState(
      rawCollections: rawCollections ?? this.rawCollections,
      isLoading: isLoading ?? this.isLoading,
      sortType: sortType ?? this.sortType,
      audioIdsMap: audioIdsMap ?? this.audioIdsMap,
    );
  }
}

@Riverpod(keepAlive: true)
class CollectionList extends _$CollectionList {
  @override
  CollectionState build() {
    return const CollectionState();
  }

  Future<void> loadCollections() async {
    state = state.copyWith(isLoading: true);

    try {
      final dao = ref.read(collectionDaoProvider);
      final dbCollections = await dao.getAllActive();
      AppLogger.log(
        'StartupLoad',
        'collections query ok: dbRows=${dbCollections.length}',
      );

      final collections = dbCollections
          .map(
            (row) => Collection(
              id: row.id,
              name: row.name,
              createdDate: row.createdDate,
              isPinned: row.isPinned,
              source: CollectionSource.fromString(row.source),
              remoteId: row.remoteId,
              coverUrl: row.coverUrl,
              description: row.description,
              deprecatedAt: row.deprecatedAt,
              podcastInputUrl: row.podcastInputUrl,
              podcastFeedUrl: row.podcastFeedUrl,
              podcastMetaJson: row.podcastMetaJson,
              podcastLastRefreshedAt: row.podcastLastRefreshedAt,
              podcastLastRefreshError: row.podcastLastRefreshError,
            ),
          )
          .toList();

      // 加载每个合集的音频 ID 列表
      final audioIdsMap = <String, List<String>>{};
      for (final c in collections) {
        audioIdsMap[c.id] = await dao.getAudioIds(c.id);
      }

      final localCount = collections.where((c) => !c.isOfficial).length;
      final officialCount = collections.where((c) => c.isOfficial).length;
      final deprecatedCount = collections.where((c) => c.isDeprecated).length;
      final linkedAudioCount = audioIdsMap.values.fold<int>(
        0,
        (total, ids) => total + ids.length,
      );
      AppLogger.log(
        'StartupLoad',
        'collections mapped: visible=${collections.length}, local=$localCount, '
            'official=$officialCount, deprecated=$deprecatedCount, '
            'linkedAudios=$linkedAudioCount',
      );

      state = state.copyWith(
        rawCollections: collections,
        isLoading: false,
        audioIdsMap: audioIdsMap,
      );
    } catch (e, st) {
      AppLogger.log('StartupLoad', 'collections load failed: $e');
      AppLogger.log('StartupLoad', st.toString());
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  Future<void> createCollection(String name) async {
    final now = DateTime.now();
    final collection = Collection(
      id: now.millisecondsSinceEpoch.toString(),
      name: name,
      createdDate: now,
    );
    state = state.copyWith(
      rawCollections: [...state.rawCollections, collection],
    );
    await _upsertCollection(collection);
    ref.read(analyticsServiceProvider).track(Events.collectionCreate);
  }

  Future<void> deleteCollection(String id) async {
    // 埋点：删除合集
    final collection = state.rawCollections
        .where((c) => c.id == id)
        .firstOrNull;
    if (collection != null) {
      ref.read(analyticsServiceProvider).track(Events.collectionDelete, {
        EventParams.collectionId: id,
        EventParams.collectionName: collection.name,
      });
    }

    final newMap = Map<String, List<String>>.from(state.audioIdsMap)
      ..remove(id);
    state = state.copyWith(
      rawCollections: state.rawCollections.where((c) => c.id != id).toList(),
      audioIdsMap: newMap,
    );
    final dao = ref.read(collectionDaoProvider);
    await dao.hardDelete(id);
  }

  Future<void> renameCollection(String id, String newName) async {
    final collections = [...state.rawCollections];
    final index = collections.indexWhere((c) => c.id == id);
    if (index != -1) {
      collections[index] = collections[index].copyWith(name: newName);
      state = state.copyWith(rawCollections: collections);
      await _upsertCollection(collections[index]);
    }
  }

  /// 切换合集置顶状态（乐观更新 + 持久化）
  Future<void> togglePin(String id) async {
    final collections = [...state.rawCollections];
    final index = collections.indexWhere((c) => c.id == id);
    if (index != -1) {
      collections[index] = collections[index].copyWith(
        isPinned: !collections[index].isPinned,
      );
      state = state.copyWith(rawCollections: collections);
      await _upsertCollection(collections[index]);
    }
  }

  Future<void> addAudioToCollection(String collectionId, String audioId) async {
    final dao = ref.read(collectionDaoProvider);
    await dao.addAudio(collectionId, audioId);

    // 更新缓存
    final newMap = Map<String, List<String>>.from(state.audioIdsMap);
    final ids = List<String>.from(newMap[collectionId] ?? []);
    if (!ids.contains(audioId)) {
      ids.add(audioId);
      newMap[collectionId] = ids;
      state = state.copyWith(audioIdsMap: newMap);
    }
  }

  Future<void> removeAudioFromCollection(
    String collectionId,
    String audioId,
  ) async {
    final dao = ref.read(collectionDaoProvider);
    await dao.removeAudio(collectionId, audioId);

    // 更新缓存
    final newMap = Map<String, List<String>>.from(state.audioIdsMap);
    final ids = List<String>.from(newMap[collectionId] ?? []);
    ids.remove(audioId);
    newMap[collectionId] = ids;
    state = state.copyWith(audioIdsMap: newMap);
  }

  /// 从所有合集中移除指定音频的引用（当音频从音频库删除时调用）
  /// CASCADE 已自动清理 junction 表，此方法仅更新内存缓存
  Future<void> removeAudioFromAllCollections(String audioId) async {
    final newMap = Map<String, List<String>>.from(state.audioIdsMap);
    for (final key in newMap.keys) {
      newMap[key] = List<String>.from(newMap[key]!)..remove(audioId);
    }
    state = state.copyWith(audioIdsMap: newMap);
  }

  /// 批量更新音频的合集归属（diff 模式）
  ///
  /// 对比当前归属和目标归属，只执行增删操作。
  Future<void> updateAudioCollectionMembership(
    String audioId,
    Set<String> targetCollectionIds,
  ) async {
    final currentCollections =
        state.audioToCollectionsMap[audioId]?.toSet() ?? <String>{};
    final toAdd = targetCollectionIds.difference(currentCollections);
    final toRemove = currentCollections.difference(targetCollectionIds);

    for (final collectionId in toAdd) {
      await addAudioToCollection(collectionId, audioId);
    }
    for (final collectionId in toRemove) {
      await removeAudioFromCollection(collectionId, audioId);
    }
  }

  /// 获取合集中的音频 ID 列表
  Future<List<String>> getAudioIdsForCollection(String collectionId) async {
    final dao = ref.read(collectionDaoProvider);
    return dao.getAudioIds(collectionId);
  }

  /// 获取合集中的音频数量
  Future<int> getAudioCountForCollection(String collectionId) async {
    final dao = ref.read(collectionDaoProvider);
    return dao.getAudioCount(collectionId);
  }

  Collection? getCollectionById(String id) {
    try {
      return state.rawCollections.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  void setSortType(CollectionSortType type) {
    state = state.copyWith(sortType: type);
  }

  /// 将 Collection 模型写入 Drift 数据库
  Future<void> _upsertCollection(Collection collection) async {
    final dao = ref.read(collectionDaoProvider);
    await dao.upsert(
      db.CollectionsCompanion(
        id: Value(collection.id),
        name: Value(collection.name),
        createdDate: Value(collection.createdDate),
        isPinned: Value(collection.isPinned),
        source: Value(collection.source.storageValue),
        remoteId: Value(collection.remoteId),
        coverUrl: Value(collection.coverUrl),
        description: Value(collection.description),
        deprecatedAt: Value(collection.deprecatedAt),
        podcastInputUrl: Value(collection.podcastInputUrl),
        podcastFeedUrl: Value(collection.podcastFeedUrl),
        podcastMetaJson: Value(collection.podcastMetaJson),
        podcastLastRefreshedAt: Value(collection.podcastLastRefreshedAt),
        podcastLastRefreshError: Value(collection.podcastLastRefreshError),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // ── Podcast 专用方法 ─────────────────────────────────────────────────

  /// 创建 podcast 合集（已由 PodcastRepository 填充完整 Collection 对象）。
  Future<void> createPodcastCollection(Collection collection) async {
    state = state.copyWith(
      rawCollections: [...state.rawCollections, collection],
      audioIdsMap: {...state.audioIdsMap, collection.id: []},
    );
    await _upsertCollection(collection);
  }

  /// 更新 podcast 合集元信息（刷新时间、coverUrl、metaJson）。
  Future<void> updatePodcastCollection(Collection updated) async {
    final idx = state.rawCollections.indexWhere((c) => c.id == updated.id);
    if (idx == -1) return;
    final list = [...state.rawCollections]..[idx] = updated;
    state = state.copyWith(rawCollections: list);
    await _upsertCollection(updated);
  }

  /// 退订 podcast 合集：彻底清理合集**独占**的所有单集（DB 记录 + 已下载音频/字幕
  /// 文件 + 学习进度/书签等关联数据），再删除合集本身。
  ///
  /// 与通用 [deleteCollection] 不同：本地手建合集的音频可能被多个合集共享，删除合集
  /// 不应删音频；而 podcast 单集由该合集独占，退订即应一并清除，避免孤儿条目与文件残留。
  /// 逐个复用 [AudioLibrary.removeAudioItem] 完成单条目的完整清理（删文件 + CASCADE +
  /// 内存状态），最后调用 [deleteCollection] 删合集行。
  Future<void> unsubscribePodcastCollection(String id) async {
    final audioIds = List<String>.from(state.getAudioIds(id));
    final audioLib = ref.read(audioLibraryProvider.notifier);
    for (final audioId in audioIds) {
      await audioLib.removeAudioItem(audioId);
    }
    await deleteCollection(id);
  }
}
