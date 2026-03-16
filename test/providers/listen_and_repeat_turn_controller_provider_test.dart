import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluency/models/speech_practice_models.dart';
import 'package:fluency/providers/listen_and_repeat_turn_controller_provider.dart';
import 'package:fluency/providers/learning_session/listen_and_repeat_player_provider.dart';
import 'package:fluency/providers/speech_practice_session_provider.dart';
import 'package:fluency/services/speech_practice_platform.dart';

import '../helpers/mock_providers.dart';

class _FakeSpeechPracticeBackend implements SpeechPracticeBackend {
  final _controller = StreamController<SpeechPracticeEvent>.broadcast();
  bool autoEmitFinal;
  String? activePromptId;
  int counter = 0;

  _FakeSpeechPracticeBackend({this.autoEmitFinal = true});

  @override
  bool get isSupported => true;

  @override
  Stream<SpeechPracticeEvent> get events => _controller.stream;

  @override
  Future<SpeechPracticePermissionState> getPermissionStatus() async {
    return const SpeechPracticePermissionState(
      microphone: SpeechPracticePermissionStatus.granted,
      speech: SpeechPracticePermissionStatus.granted,
    );
  }

  @override
  Future<SpeechPracticePermissionState> requestPermissions() {
    return getPermissionStatus();
  }

  @override
  Future<void> warmup({String locale = 'en-US'}) async {}

  @override
  Future<void> shutdown() async {}

  @override
  Future<String> startSession({
    required String promptId,
    String locale = 'en-US',
  }) async {
    activePromptId = promptId;
    counter += 1;
    return '/tmp/$promptId-$counter.caf';
  }

  @override
  Future<SpeechPracticeStopResult> stopSession() async {
    final promptId = activePromptId ?? 'shadowing:a1:0';
    if (autoEmitFinal) {
      scheduleMicrotask(() {
        _controller.add(
          SpeechPracticeEvent(
            type: SpeechPracticeEventType.finalTranscriptReady,
            promptId: promptId,
            transcript: 'done',
          ),
        );
      });
    }
    return SpeechPracticeStopResult(filePath: '/tmp/$promptId-$counter.caf');
  }

  @override
  Future<void> cancelSession() async {}

  @override
  Future<void> deleteRecording(String filePath) async {}

  void emitPartial(String transcript) {
    _controller.add(
      SpeechPracticeEvent(
        type: SpeechPracticeEventType.partialTranscriptUpdated,
        promptId: activePromptId ?? 'shadowing:a1:0',
        transcript: transcript,
      ),
    );
  }

  void emitSpeechStarted() {
    _controller.add(
      SpeechPracticeEvent(
        type: SpeechPracticeEventType.speechStarted,
        promptId: activePromptId ?? 'shadowing:a1:0',
      ),
    );
  }

  void emitSilence(Duration duration) {
    _controller.add(
      SpeechPracticeEvent(
        type: SpeechPracticeEventType.silenceProgress,
        promptId: activePromptId ?? 'shadowing:a1:0',
        silenceDuration: duration,
      ),
    );
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SpeechPracticeCompletionHeuristic', () {
    const heuristic = SpeechPracticeCompletionHeuristic();

    test('空输入 → 5s', () {
      expect(
        heuristic.computeSilenceThreshold(
          referenceText: 'Hello world',
          partialTranscript: '',
        ),
        const Duration(seconds: 5),
      );
      expect(
        heuristic.computeSilenceThreshold(
          referenceText: '',
          partialTranscript: 'Hello world',
        ),
        const Duration(seconds: 5),
      );
    });

    test('完全匹配（规则 A + B 同时 1s）→ 1s', () {
      final result = heuristic.computeSilenceThreshold(
        referenceText: 'Hello world',
        partialTranscript: 'hello world',
      );
      expect(result, const Duration(seconds: 1));
    });

    test('尾部连续完整匹配 + 唯一（规则 A）→ 1s', () {
      // "I noticed your name on the door" 匹配 7/8，尾部 5 词连续且唯一
      final result = heuristic.computeSilenceThreshold(
        referenceText: 'Anyhow I noticed your name on the door',
        partialTranscript: 'I noticed your name on the door',
      );
      expect(result, const Duration(seconds: 1));
    });

    test('全句 95% 但尾部只命中 3/5（规则 B=2s, C=3s）→ 2s', () {
      // 20 词句子，匹配 19/20 = 95%，尾部 5 词命中 3
      // 构造：20 词句子，漏掉倒数第 2 和第 4 词
      // "a b c d e f g h i j k l m n o p q r s t"
      // 匹配全部 20 词中的 19 个 = 95%
      // 尾部 5 词 (p q r s t) 命中 3 个
      final result = heuristic.computeSilenceThreshold(
        referenceText:
            'the quick brown fox jumps over the lazy dog and '
            'then runs across the wide open green field today',
        // 漏掉 "open" 和 "today" → 18/20 = 90%
        // 尾部 5 词: wide open green field today → 命中 3 (wide green field)
        partialTranscript:
            'the quick brown fox jumps over the lazy dog and '
            'then runs across the wide green field',
      );
      // 规则 B: 18/20=90% → 3s, 规则 C: 3/5 → 3s → min = 3s
      expect(result, const Duration(seconds: 3));
    });

    test('全句 90% 尾部命中 4/5（规则 B=3s, C=2s）→ 2s', () {
      // 10 词句子，匹配 9/10 = 90%，尾部 5 词命中 4
      final result = heuristic.computeSilenceThreshold(
        referenceText: 'she always wanted to visit the beautiful city of paris',
        // 漏掉 "always" → 9/10 = 90%
        // 尾部 5 词: the beautiful city of paris → 全部命中 5 个
        partialTranscript: 'she wanted to visit the beautiful city of paris',
      );
      // 规则 B: 90% → 3s, 规则 C: 5/5 → 1s
      // 规则 A: 连续尾部 = 8（从末尾 paris→of→city→beautiful→the→visit→to→wanted）
      //   ≥ tailSize(5)，尾 8 词 "wanted to visit the beautiful city of paris"
      //   唯一 → 1s
      // min(1s, 3s, 1s) = 1s
      expect(result, const Duration(seconds: 1));
    });

    test('末尾词唯一但命中少，规则 A 仍生效 → 1s', () {
      // "paris" 唯一，consecutiveTail=1 → 规则 A 给 1s
      final result = heuristic.computeSilenceThreshold(
        referenceText: 'she always wanted to visit the beautiful city of paris',
        partialTranscript: 'she wanted the paris',
      );
      expect(result, const Duration(seconds: 1));
    });

    test('只说了唯一的末尾词（规则 A：consecutiveTail=1 且唯一）→ 1s', () {
      // "syllabus" 在 reference 中唯一，连续尾部匹配 1 → 规则 A 生效
      final result = heuristic.computeSilenceThreshold(
        referenceText:
            "Thought I'd stop in and um find out if you happen "
            'to have any additional copies of the class syllabus',
        partialTranscript: 'syllabus',
      );
      expect(result, const Duration(seconds: 1));
    });

    test('末尾无命中 → 5s', () {
      final result = heuristic.computeSilenceThreshold(
        referenceText: 'Anyhow I noticed your name on the door',
        partialTranscript: 'Anyhow I noticed your',
      );
      // 尾部 5 词 "name on the door"（只有 5 个）→ 命中 0 个
      // 规则 C → 5s
      expect(result, const Duration(seconds: 5));
    });

    test('短句（< 5 词）正常工作', () {
      // "Hello world" = 2 词，tailSize = 2
      final result = heuristic.computeSilenceThreshold(
        referenceText: 'Hello world',
        partialTranscript: 'hello',
      );
      // LCS = 1/2 = 50%（规则 B 不适用）
      // 尾部 2 词 (hello world): 命中 1（hello，但 hello 不在 tail 连续匹配中）
      // 实际上 matchedRefIndexes = {0}，tail 是 index 0,1 → 命中 1 个
      // 规则 C: 1/2 → 5s
      expect(result, const Duration(seconds: 5));
    });

    test('尾部连续匹配且组合唯一 → 规则 A 生效 → 1s', () {
      // "and she said hello" 连续尾部 4 词，组合在 reference 中唯一
      final result = heuristic.computeSilenceThreshold(
        referenceText: 'I said hello and she said hello',
        partialTranscript: 'and she said hello',
      );
      expect(result, const Duration(seconds: 1));
    });

    test('尾部非唯一时规则 A 不生效，走 B/C', () {
      // "go go" → 末尾 "go" 在 reference 中出现 2 次，非唯一
      // 规则 B: 1/2=50% → 不适用；规则 C: tailSize=2, 命中 1/2 → 5s
      final result = heuristic.computeSilenceThreshold(
        referenceText: 'go go',
        partialTranscript: 'go',
      );
      expect(result, const Duration(seconds: 5));
    });
  });

  group('ListenAndRepeatTurnController', () {
    test('完全匹配时 1s 静音即停止', () async {
      final backend = _FakeSpeechPracticeBackend(autoEmitFinal: false);
      final container = ProviderContainer(
        overrides: [
          speechPracticeBackendProvider.overrideWithValue(backend),
          listenAndRepeatPlayerProvider.overrideWith(
            () => TestListenAndRepeatPlayer(
              const ListenAndRepeatPlayerState(
                currentSentenceIndex: 0,
                totalSentences: 1,
                currentPlayCount: 1,
                isPauseBetweenPlays: true,
              ),
              createTestSentences(count: 1),
            ),
          ),
        ],
      );
      addTearDown(() async {
        await backend.dispose();
        container.dispose();
      });

      final controller = container.read(
        listenAndRepeatTurnControllerProvider.notifier,
      );
      await controller.ensureAutoTurn(
        promptId: 'shadowing:a1:0',
        referenceText: 'Anyhow I noticed your name on the door',
      );

      backend.emitPartial('I noticed your name on the door');
      backend.emitSpeechStarted();
      backend.emitSilence(const Duration(seconds: 1));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final turnState = container.read(listenAndRepeatTurnControllerProvider);
      final speechState = container.read(speechPracticeSessionProvider);
      expect(turnState.phase, ListenAndRepeatTurnPhase.processing);
      expect(speechState.awaitingFinalPromptId, 'shadowing:a1:0');
    });

    test('部分匹配（3/5 尾部词）时 3s 静音才停止', () async {
      final backend = _FakeSpeechPracticeBackend(autoEmitFinal: false);
      final container = ProviderContainer(
        overrides: [
          speechPracticeBackendProvider.overrideWithValue(backend),
          listenAndRepeatPlayerProvider.overrideWith(
            () => TestListenAndRepeatPlayer(
              const ListenAndRepeatPlayerState(
                currentSentenceIndex: 0,
                totalSentences: 1,
                currentPlayCount: 1,
                isPauseBetweenPlays: true,
              ),
              createTestSentences(count: 1),
            ),
          ),
        ],
      );
      addTearDown(() async {
        await backend.dispose();
        container.dispose();
      });

      final controller = container.read(
        listenAndRepeatTurnControllerProvider.notifier,
      );
      await controller.ensureAutoTurn(
        promptId: 'shadowing:a1:0',
        referenceText: 'Anyhow I noticed your name on the door',
      );

      // 只说了前半句 → 尾部 5 词命中 0 → 阈值 5s
      backend.emitPartial('Anyhow I noticed your');
      backend.emitSpeechStarted();

      // 2s 静音不够
      backend.emitSilence(const Duration(seconds: 2));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(
        container.read(listenAndRepeatTurnControllerProvider).phase,
        ListenAndRepeatTurnPhase.speaking,
      );

      // 5s 静音才触发（尾部 0 命中 → 5s 阈值）
      backend.emitSilence(const Duration(seconds: 5));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(
        container.read(listenAndRepeatTurnControllerProvider).phase,
        ListenAndRepeatTurnPhase.processing,
      );
    });

    test('无匹配时 5s 静音才停止', () async {
      final backend = _FakeSpeechPracticeBackend(autoEmitFinal: false);
      final container = ProviderContainer(
        overrides: [
          speechPracticeBackendProvider.overrideWithValue(backend),
          listenAndRepeatPlayerProvider.overrideWith(
            () => TestListenAndRepeatPlayer(
              const ListenAndRepeatPlayerState(
                currentSentenceIndex: 0,
                totalSentences: 1,
                currentPlayCount: 1,
                isPauseBetweenPlays: true,
              ),
              createTestSentences(count: 1),
            ),
          ),
        ],
      );
      addTearDown(() async {
        await backend.dispose();
        container.dispose();
      });

      final controller = container.read(
        listenAndRepeatTurnControllerProvider.notifier,
      );
      await controller.ensureAutoTurn(
        promptId: 'shadowing:a1:0',
        referenceText: 'Anyhow I noticed your name on the door',
      );

      // 完全不相关的内容
      backend.emitPartial('something completely different');
      backend.emitSpeechStarted();

      // 4s 不够
      backend.emitSilence(const Duration(seconds: 4));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        container.read(listenAndRepeatTurnControllerProvider).phase,
        ListenAndRepeatTurnPhase.speaking,
      );

      // 5s 触发兜底
      backend.emitSilence(const Duration(seconds: 5));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        container.read(listenAndRepeatTurnControllerProvider).phase,
        ListenAndRepeatTurnPhase.processing,
      );
    });

    test('转录停滞通道：完全匹配后 1s 不更新即自动结束（无 silenceProgress）', () {
      fakeAsync((async) {
        final backend = _FakeSpeechPracticeBackend(autoEmitFinal: false);
        final container = ProviderContainer(
          overrides: [
            speechPracticeBackendProvider.overrideWithValue(backend),
            listenAndRepeatPlayerProvider.overrideWith(
              () => TestListenAndRepeatPlayer(
                const ListenAndRepeatPlayerState(
                  currentSentenceIndex: 0,
                  totalSentences: 1,
                  currentPlayCount: 1,
                  isPauseBetweenPlays: true,
                ),
                createTestSentences(count: 1),
              ),
            ),
          ],
        );

        final controller = container.read(
          listenAndRepeatTurnControllerProvider.notifier,
        );
        controller.ensureAutoTurn(
          promptId: 'shadowing:a1:0',
          referenceText: 'Anyhow I noticed your name on the door',
        );
        async.flushMicrotasks();

        // 发送完整转录，模拟嘈杂环境（不发送 silenceProgress）
        backend.emitSpeechStarted();
        async.flushMicrotasks();
        backend.emitPartial('I noticed your name on the door');
        async.flushMicrotasks();

        expect(
          container.read(listenAndRepeatTurnControllerProvider).phase,
          ListenAndRepeatTurnPhase.speaking,
        );

        // 完全匹配 → 阈值 1s，等 1s 后停滞计时器触发
        async.elapse(const Duration(seconds: 1));

        expect(
          container.read(listenAndRepeatTurnControllerProvider).phase,
          ListenAndRepeatTurnPhase.processing,
        );

        backend.dispose();
        container.dispose();
      });
    });

    test('转录停滞通道：部分匹配后按动态阈值等待', () {
      fakeAsync((async) {
        final backend = _FakeSpeechPracticeBackend(autoEmitFinal: false);
        final container = ProviderContainer(
          overrides: [
            speechPracticeBackendProvider.overrideWithValue(backend),
            listenAndRepeatPlayerProvider.overrideWith(
              () => TestListenAndRepeatPlayer(
                const ListenAndRepeatPlayerState(
                  currentSentenceIndex: 0,
                  totalSentences: 1,
                  currentPlayCount: 1,
                  isPauseBetweenPlays: true,
                ),
                createTestSentences(count: 1),
              ),
            ),
          ],
        );

        final controller = container.read(
          listenAndRepeatTurnControllerProvider.notifier,
        );
        controller.ensureAutoTurn(
          promptId: 'shadowing:a1:0',
          referenceText: 'Anyhow I noticed your name on the door',
        );
        async.flushMicrotasks();

        backend.emitSpeechStarted();
        async.flushMicrotasks();
        // 只说前半句 → 尾部 0 命中 → 阈值 5s
        backend.emitPartial('Anyhow I noticed your');
        async.flushMicrotasks();

        // 4s 后仍在 speaking
        async.elapse(const Duration(seconds: 4));
        expect(
          container.read(listenAndRepeatTurnControllerProvider).phase,
          ListenAndRepeatTurnPhase.speaking,
        );

        // 5s 后停滞计时器触发
        async.elapse(const Duration(seconds: 1));
        expect(
          container.read(listenAndRepeatTurnControllerProvider).phase,
          ListenAndRepeatTurnPhase.processing,
        );

        backend.dispose();
        container.dispose();
      });
    });

    test('转录更新会重置停滞计时器', () {
      fakeAsync((async) {
        final backend = _FakeSpeechPracticeBackend(autoEmitFinal: false);
        final container = ProviderContainer(
          overrides: [
            speechPracticeBackendProvider.overrideWithValue(backend),
            listenAndRepeatPlayerProvider.overrideWith(
              () => TestListenAndRepeatPlayer(
                const ListenAndRepeatPlayerState(
                  currentSentenceIndex: 0,
                  totalSentences: 1,
                  currentPlayCount: 1,
                  isPauseBetweenPlays: true,
                ),
                createTestSentences(count: 1),
              ),
            ),
          ],
        );

        final controller = container.read(
          listenAndRepeatTurnControllerProvider.notifier,
        );
        controller.ensureAutoTurn(
          promptId: 'shadowing:a1:0',
          referenceText: 'Anyhow I noticed your name on the door',
        );
        async.flushMicrotasks();

        backend.emitSpeechStarted();
        async.flushMicrotasks();
        backend.emitPartial('Anyhow');
        async.flushMicrotasks();

        // 4s 后更新转录 → 重置计时器
        async.elapse(const Duration(seconds: 4));
        expect(
          container.read(listenAndRepeatTurnControllerProvider).phase,
          ListenAndRepeatTurnPhase.speaking,
        );
        backend.emitPartial('Anyhow I noticed');
        async.flushMicrotasks();

        // 再过 4s 仍在 speaking（计时器已重置）
        async.elapse(const Duration(seconds: 4));
        expect(
          container.read(listenAndRepeatTurnControllerProvider).phase,
          ListenAndRepeatTurnPhase.speaking,
        );

        // 再过 1s（共 5s 无更新）→ 触发
        async.elapse(const Duration(seconds: 1));
        expect(
          container.read(listenAndRepeatTurnControllerProvider).phase,
          ListenAndRepeatTurnPhase.processing,
        );

        backend.dispose();
        container.dispose();
      });
    });

    test('review 倒计时在回放录音时重置为完整 5 秒', () async {
      final backend = _FakeSpeechPracticeBackend();
      final container = ProviderContainer(
        overrides: [
          speechPracticeBackendProvider.overrideWithValue(backend),
          listenAndRepeatPlayerProvider.overrideWith(
            () => TestListenAndRepeatPlayer(
              const ListenAndRepeatPlayerState(
                currentSentenceIndex: 0,
                totalSentences: 1,
                currentPlayCount: 1,
                isPauseBetweenPlays: true,
              ),
              createTestSentences(count: 1),
            ),
          ),
        ],
      );
      addTearDown(() async {
        await backend.dispose();
        container.dispose();
      });

      final controller = container.read(
        listenAndRepeatTurnControllerProvider.notifier,
      );
      await controller.ensureTurn(
        promptId: 'shadowing:a1:0',
        referenceText: 'Anyhow I noticed your name on the door',
        allowAutoFallback: false,
      );
      controller.activateReviewCountdown(promptId: 'shadowing:a1:0');
      await Future<void>.delayed(const Duration(milliseconds: 350));

      controller.resetReviewCountdownOnPlayback();
      final pausedState = container.read(listenAndRepeatTurnControllerProvider);
      expect(pausedState.isReviewCountdownPaused, isTrue);
      expect(pausedState.reviewCountdownRemaining, const Duration(seconds: 5));

      controller.resumeReviewCountdown();
      await Future<void>.delayed(const Duration(milliseconds: 250));
      final resumedState = container.read(
        listenAndRepeatTurnControllerProvider,
      );
      expect(
        resumedState.reviewCountdownRemaining,
        lessThan(const Duration(seconds: 5)),
      );
    });

    test(
      '15 秒无声 waitingForUser 后调用 startManualRecording 能重新进入 awaitingSpeech',
      () {
        fakeAsync((async) {
          final backend = _FakeSpeechPracticeBackend(autoEmitFinal: false);
          final container = ProviderContainer(
            overrides: [
              speechPracticeBackendProvider.overrideWithValue(backend),
              listenAndRepeatPlayerProvider.overrideWith(
                () => TestListenAndRepeatPlayer(
                  const ListenAndRepeatPlayerState(
                    currentSentenceIndex: 0,
                    totalSentences: 1,
                    currentPlayCount: 1,
                    isPauseBetweenPlays: true,
                  ),
                  createTestSentences(count: 1),
                ),
              ),
            ],
          );

          final controller = container.read(
            listenAndRepeatTurnControllerProvider.notifier,
          );
          // sentenceDuration=5s → maxDuration=17.5s > 15s，让 15 秒回退先触发
          controller.ensureAutoTurn(
            promptId: 'shadowing:a1:0',
            referenceText: 'Hello world',
            sentenceDuration: const Duration(seconds: 5),
          );
          async.flushMicrotasks();

          // 15 秒后进入 waitingForUser
          async.elapse(const Duration(seconds: 15));
          final fallbackState = container.read(
            listenAndRepeatTurnControllerProvider,
          );
          expect(fallbackState.phase, ListenAndRepeatTurnPhase.waitingForUser);

          // 用户再点录音按钮
          controller.startManualRecording(
            promptId: 'shadowing:a1:0',
            referenceText: 'Hello world',
            sentenceDuration: const Duration(seconds: 5),
          );
          async.flushMicrotasks();

          final retriedState = container.read(
            listenAndRepeatTurnControllerProvider,
          );
          expect(retriedState.phase, ListenAndRepeatTurnPhase.awaitingSpeech);

          backend.dispose();
          container.dispose();
        });
      },
    );

    test('ASR 有转录但 VAD 未触发时，仍应从 awaitingSpeech 转为 speaking', () {
      fakeAsync((async) {
        final backend = _FakeSpeechPracticeBackend(autoEmitFinal: false);
        final container = ProviderContainer(
          overrides: [
            speechPracticeBackendProvider.overrideWithValue(backend),
            listenAndRepeatPlayerProvider.overrideWith(
              () => TestListenAndRepeatPlayer(
                const ListenAndRepeatPlayerState(
                  currentSentenceIndex: 0,
                  totalSentences: 1,
                  currentPlayCount: 1,
                  isPauseBetweenPlays: true,
                ),
                createTestSentences(count: 1),
              ),
            ),
          ],
        );

        final controller = container.read(
          listenAndRepeatTurnControllerProvider.notifier,
        );
        controller.ensureAutoTurn(
          promptId: 'shadowing:a1:0',
          referenceText: 'Hello world',
        );
        async.flushMicrotasks();

        expect(
          container.read(listenAndRepeatTurnControllerProvider).phase,
          ListenAndRepeatTurnPhase.awaitingSpeech,
        );

        // 只发送 partialTranscript，不发送 speechStarted（模拟压低声音）
        backend.emitPartial('Hello');
        async.flushMicrotasks();

        expect(
          container.read(listenAndRepeatTurnControllerProvider).phase,
          ListenAndRepeatTurnPhase.speaking,
        );

        backend.dispose();
        container.dispose();
      });
    });


    test('录音超过最大时长后自动停止并进入 processing', () {
      fakeAsync((async) {
        final backend = _FakeSpeechPracticeBackend(autoEmitFinal: false);
        final container = ProviderContainer(
          overrides: [
            speechPracticeBackendProvider.overrideWithValue(backend),
            listenAndRepeatPlayerProvider.overrideWith(
              () => TestListenAndRepeatPlayer(
                const ListenAndRepeatPlayerState(
                  currentSentenceIndex: 0,
                  totalSentences: 1,
                  currentPlayCount: 1,
                  isPauseBetweenPlays: true,
                ),
                createTestSentences(count: 1),
              ),
            ),
          ],
        );

        final controller = container.read(
          listenAndRepeatTurnControllerProvider.notifier,
        );
        // 句长 2 秒 → max(2.5×2+5, 10) = 10 秒
        controller.ensureAutoTurn(
          promptId: 'shadowing:a1:0',
          referenceText: 'Hello world',
          sentenceDuration: const Duration(seconds: 2),
        );
        async.flushMicrotasks();

        // 模拟用户一直在说话
        backend.emitSpeechStarted();
        async.flushMicrotasks();

        // 9 秒时仍在录音
        async.elapse(const Duration(seconds: 9));
        final midState = container.read(listenAndRepeatTurnControllerProvider);
        expect(midState.phase, ListenAndRepeatTurnPhase.speaking);

        // 10 秒时触发最大时长兜底
        async.elapse(const Duration(seconds: 1));
        final finalState = container.read(
          listenAndRepeatTurnControllerProvider,
        );
        expect(finalState.phase, ListenAndRepeatTurnPhase.processing);

        backend.dispose();
        container.dispose();
      });
    });

    test('评估完成后进入 reviewCountdown', () async {
      final backend = _FakeSpeechPracticeBackend(autoEmitFinal: false);
      final container = ProviderContainer(
        overrides: [
          speechPracticeBackendProvider.overrideWithValue(backend),
          listenAndRepeatPlayerProvider.overrideWith(
            () => TestListenAndRepeatPlayer(
              const ListenAndRepeatPlayerState(
                currentSentenceIndex: 0,
                totalSentences: 1,
                currentPlayCount: 1,
                isPauseBetweenPlays: true,
              ),
              createTestSentences(count: 1),
            ),
          ),
        ],
      );
      addTearDown(() async {
        await backend.dispose();
        container.dispose();
      });

      final controller = container.read(
        listenAndRepeatTurnControllerProvider.notifier,
      );
      await controller.ensureAutoTurn(
        promptId: 'shadowing:a1:0',
        referenceText: 'Anyhow I noticed your name on the door',
      );

      final stopFuture = controller.handleManualStop();

      // 发送高分 final transcript（命中大部分词）
      await Future<void>.delayed(const Duration(milliseconds: 10));
      backend._controller.add(
        SpeechPracticeEvent(
          type: SpeechPracticeEventType.finalTranscriptReady,
          promptId: 'shadowing:a1:0',
          transcript: 'I noticed your name on the door',
        ),
      );
      await stopFuture;
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // 高分应进入 reviewCountdown
      final reviewState = container.read(listenAndRepeatTurnControllerProvider);
      expect(reviewState.phase, ListenAndRepeatTurnPhase.reviewCountdown);
    });

    test('快进倒计时立即跳过进入 idle', () {
      fakeAsync((async) {
        final backend = _FakeSpeechPracticeBackend();
        final container = ProviderContainer(
          overrides: [
            speechPracticeBackendProvider.overrideWithValue(backend),
            listenAndRepeatPlayerProvider.overrideWith(
              () => TestListenAndRepeatPlayer(
                const ListenAndRepeatPlayerState(
                  currentSentenceIndex: 0,
                  totalSentences: 1,
                  currentPlayCount: 1,
                  isPauseBetweenPlays: true,
                ),
                createTestSentences(count: 1),
              ),
            ),
          ],
        );

        final controller = container.read(
          listenAndRepeatTurnControllerProvider.notifier,
        );
        controller.ensureTurn(
          promptId: 'shadowing:a1:0',
          referenceText: 'Hello world',
          allowAutoFallback: false,
        );
        async.flushMicrotasks();

        // 进入 reviewCountdown
        controller.activateReviewCountdown(promptId: 'shadowing:a1:0');
        expect(
          container.read(listenAndRepeatTurnControllerProvider).phase,
          ListenAndRepeatTurnPhase.reviewCountdown,
        );

        // 快进 → 立即跳过倒计时
        controller.fastForwardReviewCountdown();
        async.flushMicrotasks();

        final after = container.read(listenAndRepeatTurnControllerProvider);
        expect(after.phase, ListenAndRepeatTurnPhase.idle);

        backend.dispose();
        container.dispose();
      });
    });

    test('非 reviewCountdown 阶段调用快进无效', () {
      fakeAsync((async) {
        final backend = _FakeSpeechPracticeBackend();
        final container = ProviderContainer(
          overrides: [
            speechPracticeBackendProvider.overrideWithValue(backend),
            listenAndRepeatPlayerProvider.overrideWith(
              () => TestListenAndRepeatPlayer(
                const ListenAndRepeatPlayerState(
                  currentSentenceIndex: 0,
                  totalSentences: 1,
                  currentPlayCount: 1,
                  isPauseBetweenPlays: true,
                ),
                createTestSentences(count: 1),
              ),
            ),
          ],
        );

        final controller = container.read(
          listenAndRepeatTurnControllerProvider.notifier,
        );
        controller.ensureTurn(
          promptId: 'shadowing:a1:0',
          referenceText: 'Hello world',
          allowAutoFallback: false,
        );
        async.flushMicrotasks();

        // awaitingSpeech 阶段调用快进，不应改变状态
        expect(
          container.read(listenAndRepeatTurnControllerProvider).phase,
          ListenAndRepeatTurnPhase.awaitingSpeech,
        );
        controller.fastForwardReviewCountdown();
        async.flushMicrotasks();

        expect(
          container.read(listenAndRepeatTurnControllerProvider).phase,
          ListenAndRepeatTurnPhase.awaitingSpeech,
        );

        backend.dispose();
        container.dispose();
      });
    });

    test('录音正常结束时 maxDurationTimer 不触发', () {
      fakeAsync((async) {
        final backend = _FakeSpeechPracticeBackend(autoEmitFinal: false);
        final container = ProviderContainer(
          overrides: [
            speechPracticeBackendProvider.overrideWithValue(backend),
            listenAndRepeatPlayerProvider.overrideWith(
              () => TestListenAndRepeatPlayer(
                const ListenAndRepeatPlayerState(
                  currentSentenceIndex: 0,
                  totalSentences: 1,
                  currentPlayCount: 1,
                  isPauseBetweenPlays: true,
                ),
                createTestSentences(count: 1),
              ),
            ),
          ],
        );

        final controller = container.read(
          listenAndRepeatTurnControllerProvider.notifier,
        );
        // 句长 4 秒 → max(2.5×4+5, 10) = 15 秒
        controller.startManualRecording(
          promptId: 'shadowing:a1:0',
          referenceText: 'Anyhow I noticed your name on the door',
          sentenceDuration: const Duration(seconds: 4),
        );
        async.flushMicrotasks();

        // 5 秒后模拟录音正常结束（进入 processing）
        async.elapse(const Duration(seconds: 5));
        controller.enterProcessing('shadowing:a1:0');
        final earlyState = container.read(
          listenAndRepeatTurnControllerProvider,
        );
        expect(earlyState.phase, ListenAndRepeatTurnPhase.processing);

        // 推进到超过最大时长，状态不应改变（timer 已被取消）
        async.elapse(const Duration(seconds: 20));
        final lateState = container.read(listenAndRepeatTurnControllerProvider);
        expect(lateState.phase, ListenAndRepeatTurnPhase.processing);

        backend.dispose();
        container.dispose();
      });
    });
  });
}
