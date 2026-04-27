/// 盲听专用播放器 Provider（段落分段播放模式）
///
/// 参考 RetellPlayer 的段落播放模式，去掉复述相关逻辑。
/// 核心功能：
/// - 段落播放（playRangeOnce：首句 startTime → 末句 endTime）
/// - 播放期间句子高亮（监听 absolutePositionStream + 二分查找）
/// - 段间停顿倒计时（段落播放完→倒计时→重复或下一段）
/// - 遍数循环（播完段落→倒计时为一遍，达到遍数后推进下一段）
/// - 文本显示模式切换（全部隐藏/全部显示）
library;

import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../analytics/analytics_providers.dart';
import '../../services/app_logger.dart';
import '../../analytics/models/event_names.dart';
import '../../database/providers.dart';
import '../../models/blind_listen_settings.dart';
import '../../models/sentence.dart';
import '../../models/study_stage.dart';
import '../../services/learned_vocabulary_tracker.dart';
import '../../services/silence_skip_detector.dart';
import '../../services/study_event_recorder.dart';
import '../../utils/word_counter.dart';
import '../audio_engine/audio_engine_provider.dart';
import '../learned_vocabulary_tracker_provider.dart';
import '../learning_progress_provider.dart';
import '../settings_provider.dart';
import 'countdown_controller.dart';
import 'learning_session_provider.dart';

part 'blind_listen_player_provider.g.dart';

/// 盲听文本显示模式
enum BlindListenDisplayMode {
  /// 全部隐藏
  hideAll,

  /// 全部显示
  showAll,
}

/// 盲听播放器状态
class BlindListenPlayerState {
  /// 当前段落索引（0-based）
  final int currentParagraphIndex;

  /// 总段落数
  final int totalParagraphs;

  /// 段内正在播放的句子索引（-1 = 未播放）
  final int playingSentenceIndex;

  /// 当前遍数（1-based）
  final int currentRepeatCount;

  /// 当前段是否已完整播放结束过一次
  final bool hasCompletedCurrentParagraphPlayback;

  /// 是否正在播放
  final bool isPlaying;

  /// 段间停顿倒计时进行中
  final bool isPauseCountdown;

  /// 倒计时剩余时间
  final Duration pauseRemaining;

  /// 倒计时总时长
  final Duration pauseDuration;

  /// 倒计时是否暂停中
  final bool isCountdownPaused;

  /// 倒计时是否快进中
  final bool isCountdownFastForward;

  /// 文本显示模式
  final BlindListenDisplayMode displayMode;

  /// 是否正在等待用户继续操作
  final bool isWaitingForUser;

  /// 盲听设置
  final BlindListenSettings settings;

  /// 当前步骤是否自然完成（用于 Screen 层检测完成信号）
  final bool stepFinished;

  const BlindListenPlayerState({
    this.currentParagraphIndex = 0,
    this.totalParagraphs = 0,
    this.playingSentenceIndex = -1,
    this.currentRepeatCount = 1,
    this.hasCompletedCurrentParagraphPlayback = false,
    this.isPlaying = false,
    this.isPauseCountdown = false,
    this.pauseRemaining = Duration.zero,
    this.pauseDuration = Duration.zero,
    this.isCountdownPaused = false,
    this.isCountdownFastForward = false,
    this.displayMode = BlindListenDisplayMode.hideAll,
    this.isWaitingForUser = false,
    this.settings = const BlindListenSettings(),
    this.stepFinished = false,
  });

  BlindListenPlayerState copyWith({
    int? currentParagraphIndex,
    int? totalParagraphs,
    int? playingSentenceIndex,
    int? currentRepeatCount,
    bool? hasCompletedCurrentParagraphPlayback,
    bool? isPlaying,
    bool? isPauseCountdown,
    Duration? pauseRemaining,
    Duration? pauseDuration,
    bool? isCountdownPaused,
    bool? isCountdownFastForward,
    BlindListenDisplayMode? displayMode,
    bool? isWaitingForUser,
    BlindListenSettings? settings,
    bool? stepFinished,
  }) {
    return BlindListenPlayerState(
      currentParagraphIndex:
          currentParagraphIndex ?? this.currentParagraphIndex,
      totalParagraphs: totalParagraphs ?? this.totalParagraphs,
      playingSentenceIndex: playingSentenceIndex ?? this.playingSentenceIndex,
      currentRepeatCount: currentRepeatCount ?? this.currentRepeatCount,
      hasCompletedCurrentParagraphPlayback:
          hasCompletedCurrentParagraphPlayback ??
          this.hasCompletedCurrentParagraphPlayback,
      isPlaying: isPlaying ?? this.isPlaying,
      isPauseCountdown: isPauseCountdown ?? this.isPauseCountdown,
      pauseRemaining: pauseRemaining ?? this.pauseRemaining,
      pauseDuration: pauseDuration ?? this.pauseDuration,
      isCountdownPaused: isCountdownPaused ?? this.isCountdownPaused,
      isCountdownFastForward:
          isCountdownFastForward ?? this.isCountdownFastForward,
      displayMode: displayMode ?? this.displayMode,
      isWaitingForUser: isWaitingForUser ?? this.isWaitingForUser,
      settings: settings ?? this.settings,
      stepFinished: stepFinished ?? this.stepFinished,
    );
  }
}

/// 盲听专用播放器 Provider
@Riverpod(keepAlive: true)
class BlindListenPlayer extends _$BlindListenPlayer {
  /// 段落列表
  List<List<Sentence>> _paragraphs = [];

  /// 学习事件记录器
  late StudyEventRecorder _recorder;

  /// position 监听（句子高亮）
  StreamSubscription<Duration>? _positionSub;

  /// 可控倒计时控制器
  final CountdownController _countdown = CountdownController();

  /// 当前 AudioEngine sessionId
  int _sessionId = -1;

  /// 倒计时运行版本号
  int _countdownRunId = 0;

  /// 当前段落播完后进入等待态
  bool _waitAfterCurrentParagraph = false;

  /// 上次跳过的静音段去重 key（避免位置流抖动重复触发同一个 gap）
  int? _lastSkippedSilenceKey;

  /// 静音跳过事件流，UI 侧订阅以弹 snackbar
  final StreamController<Duration> _silenceSkipEvents =
      StreamController<Duration>.broadcast();

  /// 静音跳过事件流（gap 时长），UI 侧订阅以弹 snackbar
  Stream<Duration> get silenceSkipEventStream => _silenceSkipEvents.stream;

  @override
  BlindListenPlayerState build() {
    LearnedVocabularyTracker? vocabTracker;
    try {
      vocabTracker = ref.read(learnedVocabularyTrackerProvider);
    } catch (e) {
      AppLogger.log('Player', '⚠ vocabTracker 不可用（测试环境？）: $e');
    }
    _recorder = StudyEventRecorder(
      studyTimeService: ref.read(studyTimeServiceProvider),
      vocabTracker: vocabTracker,
      stage: StudyStage.blindListen,
    );

    final lifecycleListener = AppLifecycleListener(
      onStateChange: _handleAppLifecycleChange,
    );
    ref.onDispose(() {
      lifecycleListener.dispose();
      _positionSub?.cancel();
      _invalidateCountdown();
      _silenceSkipEvents.close();
    });
    return const BlindListenPlayerState();
  }

  /// App 进入后台时暂停倒计时（音频继续播放）
  void _handleAppLifecycleChange(AppLifecycleState appState) {
    if (appState == AppLifecycleState.paused ||
        appState == AppLifecycleState.hidden) {
      if (state.isPauseCountdown) {
        pauseCountdown();
      }
    }
  }

  /// 初始化段落播放
  ///
  /// [startParagraphIndex] 断点续学段落索引，自动 clamp 到有效范围。
  void initializeParagraphs(
    List<List<Sentence>> paragraphs,
    BlindListenSettings settings, {
    int startParagraphIndex = 0,
  }) {
    _cleanup();
    _paragraphs = paragraphs;

    final safeIndex = paragraphs.isEmpty
        ? 0
        : startParagraphIndex.clamp(0, paragraphs.length - 1);

    state = BlindListenPlayerState(
      currentParagraphIndex: safeIndex,
      totalParagraphs: paragraphs.length,
      settings: settings,
    );
    ref.read(analyticsServiceProvider).track(Events.blindListenStart, {
      EventParams.audioId: ref.read(learningSessionProvider).audioItemId ?? '',
      EventParams.passNumber: ref
          .read(learningSessionProvider)
          .blindListenPassCount,
    });
  }

  /// 获取当前段落的句子列表
  List<Sentence> get currentParagraphSentences =>
      _paragraphs.isNotEmpty && state.currentParagraphIndex < _paragraphs.length
      ? _paragraphs[state.currentParagraphIndex]
      : [];

  /// 获取当前段落时长
  Duration get currentParagraphDuration {
    final sentences = currentParagraphSentences;
    if (sentences.isEmpty) return Duration.zero;
    return sentences.last.endTime - sentences.first.startTime;
  }

  /// 开始播放第一段
  Future<void> startPlaying() async {
    if (_paragraphs.isEmpty) return;
    await _playCurrentParagraph();
  }

  /// 暂停播放
  ///
  /// 使旧 session 失效 + 停止音频，resume 时从段落开头重播。
  Future<void> pause() async {
    final engine = ref.read(audioEngineProvider.notifier);
    _sessionId = engine.newSession();
    _positionSub?.cancel();
    _invalidateCountdown();
    await engine.stopPlayback();
    state = state.copyWith(
      isPlaying: false,
      isPauseCountdown: false,
      isCountdownPaused: false,
    );
  }

  /// 恢复播放
  Future<void> resume() async {
    await _playCurrentParagraph();
  }

  /// 跳转到下一段
  Future<void> goToNextParagraph() async {
    // 最后一段 → 停止播放，由 screen 处理完成逻辑
    if (state.currentParagraphIndex >= state.totalParagraphs - 1) {
      await _cancelAll();
      state = state.copyWith(isPlaying: false, isPauseCountdown: false);
      return;
    }

    await _cancelAll();
    state = state.copyWith(
      currentParagraphIndex: state.currentParagraphIndex + 1,
      currentRepeatCount: 1,
      hasCompletedCurrentParagraphPlayback: false,
      playingSentenceIndex: -1,
      isPauseCountdown: false,
      isCountdownPaused: false,
      displayMode: BlindListenDisplayMode.hideAll,
    );

    await _playCurrentParagraph();
  }

  /// 跳转到上一段
  Future<void> goToPreviousParagraph() async {
    if (state.currentParagraphIndex <= 0) return;

    await _cancelAll();
    state = state.copyWith(
      currentParagraphIndex: state.currentParagraphIndex - 1,
      currentRepeatCount: 1,
      hasCompletedCurrentParagraphPlayback: false,
      playingSentenceIndex: -1,
      isPauseCountdown: false,
      isCountdownPaused: false,
      displayMode: BlindListenDisplayMode.hideAll,
    );

    await _playCurrentParagraph();
  }

  /// 重新开始：重置到第一段
  Future<void> restart() async {
    await _cancelAll();
    state = BlindListenPlayerState(
      currentParagraphIndex: 0,
      totalParagraphs: _paragraphs.length,
      settings: state.settings,
      displayMode: BlindListenDisplayMode.hideAll,
    );
    await _playCurrentParagraph();
  }

  /// 设置显示模式
  void setDisplayMode(BlindListenDisplayMode mode) {
    state = state.copyWith(displayMode: mode);
  }

  /// 进入等待用户状态。
  ///
  /// 如果当前段落正在播放且 [afterCurrentParagraph] 为 true，
  /// 则允许当前段自然播完后再停在等待态。
  void enterWaitingForUser({bool afterCurrentParagraph = false}) {
    if (state.isWaitingForUser || state.stepFinished) return;

    if (state.isPlaying && afterCurrentParagraph) {
      _waitAfterCurrentParagraph = true;
      AppLogger.log(
        'BlindListenPlayer',
        '-> WaitingForUser (after current paragraph)',
      );
      return;
    }

    _waitAfterCurrentParagraph = false;
    final engine = ref.read(audioEngineProvider.notifier);
    _sessionId = engine.newSession();
    _positionSub?.cancel();
    _invalidateCountdown();
    unawaited(engine.stopPlayback());
    state = state.copyWith(
      isPlaying: false,
      isPauseCountdown: false,
      isCountdownPaused: false,
      playingSentenceIndex: -1,
      isWaitingForUser: true,
    );
    AppLogger.log('BlindListenPlayer', '-> WaitingForUser');
  }

  /// 更新设置
  ///
  /// 切换到手动模式时，停在当前段落，取消一切异步操作。
  void updateSettings(BlindListenSettings newSettings) {
    final modeChanged = newSettings.isManualMode != state.settings.isManualMode;
    final shouldKeepWaiting =
        state.isWaitingForUser || _waitAfterCurrentParagraph;

    state = state.copyWith(settings: newSettings);

    if (shouldKeepWaiting) {
      return;
    }

    // 自动↔手动切换时，停在当前段落，取消一切异步操作并进入等待态。
    if (modeChanged) {
      final engine = ref.read(audioEngineProvider.notifier);
      _sessionId = engine.newSession();
      _positionSub?.cancel();
      _invalidateCountdown();
      unawaited(engine.stopPlayback());
      state = state.copyWith(
        isPlaying: false,
        isPauseCountdown: false,
        isCountdownPaused: false,
        playingSentenceIndex: -1,
        isWaitingForUser: true,
      );
    }
  }

  /// 暂停倒计时
  void pauseCountdown() {
    _countdown.pause();
    state = state.copyWith(isCountdownPaused: true);
  }

  /// 恢复倒计时
  void resumeCountdown() {
    _countdown.resume();
    state = state.copyWith(isCountdownPaused: false);
  }

  /// 取消倒计时
  void cancelCountdown() {
    _invalidateCountdown();
    state = state.copyWith(isPauseCountdown: false, isCountdownPaused: false);
  }

  /// 切换倒计时快进
  ///
  /// 快进时剩余倒计时在 ~1.5 秒内完成。
  /// 如果当前暂停中，快进会同时恢复倒计时。
  void toggleCountdownFastForward() {
    final isFF = !state.isCountdownFastForward;
    if (isFF) {
      _countdown.fastForward();
    } else {
      _countdown.setSpeed(1.0);
    }
    if (state.isCountdownPaused) {
      _countdown.resume();
    }
    state = state.copyWith(
      isCountdownFastForward: isFF,
      isCountdownPaused: false,
    );
  }

  /// 释放资源
  void disposePlayer() {
    _cleanup();
    _paragraphs = [];
    state = const BlindListenPlayerState();
  }

  // ========== 内部方法 ==========

  /// 异步保存盲听断点段落索引，不阻塞播放流程
  void _persistCurrentParagraphIndexAsync() {
    final session = ref.read(learningSessionProvider);
    final audioItemId = session.audioItemId;
    if (audioItemId == null) return;

    unawaited(
      ref
          .read(learningProgressNotifierProvider.notifier)
          .saveBlindListenParagraphIndex(
            audioItemId,
            state.currentParagraphIndex,
            isFreePlay: session.isFreePlay,
          ),
    );
  }

  /// 播放当前段落
  Future<void> _playCurrentParagraph() async {
    _persistCurrentParagraphIndexAsync();
    final sentences = currentParagraphSentences;
    if (sentences.isEmpty) return;

    final engine = ref.read(audioEngineProvider.notifier);
    _sessionId = engine.newSession();
    final sid = _sessionId;

    state = state.copyWith(
      hasCompletedCurrentParagraphPlayback: false,
      isPlaying: true,
      playingSentenceIndex: 0,
      isPauseCountdown: false,
      isWaitingForUser: false,
      stepFinished: false,
    );

    _startPositionTracking(sentences);

    final start = sentences.first.startTime;
    final end = sentences.last.endTime;

    await engine.playRangeOnce(start, end, sid);

    if (!engine.isActiveSession(sid)) return;

    // 通过 recorder 记录听力时长、输入词数、已学词形
    final paragraphWordCount = countWordsInSentences(sentences);
    final durationMs =
        (sentences.last.endTime - sentences.first.startTime).inMilliseconds;
    final paragraphText = sentences.map((s) => s.text).join(' ');
    _recorder.onInputCompleted(
      durationMs: durationMs,
      wordCount: paragraphWordCount,
      text: paragraphText,
    );

    _positionSub?.cancel();

    if (_waitAfterCurrentParagraph) {
      _waitAfterCurrentParagraph = false;
      state = state.copyWith(
        hasCompletedCurrentParagraphPlayback: true,
        isPlaying: false,
        isPauseCountdown: false,
        isCountdownPaused: false,
        playingSentenceIndex: -1,
        isWaitingForUser: true,
      );
      return;
    }

    // 手动模式：播放完直接停止，等待用户操作
    if (state.settings.isManualMode) {
      final isLastParagraph =
          state.currentParagraphIndex >= state.totalParagraphs - 1;
      state = state.copyWith(
        hasCompletedCurrentParagraphPlayback: true,
        isPlaying: false,
        playingSentenceIndex: -1,
        isWaitingForUser: false,
        stepFinished: isLastParagraph,
      );
      return;
    }

    _startPauseCountdown();
  }

  /// 订阅 position stream，二分查找定位当前句子
  void _startPositionTracking(List<Sentence> sentences) {
    _positionSub?.cancel();
    _lastSkippedSilenceKey = null; // 新段落，清空去重指针
    final engine = ref.read(audioEngineProvider.notifier);

    _positionSub = engine.absolutePositionStream.listen((position) {
      if (!engine.isActiveSession(_sessionId)) return;

      final idx = _findSentenceIndex(sentences, position);
      if (idx != state.playingSentenceIndex && idx >= 0) {
        state = state.copyWith(playingSentenceIndex: idx);
      }
      _maybeSkipSilence(sentences, position, idx);
    });
  }

  /// 静音跳过判定（开关开启时生效）。
  ///
  /// 段落 clip 范围 = [first.start, last.end]，因此 detector 的末尾分支
  /// 在盲听场景永远不会命中——这里只会在中间 gap 触发。
  void _maybeSkipSilence(
    List<Sentence> sentences,
    Duration position,
    int idx,
  ) {
    final settings = ref.read(appSettingsProvider);
    if (!settings.skipSilenceEnabled) return;

    final result = SilenceSkipDetector.detect(
      position: position,
      sentences: sentences,
      currentIdx: idx,
      thresholdSeconds: settings.silenceThresholdSeconds,
      playbackEnd: sentences.last.endTime,
    );
    if (result == null) return;
    if (_lastSkippedSilenceKey == result.dedupKey) return;

    _lastSkippedSilenceKey = result.dedupKey;
    unawaited(
      ref.read(audioEngineProvider.notifier).seekToAbsolute(result.skipTo),
    );

    // 仅在静音段较长（> 5s）时才弹 snackbar，避免短跳过频繁打扰
    if (result.gapDuration.inSeconds > 5) {
      _silenceSkipEvents.add(result.gapDuration);
    }
  }

  /// 二分查找当前播放位置对应的句子索引
  int _findSentenceIndex(List<Sentence> sentences, Duration position) {
    var lo = 0;
    var hi = sentences.length - 1;

    while (lo <= hi) {
      final mid = (lo + hi) ~/ 2;
      if (position < sentences[mid].startTime) {
        hi = mid - 1;
      } else if (position >= sentences[mid].endTime) {
        lo = mid + 1;
      } else {
        return mid;
      }
    }

    return lo.clamp(0, sentences.length - 1);
  }

  /// 启动段间停顿倒计时
  void _startPauseCountdown() {
    final duration = state.settings.calculatePauseDuration(
      currentParagraphDuration,
    );
    final runId = ++_countdownRunId;

    state = state.copyWith(
      isPlaying: false,
      isPauseCountdown: true,
      pauseDuration: duration,
      pauseRemaining: duration,
      isCountdownPaused: false,
      isCountdownFastForward: false,
      playingSentenceIndex: -1,
      hasCompletedCurrentParagraphPlayback: true,
      isWaitingForUser: false,
    );

    _countdown.start(duration).then((_) {
      if (state.isPauseCountdown && runId == _countdownRunId) {
        _onPauseCountdownFinished();
      }
    });
  }

  /// 段间停顿结束
  Future<void> _onPauseCountdownFinished() async {
    if (state.currentRepeatCount < state.settings.repeatCount) {
      // 当前段还有遍数 → 直接继续播放，不经过 isPauseCountdown=false 中间状态
      state = state.copyWith(currentRepeatCount: state.currentRepeatCount + 1);
      await _playCurrentParagraph();
    } else if (state.currentParagraphIndex < state.totalParagraphs - 1) {
      // 还有下一段 → 推进
      state = state.copyWith(isPauseCountdown: false);
      await goToNextParagraph();
    } else {
      // 最后一段最后一遍 → 停止
      state = state.copyWith(
        isPauseCountdown: false,
        isPlaying: false,
        isWaitingForUser: false,
        stepFinished: true,
      );
      ref.read(analyticsServiceProvider).track(Events.blindListenComplete, {
        EventParams.audioId:
            ref.read(learningSessionProvider).audioItemId ?? '',
        EventParams.passNumber: state.currentRepeatCount,
      });
    }
  }

  /// 取消所有异步操作并停止音频
  Future<void> _cancelAll() async {
    final engine = ref.read(audioEngineProvider.notifier);
    _sessionId = engine.newSession();
    _positionSub?.cancel();
    _invalidateCountdown();
    _waitAfterCurrentParagraph = false;
    await engine.stopPlayback();
  }

  /// 使当前倒计时失效
  void _invalidateCountdown() {
    _countdownRunId += 1;
    _countdown.cancel();
  }

  /// 清理资源
  void _cleanup() {
    _positionSub?.cancel();
    _invalidateCountdown();
    _waitAfterCurrentParagraph = false;
    _positionSub = null;
  }
}
