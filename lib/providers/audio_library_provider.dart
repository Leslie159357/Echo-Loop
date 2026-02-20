import 'package:universal_io/io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/audio_item.dart';
import '../services/storage_service.dart';

part 'audio_library_provider.g.dart';

class AudioLibraryState {
  final List<AudioItem> audioItems;
  final bool isLoading;

  const AudioLibraryState({
    this.audioItems = const [],
    this.isLoading = false,
  });

  bool get isEmpty => audioItems.isEmpty;

  AudioLibraryState copyWith({
    List<AudioItem>? audioItems,
    bool? isLoading,
  }) {
    return AudioLibraryState(
      audioItems: audioItems ?? this.audioItems,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

@Riverpod(keepAlive: true)
class AudioLibrary extends _$AudioLibrary {
  @override
  AudioLibraryState build() {
    return const AudioLibraryState();
  }

  Future<void> loadLibrary() async {
    state = state.copyWith(isLoading: true);

    final allItems = await StorageService.loadAudioLibrary();

    final validItems = <AudioItem>[];
    bool hasInvalidItems = false;
    bool hasMigratedItems = false;

    for (final item in allItems) {
      AudioItem processedItem = item;

      if (item.audioPath.startsWith('/')) {
        final migratedItem = await _migrateToRelativePath(item);
        if (migratedItem != null) {
          processedItem = migratedItem;
          hasMigratedItems = true;
          print('Migrated ${item.name} from absolute to relative path');
        } else {
          hasInvalidItems = true;
          print('Failed to migrate ${item.name}, marking as invalid');
          continue;
        }
      }

      final fullAudioPath = await processedItem.getFullAudioPath();
      final audioFile = File(fullAudioPath);
      final audioExists = await audioFile.exists();

      if (audioExists) {
        validItems.add(processedItem);
      } else {
        hasInvalidItems = true;
        print(
          'Removed invalid audio item: ${processedItem.name} (audio file not found at: $fullAudioPath)',
        );
      }
    }

    state = state.copyWith(audioItems: validItems, isLoading: false);

    if (hasInvalidItems || hasMigratedItems) {
      await _saveLibrary();
      if (hasInvalidItems) {
        print(
          'Cleaned up ${allItems.length - validItems.length} invalid audio items',
        );
      }
      if (hasMigratedItems) {
        print('Migrated paths from absolute to relative format');
      }
    }
  }

  Future<AudioItem?> _migrateToRelativePath(AudioItem item) async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final docsPath = docs.path;

      if (!item.audioPath.startsWith(docsPath)) {
        return null;
      }

      final relativeAudioPath =
          item.audioPath.substring(docsPath.length + 1);

      String? relativeTranscriptPath;
      if (item.transcriptPath != null &&
          item.transcriptPath!.startsWith(docsPath)) {
        relativeTranscriptPath =
            item.transcriptPath!.substring(docsPath.length + 1);
      } else if (item.transcriptPath != null &&
          !item.transcriptPath!.startsWith('/')) {
        relativeTranscriptPath = item.transcriptPath;
      }

      return item.copyWith(
        audioPath: relativeAudioPath,
        transcriptPath: relativeTranscriptPath,
      );
    } catch (e) {
      print('Error migrating path for ${item.name}: $e');
      return null;
    }
  }

  Future<void> addAudioItem(AudioItem item) async {
    state = state.copyWith(
      audioItems: [...state.audioItems, item],
    );
    await _saveLibrary();
  }

  Future<void> removeAudioItem(String id) async {
    AudioItem? item;
    try {
      item = state.audioItems.firstWhere((item) => item.id == id);
    } catch (e) {
      print('Audio item not found: $id');
      return;
    }

    try {
      final audioPath = await item.getFullAudioPath();
      final audioFile = File(audioPath);
      if (await audioFile.exists()) {
        await audioFile.delete();
        print('Deleted audio file: $audioPath');
      }
    } catch (e) {
      print('Error deleting audio file: $e');
    }

    if (item.hasTranscript) {
      try {
        final transcriptPath = await item.getFullTranscriptPath();
        if (transcriptPath != null) {
          final transcriptFile = File(transcriptPath);
          if (await transcriptFile.exists()) {
            await transcriptFile.delete();
            print('Deleted transcript file: $transcriptPath');
          }
        }
      } catch (e) {
        print('Error deleting transcript file: $e');
      }
    }

    state = state.copyWith(
      audioItems: state.audioItems.where((item) => item.id != id).toList(),
    );
    await _saveLibrary();
  }

  Future<void> updateAudioItem(AudioItem updatedItem) async {
    final items = [...state.audioItems];
    final index = items.indexWhere((item) => item.id == updatedItem.id);
    if (index != -1) {
      items[index] = updatedItem;
      state = state.copyWith(audioItems: items);
      await _saveLibrary();
    }
  }

  AudioItem? getItemById(String id) {
    try {
      return state.audioItems.firstWhere((item) => item.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<void> _saveLibrary() async {
    await StorageService.saveAudioLibrary(state.audioItems);
  }
}
