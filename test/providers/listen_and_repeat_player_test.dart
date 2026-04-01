import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fluency/database/enums.dart';
import 'package:fluency/models/audio_engine_state.dart';
import 'package:fluency/models/intensive_listen_settings.dart';
import 'package:fluency/models/learning_progress.dart';
import 'package:fluency/models/sentence.dart';
import 'package:fluency/providers/audio_engine/audio_engine_provider.dart';
import 'package:fluency/providers/learning_progress_provider.dart';
import 'package:fluency/providers/learning_session/learning_session_provider.dart';
import 'package:fluency/providers/learning_session/listen_and_repeat_player_provider.dart';
import 'package:fluency/providers/learning_session/playback_phase.dart';

import '../helpers/mock_providers.dart';

class _ReplayTestAudioEngine extends TestAudioEngine {
  int _sessionId = 0;

  _ReplayTestAudioEngine()
    : super(initialState: const AudioEngineState(sessionId: 0));

  @override
  int newSession() {
    _sessionId += 1;
    return _sessionId;
  }

  @override
  bool isActiveSession(int id) => id == _sessionId;

  @override
  Future<void> playClipOnce(Sentence sentence, int sessionId) async {
    if (!isActiveSession(sessionId)) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    _sessionId += 1;
  }
}

class _RecordingLearningProgressNotifier extends TestLearningProgressNotifier {
  _RecordingLearningProgressNotifier(super.initialState);

  final List<int?> savedIndices = [];

  @override
  Future<void> saveShadowingSentenceIndex(
    String audioItemId,
    int? sentenceIndex, {
    required bool isFreePlay,
  }) async {
    savedIndices.add(sentenceIndex);
    final progress =
        state.progressMap[audioItemId] ??
        LearningProgress(
          audioItemId: audioItemId,
          currentStage: LearningStage.firstLearn,
          currentSubStage: SubStageType.listenAndRepeat,
          updatedAt: DateTime(2026, 3, 11),
        );
    final newMap = Map<String, LearningProgress>.from(state.progressMap);
    newMap[audioItemId] = progress.copyWith(
      shadowingSentenceIndex: sentenceIndex,
      clearShadowingSentenceIndex: sentenceIndex == null,
      updatedAt: DateTime(2026, 3, 11, 12),
    );
    state = state.copyWith(progressMap: newMap);
  }
}

class _PassiveLearningSession extends TestLearningSession {
  _PassiveLearningSession(super.initialState);

  @override
  void addOutputWords(int count) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ListenAndRepeatPlayerState', () {
    test('stepFinished — 默认为 false，copyWith 可设置和保留', () {
      const state = ListenAndRepeatPlayerState();
      expect(state.stepFinished, false);

      final finished = state.copyWith(
        phase: const IdlePhase(stepFinished: true),
      );
      expect(finished.stepFinished, true);

      // 不传值时保留（切换到播放阶段后 stepFinished getter 返回 false）
      final updated = finished.copyWith(
        phase: const PlayingPhase(playCount: 1),
      );
      expect(updated.isPlaying, true);

      // 重置回 idle
      final reset = finished.copyWith(
        phase: const IdlePhase(stepFinished: false),
      );
      expect(reset.stepFinished, false);
    });
  });

  group('ListenAndRepeatPlayer 开始播放时保存断点', () {
    test('startPlaying 会异步保存当前句索引', () async {
      final progressNotifier = _RecordingLearningProgressNotifier(
        LearningProgressState(
          progressMap: {
            'audio-1': LearningProgress(
              audioItemId: 'audio-1',
              currentStage: LearningStage.firstLearn,
              currentSubStage: SubStageType.listenAndRepeat,
              updatedAt: DateTime(2026, 3, 11),
            ),
          },
        ),
      );
      final container = ProviderContainer(
        overrides: [
          audioEngineProvider.overrideWith(() => _ReplayTestAudioEngine()),
          learningProgressNotifierProvider.overrideWith(() => progressNotifier),
          learningSessionProvider.overrideWith(
            () => _PassiveLearningSession(
              const LearningSessionState(
                learningMode: LearningMode.listenAndRepeat,
                audioItemId: 'audio-1',
              ),
            ),
          ),
          analyticsOverride(),
          ...studyTimeOverrides(),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(listenAndRepeatPlayerProvider.notifier);
      await notifier.initialize([
        Sentence(
          index: 0,
          text: 'First sentence',
          startTime: Duration.zero,
          endTime: const Duration(seconds: 1),
        ),
        Sentence(
          index: 1,
          text: 'Second sentence',
          startTime: const Duration(seconds: 2),
          endTime: const Duration(seconds: 3),
        ),
      ], startIndex: 1);

      await notifier.startPlaying();
      await Future<void>.delayed(const Duration(milliseconds: 1));

      expect(progressNotifier.savedIndices, contains(1));
      expect(progressNotifier.savedIndices.first, 1);
    });

    test('freePlay 模式也会异步保存当前句索引', () async {
      final progressNotifier = _RecordingLearningProgressNotifier(
        LearningProgressState(
          progressMap: {
            'audio-1': LearningProgress(
              audioItemId: 'audio-1',
              currentStage: LearningStage.firstLearn,
              currentSubStage: SubStageType.listenAndRepeat,
              updatedAt: DateTime(2026, 3, 11),
            ),
          },
        ),
      );
      final container = ProviderContainer(
        overrides: [
          audioEngineProvider.overrideWith(() => _ReplayTestAudioEngine()),
          learningProgressNotifierProvider.overrideWith(() => progressNotifier),
          learningSessionProvider.overrideWith(
            () => _PassiveLearningSession(
              const LearningSessionState(
                learningMode: LearningMode.listenAndRepeat,
                audioItemId: 'audio-1',
                isFreePlay: true,
              ),
            ),
          ),
          analyticsOverride(),
          ...studyTimeOverrides(),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(listenAndRepeatPlayerProvider.notifier);
      await notifier.initialize(createTestSentences(count: 3), startIndex: 2);
      await notifier.startPlaying();
      await Future<void>.delayed(const Duration(milliseconds: 1));

      expect(progressNotifier.savedIndices, contains(2));
    });
  });

  group('ListenAndRepeatPlayer completePausedTurn', () {
    test('遍间停顿时继续到下一遍', () async {
      final container = ProviderContainer(
        overrides: [
          listenAndRepeatPlayerProvider.overrideWith(
            () => TestListenAndRepeatPlayer(
              const ListenAndRepeatPlayerState(
                currentSentenceIndex: 0,
                totalSentences: 2,
                currentPlayCount: 1,
                settings: IntensiveListenSettings(repeatCount: 3),
                phase: RepeatPausePhase(completedPlayCount: 1),
              ),
              createTestSentences(count: 2),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(listenAndRepeatPlayerProvider.notifier);
      await notifier.completePausedTurn();

      final state = container.read(listenAndRepeatPlayerProvider);
      expect(state.currentPlayCount, 2);
      expect(state.currentSentenceIndex, 0);
      expect(state.isPauseBetweenPlays, isFalse);
    });

    test('句间停顿时推进到下一句', () async {
      final container = ProviderContainer(
        overrides: [
          listenAndRepeatPlayerProvider.overrideWith(
            () => TestListenAndRepeatPlayer(
              const ListenAndRepeatPlayerState(
                currentSentenceIndex: 0,
                totalSentences: 2,
                currentPlayCount: 3,
                settings: IntensiveListenSettings(repeatCount: 3),
                phase: AdvancePausePhase(),
              ),
              createTestSentences(count: 2),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(listenAndRepeatPlayerProvider.notifier);
      await notifier.completePausedTurn();

      final state = container.read(listenAndRepeatPlayerProvider);
      expect(state.currentSentenceIndex, 1);
      expect(state.currentPlayCount, 1);
    });
  });
}
