import 'dart:async';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../models/audio_engine_state.dart';
import '../../models/audio_item.dart';
import '../../models/sentence.dart';
import '../../services/subtitle_parser.dart';

part 'audio_engine_provider.g.dart';

@Riverpod(keepAlive: true)
class AudioEngine extends _$AudioEngine {
  late final ja.AudioPlayer _audioPlayer;

  @override
  AudioEngineState build() {
    _audioPlayer = ja.AudioPlayer();
    ref.onDispose(() => _audioPlayer.dispose());
    return const AudioEngineState();
  }

  ja.AudioPlayer get audioPlayer => _audioPlayer;

  // --- Streams ---
  Stream<Duration> get absolutePositionStream =>
      _audioPlayer.positionStream.map((rel) => state.clipStart + rel);

  Stream<ja.PlayerState> get playerStateStream =>
      _audioPlayer.playerStateStream;

  bool get isPlaying => _audioPlayer.playing;
  Duration get currentPosition => _audioPlayer.position;

  // --- 音频加载 ---
  Future<Duration?> loadAudio(AudioItem item, double speed) async {
    try {
      state = state.copyWith(isLoading: true, errorMessage: null);

      final fullAudioPath = await item.getFullAudioPath();
      await _audioPlayer.setFilePath(fullAudioPath);
      await _audioPlayer.setSpeed(speed);

      Duration? duration = _audioPlayer.duration;
      if (duration == null) {
        await _audioPlayer.durationStream.first;
        duration = _audioPlayer.duration;
      }

      state = state.copyWith(
        totalDuration: duration,
        clipStart: Duration.zero,
        currentAudioId: item.id,
        isLoading: false,
      );

      return duration;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      rethrow;
    }
  }

  // --- 字幕加载 ---
  Future<List<Sentence>> loadTranscript(AudioItem audioItem) async {
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

  // --- 基础控制 ---
  Future<void> play() async => await _audioPlayer.play();

  Future<void> pause() async {
    state = state.copyWith(sessionId: state.sessionId + 1);
    await _audioPlayer.pause();
  }

  Future<void> stop() async {
    state = state.copyWith(sessionId: state.sessionId + 1);
    await _audioPlayer.stop();
  }

  Future<void> seek(Duration pos) async => await _audioPlayer.seek(pos);

  Future<void> setSpeed(double speed) async =>
      await _audioPlayer.setSpeed(speed);

  // --- Clip 管理 ---
  Future<void> setClip(Duration start, Duration end) async {
    state = state.copyWith(clipStart: start);
    await _audioPlayer.setClip(start: start, end: end);
  }

  Future<void> clearClip() async {
    if (state.clipStart != Duration.zero) {
      state = state.copyWith(clipStart: Duration.zero);
      await _audioPlayer.setClip(start: null, end: null);
    }
  }

  // --- 句子级播放基元（所有业务模式共享） ---
  Future<void> playClipOnce(Sentence sentence, int sessionId) async {
    if (!isActiveSession(sessionId)) return;

    state = state.copyWith(clipStart: sentence.startTime);
    await _audioPlayer.setClip(
      start: sentence.startTime,
      end: sentence.endTime,
    );

    await _audioPlayer.play();

    await _audioPlayer.playerStateStream.firstWhere(
      (s) =>
          !isActiveSession(sessionId) ||
          s.processingState == ja.ProcessingState.completed ||
          (!s.playing && s.processingState == ja.ProcessingState.ready),
    );
  }

  Future<void> playClipWithLoops(
    Sentence sentence,
    int sessionId, {
    required int loopCount,
    required Duration interval,
  }) async {
    for (int loop = 0; loop < loopCount; loop++) {
      if (!isActiveSession(sessionId)) return;

      await playClipOnce(sentence, sessionId);

      if (!isActiveSession(sessionId)) return;

      // 循环间隔
      if (loop < loopCount - 1 && interval > Duration.zero) {
        await Future.delayed(interval);
      }
    }
  }

  // --- Session 管理 ---
  int newSession() {
    state = state.copyWith(sessionId: state.sessionId + 1);
    return state.sessionId;
  }

  bool isActiveSession(int id) => id == state.sessionId;
}
