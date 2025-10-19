import 'dart:async';
import 'package:just_audio/just_audio.dart' as ja;
import '../../models/sentence.dart';
import 'player_state.dart';
import 'playback_controller.dart';

/// 播放模式处理器
/// 负责处理不同的播放模式：Continuous 和 Subtitle-Driven
class PlaybackModeHandler {
  final ja.AudioPlayer audioPlayer;
  final PlayerState state;
  final PlaybackController controller;

  PlaybackModeHandler({
    required this.audioPlayer,
    required this.state,
    required this.controller,
  });

  /// 决定使用哪种播放模式
  bool shouldUseContinuousMode() {
    // 书签模式：永远使用 Subtitle-Driven
    if (state.playlistMode == PlaylistMode.bookmarks) return false;

    // 全文模式：autoPlayNextSentence开启 且 sentenceRepeat关闭 => Continuous
    if (state.settings.autoPlayNextSentenceEnabled &&
        !state.settings.loopEnabled) {
      return true;
    }

    // 其他情况：Subtitle-Driven
    return false;
  }

  /// 模式1：全程连续播放
  Future<void> playContinuous() async {
    state.incrementPlaybackSessionId();

    // 确定要 seek 的目标位置
    final startIndex = state.currentFullIndex;

    Duration? targetPosition;
    if (startIndex != null && startIndex < state.sentences.length) {
      targetPosition = state.sentences[startIndex].startTime;
    }

    // 只在有 clip 的情况下才清除，避免不必要的重置
    await controller.clearClip();

    // seek 到目标位置
    if (targetPosition != null) {
      await audioPlayer.seek(targetPosition);
    }

    await audioPlayer.play();

    // 等待音频播放完成
    if (audioPlayer.playing) {
      await audioPlayer.playerStateStream.firstWhere(
        (playerState) =>
            !playerState.playing ||
            playerState.processingState == ja.ProcessingState.completed,
      );
    }

    print("playContinuous end");
    await controller.stop();
  }

  /// 模式2：Subtitle-Driven播放（异步for循环）
  Future<void> playSubtitleDriven(
    List<Sentence> playList,
    int startIndex,
  ) async {
    final sessionId = state.playbackSessionId;

    if (playList.isEmpty) return;

    // 音频循环计数
    int audioLoopCount = 0;

    while (true) {
      // 检查音频循环条件
      if (audioLoopCount > 0) {
        if (!state.settings.loopAudioEnabled) break;
        final shouldLoop =
            state.settings.loopAudio == 0 ||
            audioLoopCount < state.settings.loopAudio;
        if (!shouldLoop) break;
      }

      // 确定起始位置：第一轮使用传入的startIndex，后续循环从0开始
      final int loopStartIdx = audioLoopCount == 0 ? startIndex : 0;

      // 使用异步for循环逐句播放
      for (int i = loopStartIdx; i < playList.length; i++) {
        // 检查会话是否被取消
        if (!controller.isActiveSession(sessionId)) {
          return;
        }

        final sentence = playList[i];

        // 更新当前索引（使用句子的原始索引）
        if (state.playlistMode == PlaylistMode.bookmarks) {
          if (state.currentBookmarkIndex != sentence.index) {
            state.setCurrentBookmarkIndex(sentence.index);
          }
        } else {
          if (state.currentFullIndex != sentence.index) {
            state.setCurrentFullIndex(sentence.index);
          }
        }

        // 播放当前句子
        print("playSingleSentenceWithLoop begin, sessionId: $sessionId");
        await controller.playSingleSentenceWithLoop(
          sentence,
          sessionId,
          state.settings,
        );
        print("playSingleSentenceWithLoop end");

        // 句子之间间隔
        if (i < playList.length - 1) {
          if (state.playlistMode == PlaylistMode.bookmarks &&
              !state.settings.loopEnabled) {
            // 如果播放收藏列表时，并且没有开启循环播放，那么默认间隔为1s
            await Future.delayed(const Duration(seconds: 1));
          } else if (state.settings.autoPlayNextSentenceEnabled &&
              state.settings.loopEnabled &&
              state.settings.pauseInterval > Duration.zero) {
            // 如果开启循环播放，那么使用设置的间隔
            await Future.delayed(state.settings.pauseInterval);
          }
        }

        // 检查会话是否被取消
        if (!controller.isActiveSession(sessionId)) {
          return;
        }

        // 如果不是自动播放下一句，等待当前句子播放完成后退出
        if (!state.settings.autoPlayNextSentenceEnabled) {
          // 等待音频播放完成
          if (audioPlayer.playing) {
            await audioPlayer.playerStateStream.firstWhere(
              (playerState) =>
                  !playerState.playing ||
                  playerState.processingState == ja.ProcessingState.completed,
            );
          }
          return;
        }
      }

      // 一轮播放完成
      audioLoopCount++;

      // 如果没有开启音频循环，退出
      if (!state.settings.loopAudioEnabled) break;
    }

    // 播放完成, stop 播放
    await controller.stop();
  }

  /// 处理Continuous模式下的播放完成
  Future<void> handlePlaybackCompleted() async {
    // 只在Continuous模式下处理音频循环
    if (!shouldUseContinuousMode()) return;

    if (state.settings.loopAudioEnabled) {
      final shouldLoop = state.settings.loopAudio == 0 || true;
      if (shouldLoop && state.sentences.isNotEmpty) {
        // 重新从头播放
        Future.microtask(() async {
          if (state.playlistMode == PlaylistMode.bookmarks) {
            final bookmarked = state.bookmarkedSentences;
            if (bookmarked.isNotEmpty) {
              state.setCurrentBookmarkIndex(bookmarked.first.index);
            }
          } else {
            state.setCurrentFullIndex(0);
          }
          await playContinuous();
        });
      } else {
        // 不循环
        print("Playback completed without loop");
      }
    } else {
      // 不循环
      print("Playback completed");
    }
  }
}
