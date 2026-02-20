import 'package:just_audio/just_audio.dart' as ja;
import '../../services/storage_service.dart';
import '../../models/audio_item.dart';
import '../../models/listening_practice_state.dart';

class PlaybackStateStorage {
  static Future<void> savePlaybackState(
    AudioItem audioItem,
    ja.AudioPlayer audioPlayer,
    ListeningPracticeState state,
  ) async {
    final stateMap = {
      'position': audioPlayer.position.inMilliseconds,
      'currentFullIndex': state.currentFullIndex,
      'currentBookmarkIndex': state.currentBookmarkIndex,
      'playlistMode': state.playlistMode.index,
      'timestamp': DateTime.now().toIso8601String(),
    };

    await StorageService.savePlaybackState(audioItem.id, stateMap);
    print('Saved playback state for ${audioItem.name}');
  }

  static Future<PlaybackStateRestoreResult?> loadPlaybackState(
    String audioId,
  ) async {
    final stateMap = await StorageService.loadPlaybackState(audioId);
    if (stateMap == null) return null;

    try {
      return PlaybackStateRestoreResult(
        position: stateMap['position'] != null
            ? Duration(milliseconds: stateMap['position'] as int)
            : null,
        currentFullIndex: stateMap['currentFullIndex'] as int?,
        currentBookmarkIndex: stateMap['currentBookmarkIndex'] as int?,
        playlistMode: stateMap['playlistMode'] != null
            ? PlaylistMode.values[stateMap['playlistMode'] as int]
            : null,
      );
    } catch (e) {
      print('Error loading playback state: $e');
      return null;
    }
  }
}

class PlaybackStateRestoreResult {
  final Duration? position;
  final int? currentFullIndex;
  final int? currentBookmarkIndex;
  final PlaylistMode? playlistMode;

  PlaybackStateRestoreResult({
    this.position,
    this.currentFullIndex,
    this.currentBookmarkIndex,
    this.playlistMode,
  });
}
