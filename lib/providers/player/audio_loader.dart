import 'package:just_audio/just_audio.dart';
import '../../models/audio_item.dart';
import '../../models/sentence.dart';
import '../../services/subtitle_parser.dart';

/// 音频加载器
/// 负责加载音频文件和字幕
class AudioLoader {
  /// 加载音频文件
  static Future<Duration?> loadAudioFile(
    AudioPlayer audioPlayer,
    AudioItem audioItem,
    double playbackSpeed,
  ) async {
    try {
      final fullAudioPath = await audioItem.getFullAudioPath();
      await audioPlayer.setFilePath(fullAudioPath);
      await audioPlayer.setSpeed(playbackSpeed);

      // 获取完整音频时长
      Duration? duration = audioPlayer.duration;
      if (duration == null) {
        await audioPlayer.durationStream.first;
        duration = audioPlayer.duration;
      }
      
      return duration;
    } catch (e) {
      print('Error loading audio file: $e');
      rethrow;
    }
  }
  
  /// 加载字幕文件
  static Future<List<Sentence>> loadTranscript(AudioItem audioItem) async {
    if (!audioItem.hasTranscript) {
      return [];
    }
    
    try {
      final fullTranscriptPath = await audioItem.getFullTranscriptPath();
      if (fullTranscriptPath != null) {
        return await SubtitleParser.parseSubtitle(fullTranscriptPath);
      }
      return [];
    } catch (e) {
      print('Error loading transcript: $e');
      return [];
    }
  }
}
