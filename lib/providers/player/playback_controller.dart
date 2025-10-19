import 'dart:async';
import 'package:just_audio/just_audio.dart' as ja;
import '../../models/sentence.dart';
import '../../models/playback_settings.dart';
import 'player_state.dart';

/// 播放控制器
/// 负责核心的播放控制逻辑
class PlaybackController {
  final ja.AudioPlayer audioPlayer;
  final PlayerState state;

  PlaybackController({required this.audioPlayer, required this.state});

  /// 检查会话是否有效
  bool isActiveSession(int sessionId) {
    return sessionId == state.playbackSessionId;
  }

  /// 播放单个句子一次（基础方法）
  Future<void> playSingleSentenceOnce(Sentence sentence, int sessionId) async {
    if (!isActiveSession(sessionId)) {
      print("playSingleSentenceOnce: session cancelled");
      return;
    }

    // 使用 setClip 限定播放范围
    state.setClipStart(sentence.startTime);
    await audioPlayer.setClip(start: sentence.startTime, end: sentence.endTime);

    print("playSingleSentenceOnce: play begin");
    await audioPlayer.play();

    // 等到本次播放结束或被打断
    await audioPlayer.playerStateStream.firstWhere(
      (s) =>
          !isActiveSession(sessionId) || // 会话被取消
          s.processingState == ja.ProcessingState.completed || // 播放到片段末尾
          (!s.playing &&
              s.processingState == ja.ProcessingState.ready), // 被暂停/停止
    );
    print("playSingleSentenceOnce: play end");
  }

  /// 播放单个句子（带循环和间隔）
  Future<void> playSingleSentenceWithLoop(
    Sentence sentence,
    int sessionId,
    PlaybackSettings settings,
  ) async {
    final loopCount = settings.loopEnabled ? settings.loopCount : 1;
    final pauseInterval = settings.pauseInterval;

    // 循环播放当前句子
    for (int loop = 0; loop < loopCount; loop++) {
      if (!isActiveSession(sessionId)) {
        print("playSingleSentenceWithLoop: break at loop $loop");
        return;
      }

      await playSingleSentenceOnce(sentence, sessionId);

      if (!isActiveSession(sessionId)) {
        print("playSingleSentenceWithLoop: break after play");
        return;
      }

      // 循环间隔，如果启用了循环播放
      if (loop < loopCount - 1 && pauseInterval > Duration.zero) {
        await Future.delayed(pauseInterval);
      }
    }
  }

  /// 基本控制方法
  Future<void> play() async {
    await audioPlayer.play();
  }

  Future<void> pause() async {
    state.incrementPlaybackSessionId();
    await audioPlayer.pause();
  }

  Future<void> stop() async {
    state.incrementPlaybackSessionId();
    await audioPlayer.stop();
  }

  Future<void> seek(Duration position) async {
    await audioPlayer.seek(position);
  }

  /// 清除 clip 限制
  Future<void> clearClip() async {
    if (state.clipStart != Duration.zero) {
      state.setClipStart(Duration.zero);
      await audioPlayer.setClip(start: null, end: null);
    }
  }

  /// 设置 clip
  Future<void> setClip(Duration start, Duration end) async {
    state.setClipStart(start);
    await audioPlayer.setClip(start: start, end: end);
  }
}
