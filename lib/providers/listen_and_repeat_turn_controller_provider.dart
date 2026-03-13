/// 跟读回合状态机 provider。
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/speech_practice_models.dart';
import 'learning_session/listen_and_repeat_player_provider.dart';
import 'speech_practice_session_provider.dart';

const _awaitingSpeechReminderDelay = Duration(seconds: 5);
const _awaitingSpeechFallbackDelay = Duration(seconds: 15);
const _silenceCompletionCheckDelay = Duration(seconds: 1);
const _silenceAutoStopDelay = Duration(seconds: 5);
const _reviewCountdownDuration = Duration(seconds: 5);
const _completionHeuristicThreshold = 0.65;
const _completionHeuristicTailTokens = 2;

enum ListenAndRepeatTurnPhase {
  idle,
  awaitingSpeech,
  speaking,
  processing,
  reviewCountdown,
  manualFallback,
}

class ListenAndRepeatTurnState {
  final ListenAndRepeatTurnPhase phase;
  final String? promptId;
  final String? referenceText;
  final bool hasShownSpeechReminder;
  final Duration reviewCountdownRemaining;
  final bool isReviewCountdownPaused;

  const ListenAndRepeatTurnState({
    this.phase = ListenAndRepeatTurnPhase.idle,
    this.promptId,
    this.referenceText,
    this.hasShownSpeechReminder = false,
    this.reviewCountdownRemaining = _reviewCountdownDuration,
    this.isReviewCountdownPaused = false,
  });

  bool get isActive =>
      phase != ListenAndRepeatTurnPhase.idle &&
      phase != ListenAndRepeatTurnPhase.manualFallback;

  ListenAndRepeatTurnState copyWith({
    ListenAndRepeatTurnPhase? phase,
    String? promptId,
    bool clearPromptId = false,
    String? referenceText,
    bool clearReferenceText = false,
    bool? hasShownSpeechReminder,
    Duration? reviewCountdownRemaining,
    bool? isReviewCountdownPaused,
  }) {
    return ListenAndRepeatTurnState(
      phase: phase ?? this.phase,
      promptId: clearPromptId ? null : (promptId ?? this.promptId),
      referenceText: clearReferenceText
          ? null
          : (referenceText ?? this.referenceText),
      hasShownSpeechReminder:
          hasShownSpeechReminder ?? this.hasShownSpeechReminder,
      reviewCountdownRemaining:
          reviewCountdownRemaining ?? this.reviewCountdownRemaining,
      isReviewCountdownPaused:
          isReviewCountdownPaused ?? this.isReviewCountdownPaused,
    );
  }
}

class SpeechPracticeCompletionHeuristic {
  const SpeechPracticeCompletionHeuristic();

  static final RegExp _englishWordPattern = RegExp(r"[A-Za-z]+(?:'[A-Za-z]+)?");

  bool isLikelyComplete({
    required String referenceText,
    required String partialTranscript,
  }) {
    final referenceTokens = _tokenize(referenceText);
    final transcriptTokens = _tokenize(partialTranscript);
    if (referenceTokens.isEmpty || transcriptTokens.isEmpty) {
      return false;
    }

    final lcsPairs = _computeLcsPairs(referenceTokens, transcriptTokens);
    if (lcsPairs.isEmpty) {
      return false;
    }

    final score = lcsPairs.length / referenceTokens.length;
    if (score < _completionHeuristicThreshold) {
      return false;
    }

    final tailSize = referenceTokens.length < _completionHeuristicTailTokens
        ? referenceTokens.length
        : _completionHeuristicTailTokens;
    final tailReferenceIndexes = <int>{
      for (
        var i = referenceTokens.length - tailSize;
        i < referenceTokens.length;
        i++
      )
        i,
    };
    final matchedTailIndexes = lcsPairs.map((pair) => pair.$1).toSet();
    return tailReferenceIndexes.every(matchedTailIndexes.contains);
  }

  List<String> _tokenize(String text) {
    return _englishWordPattern
        .allMatches(text.toLowerCase())
        .map((match) => match.group(0) ?? '')
        .where((token) => token.isNotEmpty)
        .toList();
  }

  List<(int, int)> _computeLcsPairs(
    List<String> referenceTokens,
    List<String> transcriptTokens,
  ) {
    final rows = referenceTokens.length + 1;
    final cols = transcriptTokens.length + 1;
    final dp = List.generate(rows, (_) => List.filled(cols, 0));

    for (var i = 1; i < rows; i++) {
      for (var j = 1; j < cols; j++) {
        if (referenceTokens[i - 1] == transcriptTokens[j - 1]) {
          dp[i][j] = dp[i - 1][j - 1] + 1;
        } else {
          dp[i][j] = dp[i - 1][j] > dp[i][j - 1] ? dp[i - 1][j] : dp[i][j - 1];
        }
      }
    }

    final pairs = <(int, int)>[];
    var i = referenceTokens.length;
    var j = transcriptTokens.length;
    while (i > 0 && j > 0) {
      if (referenceTokens[i - 1] == transcriptTokens[j - 1]) {
        pairs.add((i - 1, j - 1));
        i -= 1;
        j -= 1;
      } else if (dp[i - 1][j] >= dp[i][j - 1]) {
        i -= 1;
      } else {
        j -= 1;
      }
    }
    return pairs.reversed.toList();
  }
}

final speechPracticeCompletionHeuristicProvider =
    Provider<SpeechPracticeCompletionHeuristic>((ref) {
      return const SpeechPracticeCompletionHeuristic();
    });

final listenAndRepeatTurnControllerProvider =
    NotifierProvider<ListenAndRepeatTurnController, ListenAndRepeatTurnState>(
      ListenAndRepeatTurnController.new,
    );

class ListenAndRepeatTurnController extends Notifier<ListenAndRepeatTurnState> {
  Timer? _speechReminderTimer;
  Timer? _speechFallbackTimer;
  Timer? _reviewTickTimer;
  bool _isStopping = false;

  @override
  ListenAndRepeatTurnState build() {
    ref.onDispose(_cancelAllTimers);
    ref.listen<SpeechPracticeSessionState>(
      speechPracticeSessionProvider,
      _handleSpeechPracticeStateChanged,
    );
    return const ListenAndRepeatTurnState();
  }

  Future<void> ensureTurn({
    required String promptId,
    required String referenceText,
    bool allowAutoFallback = true,
  }) async {
    if (state.promptId == promptId && state.isActive) {
      return;
    }

    _cancelAllTimers();
    _isStopping = false;
    state = ListenAndRepeatTurnState(
      phase: ListenAndRepeatTurnPhase.awaitingSpeech,
      promptId: promptId,
      referenceText: referenceText,
      reviewCountdownRemaining: _reviewCountdownDuration,
    );

    final session = ref.read(speechPracticeSessionProvider.notifier);
    await session.startRecording(promptId: promptId);
    final currentAttempt = ref
        .read(speechPracticeSessionProvider.notifier)
        .attemptFor(promptId);
    if (currentAttempt?.status != SpeechPracticeAttemptStatus.recording) {
      state = state.copyWith(phase: ListenAndRepeatTurnPhase.idle);
      return;
    }

    if (allowAutoFallback) {
      _scheduleAwaitingSpeechTimers(promptId);
    }
  }

  /// 自动跟读回合开始：启动录音并启用提醒与回退。
  Future<void> ensureAutoTurn({
    required String promptId,
    required String referenceText,
  }) {
    return ensureTurn(
      promptId: promptId,
      referenceText: referenceText,
      allowAutoFallback: true,
    );
  }

  /// 手动回退后的重新录音：仍然使用同一状态机，但不再显示 5/15 秒自动提醒。
  Future<void> startManualRecording({
    required String promptId,
    required String referenceText,
  }) {
    return ensureTurn(
      promptId: promptId,
      referenceText: referenceText,
      allowAutoFallback: false,
    );
  }

  void enterProcessing(String promptId) {
    if (state.promptId != promptId) {
      return;
    }
    _cancelAwaitingSpeechTimers();
    _cancelReviewCountdown();
    state = state.copyWith(phase: ListenAndRepeatTurnPhase.processing);
  }

  Future<void> handleManualStop() async {
    final promptId = state.promptId;
    final referenceText = state.referenceText;
    if (promptId == null || referenceText == null) {
      return;
    }
    _isStopping = true;
    enterProcessing(promptId);
    await ref
        .read(speechPracticeSessionProvider.notifier)
        .stopRecordingAndEvaluate(
          promptId: promptId,
          referenceText: referenceText,
        );
  }

  Future<void> handleContinue() async {
    _cancelReviewCountdown();
    state = state.copyWith(phase: ListenAndRepeatTurnPhase.idle);
    await ref.read(listenAndRepeatPlayerProvider.notifier).completePausedTurn();
  }

  void pauseReviewCountdown() {
    if (state.phase != ListenAndRepeatTurnPhase.reviewCountdown) {
      return;
    }
    _reviewTickTimer?.cancel();
    state = state.copyWith(isReviewCountdownPaused: true);
  }

  void resumeReviewCountdown() {
    if (state.phase != ListenAndRepeatTurnPhase.reviewCountdown) {
      return;
    }
    if (state.reviewCountdownRemaining <= Duration.zero) {
      unawaited(handleContinue());
      return;
    }
    state = state.copyWith(isReviewCountdownPaused: false);
    _startReviewCountdown();
  }

  void resetReviewCountdownOnPlayback() {
    if (state.phase != ListenAndRepeatTurnPhase.reviewCountdown) {
      return;
    }
    _reviewTickTimer?.cancel();
    state = state.copyWith(
      reviewCountdownRemaining: _reviewCountdownDuration,
      isReviewCountdownPaused: true,
    );
  }

  void activateReviewCountdown({required String promptId}) {
    if (state.promptId != promptId) {
      return;
    }
    _cancelAwaitingSpeechTimers();
    _cancelReviewCountdown();
    state = state.copyWith(
      phase: ListenAndRepeatTurnPhase.reviewCountdown,
      reviewCountdownRemaining: _reviewCountdownDuration,
      isReviewCountdownPaused: false,
    );
    _startReviewCountdown();
  }

  void clearTurn() {
    _cancelAllTimers();
    _isStopping = false;
    state = const ListenAndRepeatTurnState();
  }

  void _handleSpeechPracticeStateChanged(
    SpeechPracticeSessionState? previous,
    SpeechPracticeSessionState next,
  ) {
    final promptId = state.promptId;
    if (promptId == null) {
      return;
    }
    final previousAttempt = previous?.attempts[promptId];
    final attempt = next.attempts[promptId];
    if (attempt == null) {
      return;
    }

    _handleAttemptPlaybackChanged(
      previousPlayingPromptId: previous?.playingPromptId,
      nextPlayingPromptId: next.playingPromptId,
      promptId: promptId,
    );

    if (attempt.status == SpeechPracticeAttemptStatus.awaitingFinal) {
      enterProcessing(promptId);
      return;
    }

    if (attempt.hasFinalFeedback &&
        !(previousAttempt?.hasFinalFeedback ?? false)) {
      // 识别失败或未检测到英语时回退为手动录音，等待用户操作
      if (attempt.status == SpeechPracticeAttemptStatus.noEnglishDetected ||
          attempt.status == SpeechPracticeAttemptStatus.error ||
          attempt.status == SpeechPracticeAttemptStatus.permissionDenied ||
          attempt.status == SpeechPracticeAttemptStatus.unavailable) {
        _cancelAllTimers();
        state = state.copyWith(phase: ListenAndRepeatTurnPhase.manualFallback);
        return;
      }
      activateReviewCountdown(promptId: promptId);
      return;
    }

    if (state.phase == ListenAndRepeatTurnPhase.awaitingSpeech &&
        attempt.hasDetectedSpeech) {
      _cancelAwaitingSpeechTimers();
      state = state.copyWith(phase: ListenAndRepeatTurnPhase.speaking);
    }

    if (state.phase == ListenAndRepeatTurnPhase.speaking && !_isStopping) {
      _handleSpeakingAttemptUpdate(
        promptId: promptId,
        attempt: attempt,
        previousAttempt: previousAttempt,
      );
    }
  }

  void _scheduleAwaitingSpeechTimers(String promptId) {
    _speechReminderTimer?.cancel();
    _speechFallbackTimer?.cancel();
    _speechReminderTimer = Timer(_awaitingSpeechReminderDelay, () {
      if (state.promptId != promptId ||
          state.phase != ListenAndRepeatTurnPhase.awaitingSpeech) {
        return;
      }
      state = state.copyWith(hasShownSpeechReminder: true);
    });
    _speechFallbackTimer = Timer(_awaitingSpeechFallbackDelay, () async {
      if (state.promptId != promptId ||
          state.phase != ListenAndRepeatTurnPhase.awaitingSpeech) {
        return;
      }
      await ref
          .read(speechPracticeSessionProvider.notifier)
          .cancelActiveRecording();
      state = state.copyWith(phase: ListenAndRepeatTurnPhase.manualFallback);
    });
  }

  void _handleSpeakingAttemptUpdate({
    required String promptId,
    required SpeechPracticeAttempt attempt,
    required SpeechPracticeAttempt? previousAttempt,
  }) {
    final prompt = state.promptId;
    final referenceText = state.referenceText;
    if (prompt != promptId || referenceText == null) {
      return;
    }

    final currentSilence = attempt.silenceDuration;
    final previousSilence = previousAttempt?.silenceDuration ?? Duration.zero;
    if (!attempt.hasDetectedSpeech) {
      return;
    }

    if (currentSilence >= _silenceAutoStopDelay &&
        previousSilence < _silenceAutoStopDelay) {
      _stopForEvaluation(promptId: promptId, referenceText: referenceText);
      return;
    }

    if (currentSilence >= _silenceCompletionCheckDelay &&
        previousSilence < _silenceCompletionCheckDelay) {
      final liveTranscript = attempt.liveTranscript?.trim() ?? '';
      if (liveTranscript.isEmpty) {
        return;
      }
      final heuristic = ref.read(speechPracticeCompletionHeuristicProvider);
      if (heuristic.isLikelyComplete(
        referenceText: referenceText,
        partialTranscript: liveTranscript,
      )) {
        _stopForEvaluation(promptId: promptId, referenceText: referenceText);
      }
    }
  }

  void _handleAttemptPlaybackChanged({
    required String? previousPlayingPromptId,
    required String? nextPlayingPromptId,
    required String promptId,
  }) {
    if (state.phase != ListenAndRepeatTurnPhase.reviewCountdown) {
      return;
    }
    if (previousPlayingPromptId != promptId &&
        nextPlayingPromptId == promptId) {
      resetReviewCountdownOnPlayback();
      return;
    }
    if (previousPlayingPromptId == promptId &&
        nextPlayingPromptId != promptId) {
      state = state.copyWith(
        reviewCountdownRemaining: _reviewCountdownDuration,
        isReviewCountdownPaused: false,
      );
      _startReviewCountdown();
    }
  }

  void _startReviewCountdown() {
    _reviewTickTimer?.cancel();
    _reviewTickTimer = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) async {
      if (state.phase != ListenAndRepeatTurnPhase.reviewCountdown ||
          state.isReviewCountdownPaused) {
        return;
      }
      final nextRemaining =
          state.reviewCountdownRemaining - const Duration(milliseconds: 100);
      if (nextRemaining <= Duration.zero) {
        timer.cancel();
        state = state.copyWith(reviewCountdownRemaining: Duration.zero);
        await handleContinue();
        return;
      }
      state = state.copyWith(reviewCountdownRemaining: nextRemaining);
    });
  }

  void _stopForEvaluation({
    required String promptId,
    required String referenceText,
  }) {
    _isStopping = true;
    enterProcessing(promptId);
    unawaited(
      ref
          .read(speechPracticeSessionProvider.notifier)
          .stopRecordingAndEvaluate(
            promptId: promptId,
            referenceText: referenceText,
          ),
    );
  }

  void _cancelAwaitingSpeechTimers() {
    _speechReminderTimer?.cancel();
    _speechFallbackTimer?.cancel();
    _speechReminderTimer = null;
    _speechFallbackTimer = null;
  }

  void _cancelReviewCountdown() {
    _reviewTickTimer?.cancel();
    _reviewTickTimer = null;
  }

  void _cancelAllTimers() {
    _cancelAwaitingSpeechTimers();
    _cancelReviewCountdown();
  }
}
