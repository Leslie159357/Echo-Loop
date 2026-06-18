import 'package:drift/drift.dart';
import 'package:just_audio/just_audio.dart' as ja;
import '../../database/app_database.dart' hide AudioItem;
import '../../database/daos/playback_state_dao.dart';
import '../../models/audio_item.dart';
import '../../services/app_logger.dart';
import '../../models/listening_practice_state.dart';

/// 播放状态持久化
/// 使用 Drift 数据库存储播放断点，精简为只存 position + playlistMode
class PlaybackStateStorage {
  static Future<void> savePlaybackState(
    AudioItem audioItem,
    ja.AudioPlayer audioPlayer,
    ListeningPracticeState state, {
    required PlaybackStateDao dao,
    bool silent = false,
  }) async {
    await dao.saveState(
      PlaybackStatesCompanion(
        audioItemId: Value(audioItem.id),
        positionMs: Value(audioPlayer.position.inMilliseconds),
        playlistMode: Value(state.playlistMode.index),
        savedAt: Value(DateTime.now()),
      ),
    );
    // 跨句自动保存为高频路径，静默以免日志刷屏；仅页面退出时的保存留日志。
    if (!silent) {
      AppLogger.log('Player', '✓ 保存播放状态: ${audioItem.name}');
    }
  }

  static Future<PlaybackStateRestoreResult?> loadPlaybackState(
    String audioId, {
    required PlaybackStateDao dao,
  }) async {
    final dbState = await dao.getByAudioId(audioId);
    if (dbState == null) return null;

    try {
      return PlaybackStateRestoreResult(
        position: Duration(milliseconds: dbState.positionMs),
        playlistMode: PlaylistMode.values[dbState.playlistMode],
      );
    } catch (e) {
      AppLogger.log('Player', '⚠ 加载播放状态失败: $e');
      return null;
    }
  }
}

/// 播放状态恢复结果
/// 精简版：只包含 position 和 playlistMode
/// currentFullIndex / currentBookmarkIndex 从 position 通过 SentenceTracker 计算
class PlaybackStateRestoreResult {
  final Duration? position;
  final PlaylistMode? playlistMode;

  PlaybackStateRestoreResult({this.position, this.playlistMode});
}
