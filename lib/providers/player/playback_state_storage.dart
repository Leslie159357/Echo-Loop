import 'package:just_audio/just_audio.dart' as ja;
import '../../services/storage_service.dart';
import '../../models/audio_item.dart';
import 'player_state.dart';

/// 播放状态持久化
/// 负责保存和恢复播放状态
class PlaybackStateStorage {
  /// 保存当前播放状态
  static Future<void> savePlaybackState(
    AudioItem audioItem,
    ja.AudioPlayer audioPlayer,
    PlayerState state,
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

  /// 恢复播放状态
  static Future<void> restorePlaybackState(
    AudioItem audioItem,
    ja.AudioPlayer audioPlayer,
    PlayerState state,
  ) async {
    final stateMap = await StorageService.loadPlaybackState(audioItem.id);
    if (stateMap == null) return;

    try {
      // 恢复播放模式
      if (stateMap['playlistMode'] != null) {
        state.setPlaylistMode(
          PlaylistMode.values[stateMap['playlistMode'] as int],
        );
      }

      // 恢复索引
      if (stateMap['currentFullIndex'] != null) {
        state.setCurrentFullIndex(stateMap['currentFullIndex'] as int?);
      }
      if (stateMap['currentBookmarkIndex'] != null) {
        state.setCurrentBookmarkIndex(stateMap['currentBookmarkIndex'] as int?);
      }

      // 恢复播放位置
      if (stateMap['position'] != null) {
        final position = Duration(milliseconds: stateMap['position'] as int);
        await audioPlayer.seek(position);
      }

      print('Restored playback state for ${audioItem.name}');
    } catch (e) {
      print('Error restoring playback state: $e');
    }
  }
}
