import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart' as ja;

import 'package:echo_loop/database/enums.dart';
import 'package:echo_loop/models/audio_engine_state.dart';
import 'package:echo_loop/models/intensive_listen_settings.dart'
    show ShadowingControlMode;
import 'package:echo_loop/models/learning_progress.dart';
import 'package:echo_loop/models/retell_settings.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/providers/audio_engine/audio_engine_provider.dart';
import 'package:echo_loop/providers/learning_progress_provider.dart';
import 'package:echo_loop/providers/learning_session/learning_session_provider.dart';
import 'package:echo_loop/providers/learning_session/retell_player_provider.dart';

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
  Future<void> saveRetellSentenceIndex(
    String audioItemId,
    int? paragraphIndex, {
    required bool isFreePlay,
  }) async {
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
      retellSentenceIndex: paragraphIndex,
      clearRetellSentenceIndex: paragraphIndex == null,
      updatedAt: DateTime(2026, 3, 11, 12),
    );
    state = state.copyWith(progressMap: newMap);
  }
}

class _InMemoryLearningProgressNotifier extends TestLearningProgressNotifier {
  _InMemoryLearningProgressNotifier([super.initialState]);

  @override
  Future<void> saveRetellSentenceIndex(
    String audioItemId,
    int? paragraphIndex, {
    required bool isFreePlay,
  }) async {
    final progress = await ensureProgress(audioItemId);
    final newMap = Map<String, LearningProgress>.from(state.progressMap);
    newMap[audioItemId] = progress.copyWith(
      retellSentenceIndex: paragraphIndex,
      clearRetellSentenceIndex: paragraphIndex == null,
      updatedAt: DateTime(2026, 3, 11, 12),
    );
    state = state.copyWith(progressMap: newMap);
  }
}

class _PassiveLearningSession extends TestLearningSession {
  _PassiveLearningSession([super.initialState]);

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

class DelayedRetellTestAudioEngine extends AudioEngine {
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
  ) async {
    if (!isActiveSession(sessionId)) return;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  @override
  Future<void> stopPlayback() async {}
}

void main() {
  group('RetellPlayerState', () {
    test('stepFinished — 默认为 false，copyWith 可设置和保留', () {
      const state = RetellPlayerState();
      expect(state.stepFinished, false);

      final finished = state.copyWith(stepFinished: true);
      expect(finished.stepFinished, true);

      // 不传值时保留
      final updated = finished.copyWith(isPlaying: true);
      expect(updated.stepFinished, true);

      // 重置
      final reset = finished.copyWith(stepFinished: false);
      expect(reset.stepFinished, false);
    });
  });

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
          analyticsOverride(),
          ...studyTimeOverrides(),
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
      ]);

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

    test('等待态挂起时，当前段播完后进入 waiting for user', () async {
      final delayedContainer = ProviderContainer(
        overrides: [
          audioEngineProvider.overrideWith(() => DelayedRetellTestAudioEngine()),
          learningSessionProvider.overrideWith(TestLearningSession.new),
          analyticsOverride(),
          ...studyTimeOverrides(),
        ],
      );
      addTearDown(delayedContainer.dispose);

      final delayedNotifier = delayedContainer.read(retellPlayerProvider.notifier);
      delayedNotifier.initialize([
        [
          Sentence(
            index: 0,
            text: 'Paragraph one',
            startTime: Duration.zero,
            endTime: const Duration(seconds: 3),
          ),
        ],
      ]);

      final pending = delayedNotifier.startPlaying();
      delayedNotifier.enterWaitingForUser(afterCurrentParagraph: true);
      delayedNotifier.updateSettings(
        const RetellSettings(controlMode: ShadowingControlMode.manual),
      );
      await pending;

      final state = delayedContainer.read(retellPlayerProvider);
      expect(state.phase, RetellPhase.retelling);
      expect(state.isWaitingForUser, true);
      expect(state.isPlaying, false);
      expect(state.isRetellCountdown, false);
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
          learningProgressNotifierProvider.overrideWith(() => progressNotifier),
          analyticsOverride(),
          ...studyTimeOverrides(),
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
      ]);

      await saveNotifier.startPlaying();
      await Future<void>.delayed(const Duration(milliseconds: 1));

      expect(progressNotifier.savedIndices, contains(3));
      expect(progressNotifier.savedIndices.first, 3);
    });

    test('freePlay 模式也会异步保存当前段首句索引', () async {
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
                isFreePlay: true,
              ),
            ),
          ),
          learningProgressNotifierProvider.overrideWith(() => progressNotifier),
          analyticsOverride(),
          ...studyTimeOverrides(),
        ],
      );
      addTearDown(saveContainer.dispose);

      final saveNotifier = saveContainer.read(retellPlayerProvider.notifier);
      saveNotifier.initialize([
        [
          Sentence(
            index: 5,
            text: 'Paragraph one',
            startTime: Duration.zero,
            endTime: const Duration(seconds: 3),
          ),
        ],
      ]);

      await saveNotifier.startPlaying();
      await Future<void>.delayed(const Duration(milliseconds: 1));

      expect(progressNotifier.savedIndices, contains(5));
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
          analyticsOverride(),
          ...studyTimeOverrides(),
        ],
      );
      addTearDown(countdownContainer.dispose);

      final countdownNotifier = countdownContainer.read(
        retellPlayerProvider.notifier,
      );
      countdownNotifier.initialize(
        [
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
        ],
        startSentenceIndex: 1,
      );
      await countdownNotifier.startPlaying();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // 模拟评估完成后 screen 层触发段间停顿
      countdownNotifier.startPostEvaluationPause();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(
        countdownContainer.read(retellPlayerProvider).isRetellCountdown,
        true,
      );
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

    test('用户在 listening phase 手动切换 displayMode 后，进入 retelling phase 时保持不变',
        () async {
      final countdownEngine = CountdownNavigationTestAudioEngine();
      final testContainer = ProviderContainer(
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
          analyticsOverride(),
          ...studyTimeOverrides(),
        ],
      );
      addTearDown(testContainer.dispose);

      final testNotifier = testContainer.read(
        retellPlayerProvider.notifier,
      );
      testNotifier.initialize([
        [
          Sentence(
            index: 0,
            text: 'Paragraph one',
            startTime: Duration.zero,
            endTime: const Duration(seconds: 3),
          ),
        ],
      ]);

      // 开始播放（playRangeOnce 立即完成 → 自动进入 retelling phase）
      await testNotifier.startPlaying();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // 验证默认进入 retelling 时 displayMode 为 keywordsOnly
      expect(
        testContainer.read(retellPlayerProvider).phase,
        RetellPhase.retelling,
      );
      expect(
        testContainer.read(retellPlayerProvider).displayMode,
        RetellDisplayMode.keywordsOnly,
      );

      // 重播回到 listening phase
      countdownEngine.completeStopPlayback();
      await testNotifier.replayDuringCountdown();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // 在播放完成前（或播放完成后）用户手动切换到 showAll
      testNotifier.setDisplayMode(RetellDisplayMode.showAll);
      expect(
        testContainer.read(retellPlayerProvider).displayMode,
        RetellDisplayMode.showAll,
      );
      expect(
        testContainer.read(retellPlayerProvider).userOverrodeDisplayMode,
        true,
      );

      // playRangeOnce 已完成，此时已进入 retelling phase
      // 验证 displayMode 仍为 showAll（未被重置为 keywordsOnly）
      expect(
        testContainer.read(retellPlayerProvider).phase,
        RetellPhase.retelling,
      );
      expect(
        testContainer.read(retellPlayerProvider).displayMode,
        RetellDisplayMode.showAll,
      );
    });

    test('未手动切换 displayMode 时，进入 retelling phase 正常重置为 keywordsOnly',
        () async {
      final countdownEngine = CountdownNavigationTestAudioEngine();
      final testContainer = ProviderContainer(
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
          analyticsOverride(),
          ...studyTimeOverrides(),
        ],
      );
      addTearDown(testContainer.dispose);

      final testNotifier = testContainer.read(
        retellPlayerProvider.notifier,
      );
      testNotifier.initialize([
        [
          Sentence(
            index: 0,
            text: 'Paragraph one',
            startTime: Duration.zero,
            endTime: const Duration(seconds: 3),
          ),
        ],
      ]);

      // 开始播放 → 自动进入 retelling phase
      await testNotifier.startPlaying();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // 验证未手动操作时，displayMode 被重置为 keywordsOnly
      expect(
        testContainer.read(retellPlayerProvider).phase,
        RetellPhase.retelling,
      );
      expect(
        testContainer.read(retellPlayerProvider).displayMode,
        RetellDisplayMode.keywordsOnly,
      );
      expect(
        testContainer.read(retellPlayerProvider).userOverrodeDisplayMode,
        false,
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
          analyticsOverride(),
          ...studyTimeOverrides(),
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
      ]);

      await countdownNotifier.startPlaying();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // 模拟评估完成后 screen 层触发段间停顿
      countdownNotifier.startPostEvaluationPause();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(
        countdownContainer.read(retellPlayerProvider).isRetellCountdown,
        true,
      );
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
