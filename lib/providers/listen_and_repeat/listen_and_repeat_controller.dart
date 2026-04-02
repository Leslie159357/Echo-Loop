/// 跟读会话控制器
///
/// **唯一的状态入口**：所有状态变更都通过此控制器。
/// Screen 只读 state、只调公开方法，不直接操作资源服务。
///
/// 流程：PlayingPrompt → Recording → (ReviewingRecording) → WaitingInterval → 下一遍/句
///
/// 关键设计：
/// - 倒计时只在 WaitingInterval
/// - flowToken 防异步竞态
/// - 切句原子重置
/// - 手动暂停(保留剩余) vs 外部打断(重置T)
library;

import 'dart:async';
import 'dart:math' as math;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../database/providers.dart';
import '../../models/intensive_listen_settings.dart';
import '../../models/sentence.dart';
import '../../models/study_stage.dart';
import '../../services/app_logger.dart';
import '../../services/audio_playback_service.dart';
import '../audio_engine/audio_engine_provider.dart';
import '../learning_progress_provider.dart';
import '../learning_session/countdown_controller.dart';
import '../learning_session/sentence_playback_engine.dart';
import '../speech/speech_recording_controller.dart';
import '../listening_practice/bookmark_manager.dart';
import '../study_task_controller_mixin.dart';
import 'listen_and_repeat_phase.dart';
import 'listen_and_repeat_session_state.dart';
import 'listen_and_repeat_settings_provider.dart';

part 'listen_and_repeat_controller.g.dart';

/// 智能停顿模式下句子时长的倍数
const _kSmartPauseMultiplier = 2;

/// 智能停顿最小时长（毫秒）
const _kSmartPauseMinMs = 2000;

/// 倍率停顿最小时长（毫秒）
const _kMultiplierPauseMinMs = 1000;

/// 倒计时快进速度倍率
const _kFastForwardSpeed = 10.0;

/// 录音最大时长 = sentenceDuration × 此倍率 + _kRecordingTimeoutBase
const _kRecordingDurationMultiplier = 2.5;

/// 录音超时基础时长
const _kRecordingTimeoutBase = Duration(seconds: 5);

/// 录音最小超时时长
const _kRecordingMinTimeout = Duration(seconds: 10);

/// 跟读差异化配置
///
/// 各页面（跟读/难句补练/收藏复习）通过不同 Config 注入差异行为。
class ListenAndRepeatConfig {
  /// 音频项 ID（用于构建 promptId）
  final String audioItemId;

  /// 获取指定句子的目标遍数
  final int Function(Sentence sentence) getRepeatCount;

  /// 获取遍间倒计时时长
  final Duration Function(Sentence sentence) getIntervalDuration;

  /// 是否手动模式（手动模式下不自动录音、不自动倒计时推进）
  final bool Function() isManualMode;

  /// 句子播放前的钩子（如收藏复习需要跨音频加载）
  final Future<void> Function(int sentenceIndex)? onBeforeSentenceStart;

  /// 句子播完一遍的回调（用于学习统计）
  final void Function(Sentence sentence)? onSentencePlayed;

  const ListenAndRepeatConfig({
    required this.audioItemId,
    required this.getRepeatCount,
    required this.getIntervalDuration,
    required this.isManualMode,
    this.onBeforeSentenceStart,
    this.onSentencePlayed,
  });
}

/// 跟读会话控制器
@Riverpod(keepAlive: true)
class ListenAndRepeatController extends _$ListenAndRepeatController
    with StudyTaskControllerMixin {
  /// 句子列表
  List<Sentence> _sentences = [];

  /// 差异化配置
  late ListenAndRepeatConfig _config;

  /// 倒计时控制器
  final CountdownController _countdown = CountdownController();

  /// 录音回放服务
  final AudioPlaybackService _playbackService = AudioPlaybackService();

  @override
  ListenAndRepeatSessionState build() {
    // 监听录音控制器状态变化（评估完成时推进流程）
    ref.listen(speechRecordingControllerProvider, _onRecordingStateChanged);

    // 打印状态变化日志
    ref.listenSelf((prev, next) {
      if (prev?.phase.runtimeType != next.phase.runtimeType ||
          prev?.sentenceIndex != next.sentenceIndex ||
          prev?.repeatIndex != next.repeatIndex) {
        final recPhase = ref.read(speechRecordingControllerProvider).phase;
        AppLogger.log(
          'L&R State',
          '${next.phase.runtimeType} | '
              '句${next.sentenceIndex + 1}/${next.totalSentences} '
              '遍${next.repeatIndex + 1}/${next.totalRepeats} | '
              '录音=$recPhase | '
              'token=${next.flowToken}',
        );
      }
    });

    ref.onDispose(() {
      _countdown.cancel();
      _playbackService.dispose();
    });
    return const ListenAndRepeatSessionState();
  }

  // ========== 初始化 ==========

  /// 初始化跟读任务（从 DB 读数据 + 启动学习计时 + 开始播放）
  ///
  /// 替代 LearningSessionProvider.enterListenAndRepeatMode()，
  /// 把所有初始化逻辑收到 Controller 内部。
  Future<void> initialize({
    required String audioItemId,
    required List<Sentence> allSentences,
    required bool isFreePlay,
  }) async {
    // 从 DB 读难句索引
    final bookmarkDao = ref.read(bookmarkDaoProvider);
    final bookmarkedIndices = await bookmarkDao.getBookmarkedIndices(
      audioItemId,
    );
    final difficultSentences = allSentences
        .where((s) => bookmarkedIndices.contains(s.index))
        .toList();

    // 从 DB 读断点
    final progress = await ref
        .read(learningProgressNotifierProvider.notifier)
        .getLatestOrEnsureProgress(audioItemId);
    int startIndex = 0;
    if (isFreePlay) {
      startIndex = progress.freePlayShadowingSentenceIndex ?? 0;
    } else {
      startIndex = progress.shadowingSentenceIndex ?? 0;
    }

    // 根据难度计算目标遍数
    final targetPlayCount = targetPlayCountForDifficulty(
      progress.difficulty.value,
    );

    // 初始化设置
    ref
        .read(listenAndRepeatSettingsProvider.notifier)
        .initialize(repeatCount: targetPlayCount);

    // 学习任务通用初始化（计时、LP、音频、analytics）
    await initStudyTask(
      ref,
      audioItemId: audioItemId,
      stage: StudyStage.listenAndRepeat,
      isFreePlay: isFreePlay,
    );

    // 构造 config 并启动会话
    final config = ListenAndRepeatConfig(
      audioItemId: audioItemId,
      getRepeatCount: (_) =>
          ref.read(listenAndRepeatSettingsProvider).repeatCount,
      getIntervalDuration: (s) {
        final st = ref.read(listenAndRepeatSettingsProvider);
        return switch (st.pauseMode) {
          PauseMode.smart => Duration(
            milliseconds: math.max(
              s.duration.inMilliseconds * _kSmartPauseMultiplier,
              _kSmartPauseMinMs,
            ),
          ),
          PauseMode.fixed => Duration(seconds: st.fixedPauseSeconds),
          PauseMode.multiplier => Duration(
            milliseconds: math.max(
              (s.duration.inMilliseconds * st.pauseMultiplier).round(),
              _kMultiplierPauseMinMs,
            ),
          ),
        };
      },
      isManualMode: () =>
          ref.read(listenAndRepeatSettingsProvider).isManualMode,
    );

    // 只准备数据，不自动播放。Screen 进入后调 startPlaying()。
    await prepareSession(
      sentences: difficultSentences,
      config: config,
      startIndex: startIndex,
      isFreePlay: isFreePlay,
    );
  }

  // ========== 公开方法（Screen 调用） ==========

  /// 准备会话数据（不自动播放，Screen 进入后调 startPlaying）
  Future<void> prepareSession({
    required List<Sentence> sentences,
    required ListenAndRepeatConfig config,
    int startIndex = 0,
    bool isFreePlay = false,
  }) async {
    _sentences = sentences.map((s) => s.copyWith()).toList();
    _config = config;

    final safeIndex = _sentences.isEmpty
        ? 0
        : startIndex.clamp(0, _sentences.length - 1);
    final sentence = _sentences[safeIndex];

    state = ListenAndRepeatSessionState(
      phase: const Idle(),
      sentenceIndex: safeIndex,
      totalSentences: _sentences.length,
      totalRepeats: config.getRepeatCount(sentence),
      intervalDuration: config.getIntervalDuration(sentence),
      flowToken: 1,
      isFreePlay: isFreePlay,
    );

    // 同步录音控制器模式
    ref
        .read(speechRecordingControllerProvider.notifier)
        .setManualMode(config.isManualMode());
  }

  /// 开始播放（Screen 进入后调用）
  Future<void> startPlaying() async {
    if (_sentences.isEmpty) return;
    await _playCurrentSentence();
  }

  /// 进入等待用户操作状态
  ///
  /// 停止所有资源（播放/录音/倒计时），进入 WaitingForUser。
  /// 用户做任何操作（录音/播放/切句）后自动恢复正常流程。
  void enterWaitingForUser() {
    final phase = state.phase;
    if (phase is WaitingForUser || phase is Idle || phase is SessionCompleted) {
      return;
    }

    _stopActiveResources();
    state = state.copyWith(
      phase: const WaitingForUser(WaitingReason.userInteraction),
    );
    AppLogger.log('L&R', '→ WaitingForUser (从 ${phase.runtimeType})');
  }

  /// 下一句（原子重置）
  Future<void> nextSentence() async {
    if (state.isLastSentence) return;
    await _jumpToSentence(state.sentenceIndex + 1);
  }

  /// 上一句（原子重置）
  Future<void> previousSentence() async {
    if (state.isFirstSentence) return;
    await _jumpToSentence(state.sentenceIndex - 1);
  }

  /// 录音按钮点击（Screen 直接调，不做判断）
  ///
  /// 根据当前状态决定：开始录音 / 停止录音。
  Future<void> onRecordButtonTapped() async {
    final phase = state.phase;
    if (phase is Recording) {
      await stopRecording();
      return;
    }
    // 先停回放
    if (phase is ReviewingRecording) {
      await stopPlayback();
    }
    startManualRecording();
  }

  /// 录音回放按钮点击（Screen 直接调，不做判断）
  ///
  /// 根据当前状态决定：开始回放 / 停止回放。
  Future<void> togglePlayback() async {
    if (state.phase is ReviewingRecording) {
      await stopPlayback();
    } else {
      await playRecording();
    }
  }

  /// 手动开始录音
  ///
  /// 在 WaitingInterval 或 WaitingForUser 阶段允许开始录音。
  void startManualRecording() {
    final phase = state.phase;
    if (phase is! WaitingInterval && phase is! WaitingForUser) {
      AppLogger.log(
        'L&R',
        'startManualRecording 跳过: phase=${phase.runtimeType}',
      );
      return;
    }
    _startRecording();
  }

  /// 手动停止录音
  ///
  /// 如果未检测到语音，取消录音（不评估）回到 WaitingInterval 等用户重试。
  /// 如果已检测到语音，停止并评估。
  Future<void> stopRecording() async {
    if (state.phase is! Recording) return;
    final sentence = _currentSentence;
    if (sentence == null) return;

    final recController = ref.read(speechRecordingControllerProvider.notifier);
    final recState = ref.read(speechRecordingControllerProvider);

    if (!recState.hasDetectedSpeech) {
      // 没检测到语音 → 取消录音，回到等待状态
      AppLogger.log('L&R', '手动停止录音: 无语音 → 取消');
      await recController.cancelActiveRecording();
      state = state.copyWith(
        phase: const WaitingForUser(WaitingReason.recordingFailed),
      );
      return;
    }

    AppLogger.log('L&R', '手动停止录音: 有语音 → 评估');
    await recController.stopAndEvaluate(referenceText: sentence.text);
    // 评估完成后 _onRecordingStateChanged 回调推进流程
  }

  /// 播放录音回放
  Future<void> playRecording() async {
    final path = state.recordingPath;
    if (path == null || path.isEmpty) return;

    final phase = state.phase;
    if (phase is! WaitingInterval && phase is! WaitingForUser && phase is! Idle)
      return;

    // 如果在倒计时中，取消倒计时
    if (phase is WaitingInterval) {
      _countdown.cancel();
    }

    state = state.copyWith(phase: ReviewingRecording(recordingPath: path));
    final token = state.flowToken;
    AppLogger.log('L&R', '播放录音回放: $path');

    // play 返回的 Future 在播放完成或 stop 时 complete
    await _playbackService.play(path);

    // 校验 token + phase，防止播放期间用户已切句/停止
    if (token != state.flowToken) return;
    if (state.phase is! ReviewingRecording) return;
    _onReviewPlaybackFinished();
  }

  /// 停止录音回放
  Future<void> stopPlayback() async {
    if (state.phase is! ReviewingRecording) return;
    await _playbackService.stop();
    _onReviewPlaybackFinished();
  }

  /// 用户打开弹窗（查词典/设置等）→ 进入等待用户状态
  void onUserInteraction() {
    enterWaitingForUser();
  }

  /// 用户关闭设置弹窗 → 同步设置变更
  void onSettingsClosed() {
    ref
        .read(speechRecordingControllerProvider.notifier)
        .setManualMode(_config.isManualMode());
  }

  /// 快进倒计时（10 倍速）
  void fastForwardInterval() {
    AppLogger.log(
      'L&R',
      'fastForward: phase=${state.phase.runtimeType}, '
          'countdownActive=${_countdown.isActive}, '
          'countdownPaused=${_countdown.isPaused}, '
          'speed=${_countdown.speed}',
    );
    if (state.phase is! WaitingInterval) return;
    if (!_countdown.isActive) return;
    _countdown.setSpeed(_kFastForwardSpeed);
    AppLogger.log(
      'L&R',
      '倒计时快进 ${_kFastForwardSpeed}x → speed=${_countdown.speed}',
    );
  }

  /// 暂停倒计时（WaitingInterval 中用户点击倒计时圆环）
  void pauseInterval() {
    final phase = state.phase;
    AppLogger.log(
      'L&R',
      'pauseInterval: phase=${phase.runtimeType}, '
          'countdownActive=${_countdown.isActive}, '
          'countdownPaused=${_countdown.isPaused}',
    );
    if (phase is! WaitingInterval) return;
    if (_countdown.isPaused) return;
    _countdown.pause();
    state = state.copyWith(phase: phase.copyWith(isPaused: true));
    AppLogger.log('L&R', '倒计时暂停 ✓');
  }

  /// 恢复倒计时
  void resumeInterval() {
    final phase = state.phase;
    AppLogger.log(
      'L&R',
      'resumeInterval: phase=${phase.runtimeType}, '
          'countdownActive=${_countdown.isActive}, '
          'countdownPaused=${_countdown.isPaused}, '
          'isPaused=${phase is WaitingInterval ? phase.isPaused : 'N/A'}',
    );
    if (phase is! WaitingInterval) return;
    if (!_countdown.isPaused) return;
    _countdown.resume();
    state = state.copyWith(phase: phase.copyWith(isPaused: false));
    AppLogger.log('L&R', '倒计时恢复 ✓');
  }

  /// 停止会话
  void stopSession() {
    _atomicReset();
    state = state.copyWith(phase: const Idle());
  }

  /// 释放资源
  void disposeSession() {
    _atomicReset();
    ref.read(speechRecordingControllerProvider.notifier).fullReset();
    _sentences = [];
    state = const ListenAndRepeatSessionState();
  }

  /// 重播当前句子（倒计时期间用户点击播放按钮时调用）
  ///
  /// 停止所有资源，保持当前遍数，重新播放当前句子。
  Future<void> replayCurrentSentence() async {
    _stopActiveResources();
    ref.read(speechRecordingControllerProvider.notifier).clearRecording();
    state = state.copyWith(
      recordingPath: null,
      recordingScore: null,
      flowToken: state.flowToken + 1,
    );
    await _playCurrentSentence();
  }

  /// 切换当前句子的收藏标记（内存 + DB）
  Future<void> toggleCurrentBookmark() async {
    if (_sentences.isEmpty) return;
    final idx = state.sentenceIndex;
    final s = _sentences[idx];
    final wasBookmarked = s.isBookmarked;
    _sentences[idx] = s.copyWith(isBookmarked: !wasBookmarked);
    state = state.copyWith(flowToken: state.flowToken + 1);

    final bookmarkDao = ref.read(bookmarkDaoProvider);
    if (wasBookmarked) {
      await bookmarkDao.removeBookmark(_config.audioItemId, s.index);
    } else {
      await BookmarkManager.addBookmarkToDb(
        _config.audioItemId,
        s,
        dao: bookmarkDao,
      );
    }
  }

  // ========== 进度管理 ==========

  /// 保存跟读断点
  Future<void> saveBreakpoint({required bool isFreePlay}) async {
    await ref
        .read(learningProgressNotifierProvider.notifier)
        .saveShadowingSentenceIndex(
          _config.audioItemId,
          state.sentenceIndex,
          isFreePlay: isFreePlay,
        );
  }

  /// 清除断点（完成时调用）
  Future<void> clearBreakpoint({required bool isFreePlay}) async {
    await ref
        .read(learningProgressNotifierProvider.notifier)
        .saveShadowingSentenceIndex(
          _config.audioItemId,
          null,
          isFreePlay: isFreePlay,
        );
  }

  /// 递增跟读遍数统计
  Future<void> incrementPassCount() async {
    await ref
        .read(learningProgressNotifierProvider.notifier)
        .incrementShadowingPassCount(_config.audioItemId);
  }

  /// 标记当前子步骤完成
  Future<void> completeSubStage() async {
    await ref
        .read(learningProgressNotifierProvider.notifier)
        .completeCurrentSubStage(_config.audioItemId);
  }

  /// 退出学习模式（释放资源 + 保存时长 + 恢复 LP）
  Future<void> exitLearningMode() async {
    disposeSession();
    await disposeStudyTask(ref);
  }

  /// 获取当前句子（供 Screen 读取）
  Sentence? get currentSentence => _currentSentence;

  /// 当前句子的 promptId（供 Screen 匹配录音状态）
  String get currentPromptId {
    final sentence = _currentSentence;
    final idx = sentence?.index ?? state.sentenceIndex;
    return 'lar:${_config.audioItemId}:$idx';
  }

  /// 当前配置（供 onStudyAgain 复用）
  ListenAndRepeatConfig get config => _config;

  /// 获取当前句子索引
  int get currentIndex => state.sentenceIndex;

  /// 获取句子列表（只读）
  List<Sentence> get sentences => List.unmodifiable(_sentences);

  // ========== 录音状态监听 ==========

  /// 录音控制器状态变化回调
  void _onRecordingStateChanged(
    SpeechRecordingState? prev,
    SpeechRecordingState next,
  ) {
    if (prev == null) return;
    if (prev.phase != next.phase) {
      AppLogger.log(
        'L&R Rec',
        '${prev.phase.name} → ${next.phase.name} | '
            'attempt=${next.currentAttempt != null} | '
            'score=${next.currentAttempt?.score}',
      );
    }

    // 评估完成（processing → idle，有结果）→ 推进流程
    if (prev.phase == SpeechRecordingPhase.processing &&
        next.phase == SpeechRecordingPhase.idle &&
        next.currentAttempt != null) {
      final token = state.flowToken;
      final attempt = next.currentAttempt!;
      _onRecordingFinished(token, attempt.filePath, attempt.score);
    }

    // 录音取消/超时（→ idle 无结果）→ 等待用户操作
    if (state.phase is Recording &&
        next.phase == SpeechRecordingPhase.idle &&
        next.currentAttempt == null) {
      AppLogger.log('L&R', '录音取消/超时 → WaitingForUser');
      state = state.copyWith(
        phase: const WaitingForUser(WaitingReason.recordingFailed),
      );
    }
  }

  // ========== 资源回调（内部方法） ==========

  /// 原句播放完成回调
  void _onPromptFinished(int token) {
    if (token != state.flowToken) return;
    if (state.phase is! PlayingPrompt) return;

    AppLogger.log('L&R', '原句播放完成');
    _config.onSentencePlayed?.call(_currentSentence!);

    if (_config.isManualMode()) {
      // 手动模式：不自动录音，等用户手动操作
      state = state.copyWith(
        phase: const WaitingForUser(WaitingReason.userInteraction),
      );
      return;
    }

    // 自动模式：开始录音
    _startRecording();
  }

  /// 录音完成回调（自动/手动统一收口）
  void _onRecordingFinished(int token, String? filePath, double? score) {
    if (token != state.flowToken) return;
    if (state.phase is! Recording) return;

    AppLogger.log(
      'L&R',
      score != null ? '录音评估完成: score=$score' : '录音评估失败: 无有效识别结果',
    );
    state = state.copyWith(recordingPath: filePath, recordingScore: score);

    // 识别失败（score 为 null）：回到等待状态，清掉失败的 attempt
    if (score == null) {
      AppLogger.log('L&R', '→ 识别失败，等待用户重试');
      // 先改 phase，再 clear，避免 clearRecording 触发 _onRecordingStateChanged 时
      // state.phase 还是 Recording 导致二次触发
      state = state.copyWith(
        phase: const WaitingForUser(WaitingReason.recordingFailed),
        recordingPath: null,
        recordingScore: null,
      );
      ref.read(speechRecordingControllerProvider.notifier).clearRecording();
      return;
    }

    // 手动模式：等用户操作
    if (_config.isManualMode()) {
      AppLogger.log('L&R', '→ 手动模式，等待用户操作');
      state = state.copyWith(
        phase: const WaitingForUser(WaitingReason.userInteraction),
      );
      return;
    }

    // 自动模式 + 识别成功：进入遍间倒计时
    _startInterval(resetFull: true);
  }

  /// 录音回放完成回调
  void _onReviewPlaybackFinished() {
    if (state.phase is! ReviewingRecording) return;

    AppLogger.log('L&R', '回放结束 → WaitingInterval');

    if (_config.isManualMode()) {
      state = state.copyWith(
        phase: const WaitingForUser(WaitingReason.userInteraction),
      );
      return;
    }

    // 自动模式：回放结束后重置完整 T 秒
    _startInterval(resetFull: true);
  }

  /// 倒计时 tick 回调
  void _onIntervalTick(int token, Duration remaining) {
    if (token != state.flowToken) return;
    final phase = state.phase;
    if (phase is! WaitingInterval) return;
    state = state.copyWith(phase: phase.copyWith(remaining: remaining));
  }

  /// 倒计时结束回调
  void _onIntervalFinished() {
    if (state.phase is! WaitingInterval) return;
    _advanceToNextRepeatOrSentence();
  }

  // ========== 内部流程方法 ==========

  /// 播放当前句子
  Future<void> _playCurrentSentence() async {
    final sentence = _currentSentence;
    if (sentence == null) return;

    // 跳过零时长句子
    if (sentence.duration <= Duration.zero) {
      _advanceToNextRepeatOrSentence();
      return;
    }

    await _config.onBeforeSentenceStart?.call(state.sentenceIndex);

    state = state.copyWith(phase: const PlayingPrompt());
    final token = state.flowToken;

    AppLogger.log(
      'L&R',
      '播放句子 ${state.sentenceIndex + 1}/${state.totalSentences} '
          '第 ${state.repeatIndex + 1}/${state.totalRepeats} 遍',
    );

    final engine = ref.read(audioEngineProvider.notifier);
    final sessionId = engine.newSession();
    await engine.playClipOnce(sentence, sessionId);

    _onPromptFinished(token);
  }

  /// 启动录音
  void _startRecording() {
    final sentence = _currentSentence;
    if (sentence == null) return;

    final promptId = 'lar:${_config.audioItemId}:${sentence.index}';
    state = state.copyWith(phase: Recording(promptId: promptId));

    // 设置录音阈值：max(multiplier × sentenceDuration + base, minTimeout)
    final computed =
        sentence.duration * _kRecordingDurationMultiplier +
        _kRecordingTimeoutBase;
    final maxDuration = computed < _kRecordingMinTimeout
        ? _kRecordingMinTimeout
        : computed;

    final controller = ref.read(speechRecordingControllerProvider.notifier);
    controller.setMaxRecordingDuration(maxDuration);

    AppLogger.log('L&R', '开始录音: $promptId');
    unawaited(
      controller.startRecording(
        promptId: promptId,
        referenceText: sentence.text,
      ),
    );
  }

  /// 启动遍间倒计时
  Future<void> _startInterval({required bool resetFull}) async {
    final total = state.intervalDuration;
    final currentPhase = state.phase;
    final remaining = resetFull || currentPhase is! WaitingInterval
        ? total
        : currentPhase.remaining;

    state = state.copyWith(
      phase: WaitingInterval(remaining: remaining, total: total),
    );

    if (_config.isManualMode()) return;

    final token = state.flowToken;
    await _countdown.start(remaining, (rem) {
      _onIntervalTick(token, rem);
    });

    // 倒计时自然结束（cancel 也会 complete，用 token 区分）
    if (token == state.flowToken && state.phase is WaitingInterval) {
      _onIntervalFinished();
    }
  }

  /// 推进到下一遍或下一句
  void _advanceToNextRepeatOrSentence() {
    if (state.isLastRepeat) {
      if (state.isLastSentence) {
        AppLogger.log('L&R', '全部完成');
        state = state.copyWith(phase: const SessionCompleted());
      } else {
        AppLogger.log('L&R', '当前句完成 → 下一句');
        _jumpToSentence(state.sentenceIndex + 1);
      }
    } else {
      final nextRepeat = state.repeatIndex + 1;
      AppLogger.log('L&R', '下一遍: ${nextRepeat + 1}/${state.totalRepeats}');
      ref.read(speechRecordingControllerProvider.notifier).clearRecording();
      state = state.copyWith(
        repeatIndex: nextRepeat,
        recordingPath: null,
        recordingScore: null,
      );
      _playCurrentSentence();
    }
  }

  /// 跳转到指定句子（原子重置）
  Future<void> _jumpToSentence(int index) async {
    _atomicReset();

    final sentence = _sentences[index];
    state = state.copyWith(
      phase: const Idle(),
      sentenceIndex: index,
      repeatIndex: 0,
      totalRepeats: _config.getRepeatCount(sentence),
      intervalDuration: _config.getIntervalDuration(sentence),
      recordingPath: null,
      recordingScore: null,
      flowToken: state.flowToken + 1,
    );

    await _playCurrentSentence();
  }

  /// 原子重置：停止所有资源 + 递增 token
  void _atomicReset() {
    _stopActiveResources();
    state = state.copyWith(flowToken: state.flowToken + 1);
  }

  /// 停止正在进行的活动（播放/倒计时/录音），保留已有评估结果。
  void _stopActiveResources() {
    ref.read(audioEngineProvider.notifier).pause();
    _countdown.cancel();
    final recController = ref.read(speechRecordingControllerProvider.notifier);
    recController.cancelActiveRecording();
    // 不调 clearRecording()：保留已有评分 badge 和匹配高亮。
    // 录音数据由 Screen 在导航操作（切句/重播）前显式清除。
    _playbackService.stop();
  }

  /// 当前句子
  Sentence? get _currentSentence =>
      _sentences.isNotEmpty && state.sentenceIndex < _sentences.length
      ? _sentences[state.sentenceIndex]
      : null;
}
