import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart' as ja;

import 'package:fluency/database/enums.dart';
import 'package:fluency/models/audio_engine_state.dart';
import 'package:fluency/models/learning_progress.dart';
import 'package:fluency/models/sentence.dart';
import 'package:fluency/providers/audio_engine/audio_engine_provider.dart';
import 'package:fluency/providers/learning_progress_provider.dart';
import 'package:fluency/providers/learning_session/learning_session_provider.dart';
import 'package:fluency/providers/learning_session/retell_player_provider.dart';

import '../../helpers/mock_providers.dart';

/// 可控测试引擎：用于验证 stopPlayback 与下一次 playRangeOnce 的时序。
class SequencedTestAudioEngine extends AudioEngine {
  final Completer<void> _stopCompleter = Completer<void>();
  int _sessionId = 0;

  int stopPlaybackCallCount = 0;
  int playRangeOnceCallCount = 0;
  bool playCalledBeforeStopCompleted = false;

  @override
  AudioEngineState build() => const AudioEngineState();

  @override
  Stream<Duration> get absolutePositionStream => const Stream.empty();

  @override
  Stream<ja.PlayerState> get playerStateStream => const Stream.empty();

  @override
  bool get isPlaying => false;

  @override
  Duration get currentPosition => Duration.zero;

  @override
  int newSession() {
    _sessionId += 1;
    return _sessionId;
  }

  @override
  bool isActiveSession(int id) => id == _sessionId;

  @override
  Future<void> stopPlayback() async {
    stopPlaybackCallCount += 1;
    await _stopCompleter.future;
  }

  @override
  Future<void> playRangeOnce(
    Duration start,
    Duration end,
    int sessionId,
  ) async {
    playRangeOnceCallCount += 1;
    if (!_stopCompleter.isCompleted) {
      playCalledBeforeStopCompleted = true;
    }

    // 只用于时序测试：触发调用后立刻使当前 session 失效，
    // 避免 RetellPlayer 进入后续倒计时逻辑，保持测试稳定。
    _sessionId += 1;
  }

  void completeStopPlayback() {
    if (!_stopCompleter.isCompleted) {
      _stopCompleter.complete();
    }
  }
}

class _RecordingLearningProgressNotifier extends TestLearningProgressNotifier {
  _RecordingLearningProgressNotifier(super.initialState);

  final List<int?> savedIndices = [];

  @override
  Future<void> saveRetellParagraphIndex(
    String audioItemId,
    int? paragraphIndex,
  ) async {
    savedIndices.add(paragraphIndex);
    final progress =
        state.progressMap[audioItemId] ??
        LearningProgress(
          audioItemId: audioItemId,
          currentStage: LearningStage.firstLearn,
          currentSubStage: SubStageType.retell,
          updatedAt: DateTime(2026, 3, 11),
        );
    final newMap = Map<String, LearningProgress>.from(state.progressMap);
    newMap[audioItemId] = progress.copyWith(
      retellParagraphIndex: paragraphIndex,
      clearRetellParagraphIndex: paragraphIndex == null,
      updatedAt: DateTime(2026, 3, 11, 12),
    );
    state = state.copyWith(progressMap: newMap);
  }
}

class _InMemoryLearningProgressNotifier extends TestLearningProgressNotifier {
  _InMemoryLearningProgressNotifier([super.initialState]);

  @override
  Future<void> saveRetellParagraphIndex(
    String audioItemId,
    int? paragraphIndex,
  ) async {
    final progress = await ensureProgress(audioItemId);
    final newMap = Map<String, LearningProgress>.from(state.progressMap);
    newMap[audioItemId] = progress.copyWith(
      retellParagraphIndex: paragraphIndex,
      clearRetellParagraphIndex: paragraphIndex == null,
      updatedAt: DateTime(2026, 3, 11, 12),
    );
    state = state.copyWith(progressMap: newMap);
  }
}

class _PassiveLearningSession extends TestLearningSession {
  _PassiveLearningSession([super.initialState]);

  @override
  void addInputWords(int count) {}

  @override
  void addOutputWords(int count) {}
}

/// 用于复现“倒计时中切段”问题：
/// - 段落播放立即完成，进入复述倒计时
/// - stopPlayback 延迟完成，给已取消倒计时的过期回调制造竞态窗口
class CountdownNavigationTestAudioEngine extends AudioEngine {
  final Completer<void> _stopCompleter = Completer<void>();
  int _sessionId = 0;

  @override
  AudioEngineState build() => const AudioEngineState();

  @override
  Stream<Duration> get absolutePositionStream => const Stream.empty();

  @override
  Stream<ja.PlayerState> get playerStateStream => const Stream.empty();

  @override
  bool get isPlaying => false;

  @override
  Duration get currentPosition => Duration.zero;

  @override
  int newSession() {
    _sessionId += 1;
    return _sessionId;
  }

  @override
  bool isActiveSession(int id) => id == _sessionId;

  @override
  Future<void> playRangeOnce(
    Duration start,
    Duration end,
    int sessionId,
  ) async {}

  @override
  Future<void> stopPlayback() async {
    await _stopCompleter.future;
  }

  void completeStopPlayback() {
    if (!_stopCompleter.isCompleted) {
      _stopCompleter.complete();
    }
  }
}

void main() {
  group('RetellPlayer', () {
    late ProviderContainer container;
    late SequencedTestAudioEngine engine;
    late RetellPlayer notifier;

    setUp(() {
      engine = SequencedTestAudioEngine();
      container = ProviderContainer(
        overrides: [
          audioEngineProvider.overrideWith(() => engine),
          learningSessionProvider.overrideWith(TestLearningSession.new),
        ],
      );
      notifier = container.read(retellPlayerProvider.notifier);
    });

    tearDown(() => container.dispose());

    test('goToNextParagraph 等待 stopPlayback 完成后才开始下一段播放', () async {
      final sentences = [
        Sentence(
          index: 0,
          text: 'Paragraph one',
          startTime: Duration.zero,
          endTime: const Duration(seconds: 3),
        ),
        Sentence(
          index: 1,
          text: 'Paragraph two',
          startTime: const Duration(seconds: 3),
          endTime: const Duration(seconds: 6),
        ),
      ];

      notifier.initialize([
        [sentences[0]],
        [sentences[1]],
      ], const {});

      final pending = notifier.goToNextParagraph();
      await Future<void>.delayed(Duration.zero);

      expect(engine.stopPlaybackCallCount, 1);
      expect(engine.playRangeOnceCallCount, 0);

      engine.completeStopPlayback();
      await pending;

      expect(engine.playRangeOnceCallCount, 1);
      expect(engine.playCalledBeforeStopCompleted, false);
      expect(container.read(retellPlayerProvider).currentParagraphIndex, 1);
    });

    test('startPlaying 会异步保存当前段首句索引', () async {
      final progressNotifier = _RecordingLearningProgressNotifier(
        LearningProgressState(
          progressMap: {
            'audio-1': LearningProgress(
              audioItemId: 'audio-1',
              currentStage: LearningStage.firstLearn,
              currentSubStage: SubStageType.retell,
              updatedAt: DateTime(2026, 3, 11),
            ),
          },
        ),
      );
      final saveContainer = ProviderContainer(
        overrides: [
          audioEngineProvider.overrideWith(() => SequencedTestAudioEngine()),
          learningSessionProvider.overrideWith(
            () => TestLearningSession(
              const LearningSessionState(
                learningMode: LearningMode.retell,
                audioItemId: 'audio-1',
              ),
            ),
          ),
          learningProgressNotifierProvider.overrideWith(
            () => progressNotifier,
          ),
        ],
      );
      addTearDown(saveContainer.dispose);

      final saveNotifier = saveContainer.read(retellPlayerProvider.notifier);
      saveNotifier.initialize([
        [
          Sentence(
            index: 3,
            text: 'Paragraph one',
            startTime: Duration.zero,
            endTime: const Duration(seconds: 3),
          ),
        ],
      ], const {});

      await saveNotifier.startPlaying();
      await Future<void>.delayed(const Duration(milliseconds: 1));

      expect(progressNotifier.savedIndices, contains(3));
      expect(progressNotifier.savedIndices.first, 3);
    });

    test('复述倒计时中点击上一段会正确进入上一段，不会停留在当前段', () async {
      final countdownEngine = CountdownNavigationTestAudioEngine();
      final countdownContainer = ProviderContainer(
        overrides: [
          audioEngineProvider.overrideWith(() => countdownEngine),
          learningSessionProvider.overrideWith(
            () => _PassiveLearningSession(
              const LearningSessionState(
                learningMode: LearningMode.retell,
                audioItemId: 'audio-1',
              ),
            ),
          ),
          learningProgressNotifierProvider.overrideWith(
            _InMemoryLearningProgressNotifier.new,
          ),
        ],
      );
      addTearDown(countdownContainer.dispose);

      final countdownNotifier = countdownContainer.read(
        retellPlayerProvider.notifier,
      );
      countdownNotifier.initialize([
        [
          Sentence(
            index: 0,
            text: 'Paragraph one',
            startTime: Duration.zero,
            endTime: const Duration(seconds: 3),
          ),
        ],
        [
          Sentence(
            index: 1,
            text: 'Paragraph two',
            startTime: const Duration(seconds: 3),
            endTime: const Duration(seconds: 6),
          ),
        ],
        [
          Sentence(
            index: 2,
            text: 'Paragraph three',
            startTime: const Duration(seconds: 6),
            endTime: const Duration(seconds: 9),
          ),
        ],
      ], const {}, startSentenceIndex: 1);
      await countdownNotifier.startPlaying();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(countdownContainer.read(retellPlayerProvider).isRetellCountdown, true);
      expect(
        countdownContainer.read(retellPlayerProvider).currentParagraphIndex,
        1,
      );

      final pending = countdownNotifier.goToPreviousParagraph();
      await Future<void>.delayed(Duration.zero);
      countdownEngine.completeStopPlayback();
      await pending;

      expect(
        countdownContainer.read(retellPlayerProvider).currentParagraphIndex,
        0,
      );
    });

    test('复述倒计时中点击下一段只推进一段，不会跳过一段', () async {
      final countdownEngine = CountdownNavigationTestAudioEngine();
      final countdownContainer = ProviderContainer(
        overrides: [
          audioEngineProvider.overrideWith(() => countdownEngine),
          learningSessionProvider.overrideWith(
            () => _PassiveLearningSession(
              const LearningSessionState(
                learningMode: LearningMode.retell,
                audioItemId: 'audio-1',
              ),
            ),
          ),
          learningProgressNotifierProvider.overrideWith(
            _InMemoryLearningProgressNotifier.new,
          ),
        ],
      );
      addTearDown(countdownContainer.dispose);

      final countdownNotifier = countdownContainer.read(
        retellPlayerProvider.notifier,
      );
      countdownNotifier.initialize([
        [
          Sentence(
            index: 0,
            text: 'Paragraph one',
            startTime: Duration.zero,
            endTime: const Duration(seconds: 3),
          ),
        ],
        [
          Sentence(
            index: 1,
            text: 'Paragraph two',
            startTime: const Duration(seconds: 3),
            endTime: const Duration(seconds: 6),
          ),
        ],
        [
          Sentence(
            index: 2,
            text: 'Paragraph three',
            startTime: const Duration(seconds: 6),
            endTime: const Duration(seconds: 9),
          ),
        ],
      ], const {});

      await countdownNotifier.startPlaying();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(countdownContainer.read(retellPlayerProvider).isRetellCountdown, true);
      expect(
        countdownContainer.read(retellPlayerProvider).currentParagraphIndex,
        0,
      );

      final pending = countdownNotifier.goToNextParagraph();
      await Future<void>.delayed(Duration.zero);
      countdownEngine.completeStopPlayback();
      await pending;

      expect(
        countdownContainer.read(retellPlayerProvider).currentParagraphIndex,
        1,
      );
    });
  });
}
