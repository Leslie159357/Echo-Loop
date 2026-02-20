import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/collection.dart';
import '../services/storage_service.dart';

part 'collection_provider.g.dart';

enum CollectionSortType {
  nameAsc,
  nameDesc,
  dateAsc,
  dateDesc,
  custom,
}

enum CollectionViewMode {
  grid,
  list,
}

class CollectionState {
  final List<Collection> rawCollections;
  final bool isLoading;
  final CollectionViewMode viewMode;
  final CollectionSortType sortType;

  const CollectionState({
    this.rawCollections = const [],
    this.isLoading = false,
    this.viewMode = CollectionViewMode.list,
    this.sortType = CollectionSortType.dateDesc,
  });

  bool get isEmpty => rawCollections.isEmpty;

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
      case CollectionSortType.custom:
        sorted.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }
    return sorted;
  }

  CollectionState copyWith({
    List<Collection>? rawCollections,
    bool? isLoading,
    CollectionViewMode? viewMode,
    CollectionSortType? sortType,
  }) {
    return CollectionState(
      rawCollections: rawCollections ?? this.rawCollections,
      isLoading: isLoading ?? this.isLoading,
      viewMode: viewMode ?? this.viewMode,
      sortType: sortType ?? this.sortType,
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
    final collections = await StorageService.loadCollections();
    state = state.copyWith(rawCollections: collections, isLoading: false);
  }

  Future<void> createCollection(String name) async {
    final collection = Collection(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      createdDate: DateTime.now(),
      sortOrder: state.rawCollections.length,
    );
    state = state.copyWith(
      rawCollections: [...state.rawCollections, collection],
    );
    await _save();
  }

  Future<void> deleteCollection(String id) async {
    state = state.copyWith(
      rawCollections: state.rawCollections.where((c) => c.id != id).toList(),
    );
    await _save();
  }

  Future<void> renameCollection(String id, String newName) async {
    final collections = [...state.rawCollections];
    final index = collections.indexWhere((c) => c.id == id);
    if (index != -1) {
      collections[index] = collections[index].copyWith(name: newName);
      state = state.copyWith(rawCollections: collections);
      await _save();
    }
  }

  Future<void> toggleStar(String id) async {
    final collections = [...state.rawCollections];
    final index = collections.indexWhere((c) => c.id == id);
    if (index != -1) {
      collections[index] = collections[index].copyWith(
        isStarred: !collections[index].isStarred,
      );
      state = state.copyWith(rawCollections: collections);
      await _save();
    }
  }

  Future<void> addAudioToCollection(
    String collectionId,
    String audioId,
  ) async {
    final collections = [...state.rawCollections];
    final index = collections.indexWhere((c) => c.id == collectionId);
    if (index != -1) {
      final ids = List<String>.from(collections[index].audioItemIds);
      if (!ids.contains(audioId)) {
        ids.add(audioId);
        collections[index] =
            collections[index].copyWith(audioItemIds: ids);
        state = state.copyWith(rawCollections: collections);
        await _save();
      }
    }
  }

  Future<void> removeAudioFromCollection(
    String collectionId,
    String audioId,
  ) async {
    final collections = [...state.rawCollections];
    final index = collections.indexWhere((c) => c.id == collectionId);
    if (index != -1) {
      final ids = List<String>.from(collections[index].audioItemIds);
      ids.remove(audioId);
      collections[index] =
          collections[index].copyWith(audioItemIds: ids);
      state = state.copyWith(rawCollections: collections);
      await _save();
    }
  }

  Collection? getCollectionById(String id) {
    try {
      return state.rawCollections.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  void toggleViewMode() {
    state = state.copyWith(
      viewMode: state.viewMode == CollectionViewMode.grid
          ? CollectionViewMode.list
          : CollectionViewMode.grid,
    );
  }

  void setSortType(CollectionSortType type) {
    state = state.copyWith(sortType: type);
  }

  Future<void> reorderCollections(int oldIndex, int newIndex) async {
    final sorted = state.collections;
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = sorted.removeAt(oldIndex);
    sorted.insert(newIndex, item);

    final collections = [...state.rawCollections];
    for (int i = 0; i < sorted.length; i++) {
      final idx = collections.indexWhere((c) => c.id == sorted[i].id);
      if (idx != -1) {
        collections[idx] = collections[idx].copyWith(sortOrder: i);
      }
    }

    state = state.copyWith(rawCollections: collections);
    await _save();
  }

  Future<void> applyCustomOrder(List<String> orderedIds) async {
    final collections = [...state.rawCollections];
    for (int i = 0; i < orderedIds.length; i++) {
      final idx = collections.indexWhere((c) => c.id == orderedIds[i]);
      if (idx != -1) {
        collections[idx] = collections[idx].copyWith(sortOrder: i);
      }
    }
    state = state.copyWith(rawCollections: collections);
    await _save();
  }

  Future<void> _save() async {
    await StorageService.saveCollections(state.rawCollections);
  }
}
