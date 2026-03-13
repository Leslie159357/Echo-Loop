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

    test('句尾命中且整体分数足够时判定已说完', () {
      final result = heuristic.isLikelyComplete(
        referenceText: 'Anyhow I noticed your name on the door',
        partialTranscript: 'I noticed your name on the door',
      );

      expect(result, isTrue);
    });

    test('整体分数不足时即使有句尾也不判定已说完', () {
      final result = heuristic.isLikelyComplete(
        referenceText: 'Anyhow I noticed your name on the door',
        partialTranscript: 'name on the door',
      );

      expect(result, isFalse);
    });

    test('没有命中句尾词时不判定已说完', () {
      final result = heuristic.isLikelyComplete(
        referenceText: 'Anyhow I noticed your name on the door',
        partialTranscript: 'Anyhow I noticed your name',
      );

      expect(result, isFalse);
    });
  });

  group('ListenAndRepeatTurnController', () {
    test('静音 1 秒且内容看起来已说完时自动进入 processing', () async {
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
      '15 秒无声 manualFallback 后调用 startManualRecording 能重新进入 awaitingSpeech',
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

          // 15 秒后进入 manualFallback
          async.elapse(const Duration(seconds: 15));
          final fallbackState = container.read(
            listenAndRepeatTurnControllerProvider,
          );
          expect(fallbackState.phase, ListenAndRepeatTurnPhase.manualFallback);

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

    test(
      '识别失败（noEnglishDetected）时进入 retryPending 自动重试',
      () async {
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
          referenceText: 'Hello world',
        );

        final stopFuture = controller.handleManualStop();

        // 发送空 final transcript → matcher 判定 noEnglishDetected
        await Future<void>.delayed(const Duration(milliseconds: 10));
        backend._controller.add(
          SpeechPracticeEvent(
            type: SpeechPracticeEventType.finalTranscriptReady,
            promptId: 'shadowing:a1:0',
            transcript: '',
          ),
        );
        await stopFuture;
        await Future<void>.delayed(const Duration(milliseconds: 50));

        final turnState = container.read(listenAndRepeatTurnControllerProvider);
        expect(turnState.phase, ListenAndRepeatTurnPhase.retryPending);
      },
    );

    test('连续 3 次检测失败后退出自动录音进入 manualFallback', () async {
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
        referenceText: 'Hello world',
      );

      // 第 1 次失败 → retryPending
      var stopFuture = controller.handleManualStop();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      backend._controller.add(
        SpeechPracticeEvent(
          type: SpeechPracticeEventType.finalTranscriptReady,
          promptId: 'shadowing:a1:0',
          transcript: '',
        ),
      );
      await stopFuture;
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        container.read(listenAndRepeatTurnControllerProvider).phase,
        ListenAndRepeatTurnPhase.retryPending,
      );

      // 第 2 次失败 → retryPending
      // 手动触发重试（模拟 timer 到期）
      await controller.ensureTurn(
        promptId: 'shadowing:a1:0',
        referenceText: 'Hello world',
        allowAutoFallback: false,
      );
      stopFuture = controller.handleManualStop();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      backend._controller.add(
        SpeechPracticeEvent(
          type: SpeechPracticeEventType.finalTranscriptReady,
          promptId: 'shadowing:a1:0',
          transcript: '',
        ),
      );
      await stopFuture;
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        container.read(listenAndRepeatTurnControllerProvider).phase,
        ListenAndRepeatTurnPhase.retryPending,
      );

      // 第 3 次失败 → manualFallback（连续 3 次上限）
      await controller.ensureTurn(
        promptId: 'shadowing:a1:0',
        referenceText: 'Hello world',
        allowAutoFallback: false,
      );
      stopFuture = controller.handleManualStop();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      backend._controller.add(
        SpeechPracticeEvent(
          type: SpeechPracticeEventType.finalTranscriptReady,
          promptId: 'shadowing:a1:0',
          transcript: '',
        ),
      );
      await stopFuture;
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        container.read(listenAndRepeatTurnControllerProvider).phase,
        ListenAndRepeatTurnPhase.manualFallback,
      );
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
        final midState = container.read(
          listenAndRepeatTurnControllerProvider,
        );
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

    test('评级未达 Fair 时进入 retryPending 并自动重新录音', () async {
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

      // 手动停止 → processing
      final stopFuture = controller.handleManualStop();

      // 发送低分 final transcript（只命中 1/8 个词）
      await Future<void>.delayed(const Duration(milliseconds: 10));
      backend._controller.add(
        SpeechPracticeEvent(
          type: SpeechPracticeEventType.finalTranscriptReady,
          promptId: 'shadowing:a1:0',
          transcript: 'hello',
        ),
      );
      await stopFuture;
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // 应进入 retryPending（评级低于 Fair）
      final retryState = container.read(listenAndRepeatTurnControllerProvider);
      expect(retryState.phase, ListenAndRepeatTurnPhase.retryPending);
    });

    test('评级达到 Fair 时正常进入 reviewCountdown', () async {
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

    test('retryPending 2 秒后自动重新开始录音', () {
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

        // 手动停止 → processing
        controller.handleManualStop();
        async.flushMicrotasks();

        // 发送低分 final transcript
        backend._controller.add(
          SpeechPracticeEvent(
            type: SpeechPracticeEventType.finalTranscriptReady,
            promptId: 'shadowing:a1:0',
            transcript: 'hello',
          ),
        );
        async.flushMicrotasks();

        // 应进入 retryPending
        final retryState = container.read(
          listenAndRepeatTurnControllerProvider,
        );
        expect(retryState.phase, ListenAndRepeatTurnPhase.retryPending);

        // 4 秒后应自动重新录音
        async.elapse(const Duration(seconds: 4));
        final retriedState = container.read(
          listenAndRepeatTurnControllerProvider,
        );
        expect(retriedState.phase, ListenAndRepeatTurnPhase.awaitingSpeech);

        backend.dispose();
        container.dispose();
      });
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
        final lateState = container.read(
          listenAndRepeatTurnControllerProvider,
        );
        expect(lateState.phase, ListenAndRepeatTurnPhase.processing);

        backend.dispose();
        container.dispose();
      });
    });
  });
}
