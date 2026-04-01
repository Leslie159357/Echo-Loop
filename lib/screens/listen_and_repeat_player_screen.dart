/// 跟读播放器页面
///
/// 难句跟读界面，逐句显示难句文本（带★标记），
/// 用户听完后在停顿时间内跟读。
///
/// 流程控制通过 [ShadowingController] 驱动（统一管理播放、录音、倒计时）。
/// 录音 UI 状态通过 [ShadowingRecordingController] 读取（转录文本、评估结果）。
///
/// 完成处理：所有句子播完 → 完成对话框 → completeCurrentSubStage → 退出
/// 退出处理：PopScope → 保存断点 → exitLearningMode → pop
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../router/app_router.dart';
import '../database/enums.dart';
import '../database/providers.dart';
import '../models/intensive_listen_settings.dart';
import '../utils/wakelock_mixin.dart';
import '../l10n/app_localizations.dart';
import '../providers/learning_progress_provider.dart';
import '../providers/learning_session/learning_session_provider.dart';
import '../providers/learning_session/listen_and_repeat_player_provider.dart';
import '../providers/listening_practice/bookmark_manager.dart';
import '../providers/listen_and_repeat_turn_controller_provider.dart';
import '../providers/shadowing/shadowing_controller.dart';
import '../providers/shadowing/shadowing_phase.dart';
import '../providers/shadowing/shadowing_session_state.dart';
import '../services/app_logger.dart';
import '../theme/app_theme.dart';
import '../providers/sentence_ai_provider.dart';
import '../widgets/common/bookmark_toggle_row.dart';
import '../widgets/common/countdown_chip.dart';
import '../widgets/listen_and_repeat/listen_and_repeat_settings_sheet.dart';
import '../widgets/listen_and_repeat/speech_practice_turn_panel.dart';
import '../widgets/common/speech_rating_badge.dart';
import '../widgets/dialogs/free_play_complete_dialog.dart';
import '../widgets/dialogs/step_complete_dialog.dart';
import '../widgets/review/review_briefing_sheet.dart';
import '../widgets/player_hotkey_scope.dart';
import '../widgets/practice/annotation_content_view.dart';
import '../widgets/common/playback_controls.dart';
import '../widgets/practice/practice_play_count_label.dart';
import '../widgets/practice/practice_progress_section.dart';

/// 录音/倒计时区域固定高度（录音面板最高：24 状态 + 4 间距 + 56 按钮 + 16 底部 = 100）
const double _kTurnAreaHeight = 100;

/// 跟读播放器页面
class ListenAndRepeatPlayerScreen extends ConsumerStatefulWidget {
  /// 合集 ID（用于返回导航，从独立音频路由进入时为 null）
  final String? collectionId;

  /// 音频项 ID
  final String audioItemId;

  const ListenAndRepeatPlayerScreen({
    super.key,
    this.collectionId,
    required this.audioItemId,
  });

  @override
  ConsumerState<ListenAndRepeatPlayerScreen> createState() =>
      _ListenAndRepeatPlayerScreenState();
}

class _ListenAndRepeatPlayerScreenState
    extends ConsumerState<ListenAndRepeatPlayerScreen>
    with WakelockMixin {
  /// 是否正在退出页面，防止退出过程中 listener 触发弹窗
  bool _isExiting = false;

  /// 是否正在显示完成弹窗，防止重复弹窗
  bool _isShowingDialog = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 从旧 Player 读取初始化数据（句子列表、起始索引、设置）
      final player = ref.read(listenAndRepeatPlayerProvider.notifier);
      final playerState = ref.read(listenAndRepeatPlayerProvider);
      final ctrl = ref.read(shadowingControllerProvider.notifier);

      ctrl.startSession(
        sentences: player.sentences,
        config: ShadowingConfig(
          audioItemId: widget.audioItemId,
          getRepeatCount: (_) => playerState.settings.repeatCount,
          getIntervalDuration: (s) => _calculateInterval(
            s.duration,
            playerState.settings,
          ),
          isManualMode: () =>
              ref.read(listenAndRepeatPlayerProvider).settings.isManualMode,
        ),
        startIndex: playerState.currentSentenceIndex,
      );
    });
  }

  // No resources to dispose — ShadowingController manages playback/recording.

  /// 根据设置计算停顿时长
  Duration _calculateInterval(
    Duration sentenceDuration,
    IntensiveListenSettings settings,
  ) {
    return switch (settings.pauseMode) {
      PauseMode.smart => Duration(
          milliseconds: math.max(sentenceDuration.inMilliseconds * 2, 2000),
        ),
      PauseMode.fixed => Duration(seconds: settings.fixedPauseSeconds),
      PauseMode.multiplier => Duration(
          milliseconds: math.max(
            (sentenceDuration.inMilliseconds * settings.pauseMultiplier)
                .round(),
            1000,
          ),
        ),
    };
  }

  /// 构造当前句子的 promptId（用于匹配录音状态）
  String _currentPromptId(ShadowingSessionState ctrlState) {
    final ctrl = ref.read(shadowingControllerProvider.notifier);
    final sentence = ctrl.currentSentence;
    final sentenceIndex = sentence?.index ?? ctrlState.sentenceIndex;
    return 'shadowing:${widget.audioItemId}:$sentenceIndex';
  }

  /// 处理录音按钮点击
  Future<void> _handleRecordTap() async {
    final ctrlState = ref.read(shadowingControllerProvider);
    if (ctrlState.phase is! WaitingInterval) return;

    final ctrl = ref.read(shadowingControllerProvider.notifier);
    final recState = ref.read(shadowingRecordingControllerProvider);
    final currentSentence = ctrl.currentSentence;
    if (currentSentence == null) return;

    final promptId = _currentPromptId(ctrlState);
    if (recState.isRecordingPrompt(promptId)) {
      AppLogger.log('ShadowScreen', '手动停止录音 → 评估');
      await ctrl.stopRecording();
      return;
    }

    // 停止录音回放（如果正在播放）
    await ctrl.stopPlayback();

    AppLogger.log(
      'ShadowScreen',
      '手动开始录音: 句子${ctrlState.sentenceIndex + 1}',
    );
    ctrl.startManualRecording();
  }

  /// 处理录音回放按钮点击
  Future<void> _handleAttemptPlaybackTap() async {
    final ctrlState = ref.read(shadowingControllerProvider);
    final ctrl = ref.read(shadowingControllerProvider.notifier);

    if (ctrlState.phase is ReviewingRecording) {
      await ctrl.stopPlayback();
      return;
    }

    await ctrl.playRecording();
  }

  /// 取消录音和回放
  Future<void> _cancelRecordingAndPlayback() async {
    await ref
        .read(shadowingRecordingControllerProvider.notifier)
        .cancelActiveRecording();
    await ref
        .read(shadowingControllerProvider.notifier)
        .stopPlayback();
  }

  /// 处理退出（close 按钮 / 系统返回）
  Future<void> _handleExit() async {
    _isExiting = true;
    await _cancelRecordingAndPlayback();
    final ctrl = ref.read(shadowingControllerProvider.notifier);
    ctrl.pause();
    if (!mounted) return;

    final session = ref.read(learningSessionProvider);
    if (session.isFreePlay) {
      await _saveSentenceProgress(isFreePlay: true);
      await _exit();
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.exitListenAndRepeatTitle),
        content: Text(l10n.exitListenAndRepeatMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.confirmExit),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) {
      _isExiting = false;
      return;
    }

    // 保存断点
    await _saveSentenceProgress(isFreePlay: false);
    await _exit();
  }

  /// 执行退出
  Future<void> _exit() async {
    _isExiting = true;
    ref.read(shadowingControllerProvider.notifier).disposeSession();
    await ref.read(learningSessionProvider.notifier).exitLearningMode();
    if (mounted) context.pop();
  }

  /// 保存跟读断点进度
  Future<void> _saveSentenceProgress({required bool isFreePlay}) async {
    final ctrl = ref.read(shadowingControllerProvider.notifier);
    await ref
        .read(learningProgressNotifierProvider.notifier)
        .saveShadowingSentenceIndex(
          widget.audioItemId,
          ctrl.currentIndex,
          isFreePlay: isFreePlay,
        );
  }

  /// 切换当前句子的难句标记
  Future<void> _handleToggleDifficult() async {
    final ctrl = ref.read(shadowingControllerProvider.notifier);
    final sentence = ctrl.currentSentence;
    if (sentence == null) return;

    final isCurrentlyBookmarked = sentence.isBookmarked;
    ctrl.toggleCurrentBookmark();

    final bookmarkDao = ref.read(bookmarkDaoProvider);
    if (isCurrentlyBookmarked) {
      await bookmarkDao.removeBookmark(widget.audioItemId, sentence.index);
    } else {
      await BookmarkManager.addBookmarkToDb(
        widget.audioItemId,
        sentence,
        dao: bookmarkDao,
      );
    }
  }

  /// 获取当前步骤的上下文信息
  ({
    int stepIndex,
    int totalSteps,
    String stageName,
    String? nextStepName,
    bool isLastStep,
  })
  _getStepContext() {
    final l10n = AppLocalizations.of(context)!;
    final progress = ref
        .read(learningProgressNotifierProvider)
        .progressMap[widget.audioItemId];

    if (progress == null) {
      final subStages = LearningStage.firstLearn.subStages;
      final idx = subStages.indexOf(SubStageType.listenAndRepeat);
      final isLast = idx >= subStages.length - 1;
      String? nextName;
      if (!isLast) {
        final next = subStages[idx + 1];
        if (_hasPlayerScreen(next)) {
          nextName = _getSubStageName(next, l10n);
        }
      }
      return (
        stepIndex: idx,
        totalSteps: subStages.length,
        stageName: reviewStageLabel(l10n, LearningStage.firstLearn),
        nextStepName: nextName,
        isLastStep: isLast,
      );
    }

    final stage = progress.currentStage;
    final subStages = stage.subStages;
    final currentIdx = subStages.indexOf(progress.currentSubStage);
    final isLast = currentIdx >= subStages.length - 1;

    String? nextStepName;
    if (!isLast) {
      final nextSubStage = subStages[currentIdx + 1];
      if (_hasPlayerScreen(nextSubStage)) {
        nextStepName = _getSubStageName(nextSubStage, l10n);
      }
    }

    return (
      stepIndex: currentIdx,
      totalSteps: subStages.length,
      stageName: reviewStageLabel(l10n, stage),
      nextStepName: nextStepName,
      isLastStep: isLast,
    );
  }

  /// 处理播放完成
  Future<void> _handleCompleted() async {
    if (_isShowingDialog || _isExiting || !mounted) return;
    _isShowingDialog = true;

    final session = ref.read(learningSessionProvider);
    final ctrlState = ref.read(shadowingControllerProvider);

    if (!mounted) return;

    // 自由练习模式：弹窗询问"完成"或"再来一遍"
    if (session.isFreePlay) {
      final l10n = AppLocalizations.of(context)!;
      // 弹窗前递增遍数
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .incrementShadowingPassCount(widget.audioItemId);

      if (!mounted) return;

      await handleFreePlayComplete(
        context: context,
        title: l10n.listenAndRepeatCompleteTitle,
        message: l10n.listenAndRepeatCompleteMessage(
          ctrlState.totalSentences,
        ),
        onStudyAgain: () async {
          final ctrl = ref.read(shadowingControllerProvider.notifier);
          final player = ref.read(listenAndRepeatPlayerProvider.notifier);
          final playerState = ref.read(listenAndRepeatPlayerProvider);
          // 重新开始会话
          await ctrl.startSession(
            sentences: player.sentences,
            config: ShadowingConfig(
              audioItemId: widget.audioItemId,
              getRepeatCount: (_) => playerState.settings.repeatCount,
              getIntervalDuration: (s) => _calculateInterval(
                s.duration,
                playerState.settings,
              ),
              isManualMode: () => ref
                  .read(listenAndRepeatPlayerProvider)
                  .settings
                  .isManualMode,
            ),
            startIndex: 0,
          );
        },
        onExit: () async {
          await ref
              .read(learningProgressNotifierProvider.notifier)
              .saveShadowingSentenceIndex(
                widget.audioItemId,
                null,
                isFreePlay: true,
              );
          await _exit();
        },
      );
      _isShowingDialog = false;
      return;
    }

    final stepCtx = _getStepContext();

    // 弹窗前保存统计（事实记录，不影响步骤进度）
    try {
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .incrementShadowingPassCount(widget.audioItemId);
    } catch (e) {
      debugPrint('跟读保存统计出错: $e');
    }

    if (!mounted) return;

    final l10nStep = AppLocalizations.of(context)!;
    final result = await showStepCompleteDialog(
      context: context,
      title: l10nStep.listenAndRepeatCompleteTitle,
      contentBody: Text(
        l10nStep.listenAndRepeatCompleteMessage(ctrlState.totalSentences),
      ),
      stepIndex: stepCtx.stepIndex,
      totalSteps: stepCtx.totalSteps,
      stageName: stepCtx.stageName,
      nextStepName: stepCtx.nextStepName,
      isLastStep: stepCtx.isLastStep,
    );

    if (!mounted || result == null) {
      _isShowingDialog = false;
      return;
    }

    // 用户确认后：清除断点 + 标记完成
    try {
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .saveShadowingSentenceIndex(
            widget.audioItemId,
            null,
            isFreePlay: false,
          );
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .completeCurrentSubStage(widget.audioItemId);
    } catch (e) {
      debugPrint('跟读完成处理出错: $e');
    }

    ref.read(shadowingControllerProvider.notifier).disposeSession();
    await ref.read(learningSessionProvider.notifier).exitLearningMode();
    if (!mounted) return;

    if (result.action == StepCompleteAction.continueNext) {
      _navigateBackToPlanAndAutoStart();
    } else {
      context.pop();
    }
  }

  /// 返回学习计划页并自动启动下一个任务
  ///
  /// 先 go 回学习 Tab 清空导航栈，再 push 新的学习计划页（autoStart=true），
  /// 效果等同于用户在学习列表点击"继续学习"。
  void _navigateBackToPlanAndAutoStart() {
    if (!mounted) return;
    final route = widget.collectionId != null
        ? AppRoutes.learningPlan(
            widget.collectionId!,
            widget.audioItemId,
            autoStart: true,
          )
        : AppRoutes.audioLearningPlan(widget.audioItemId, autoStart: true);
    GoRouter.of(context).go(AppRoutes.study);
    GoRouter.of(context).push(route);
  }

  /// 判断当前是否处于"等待用户操作"的停顿状态
  ///
  /// 包含 WaitingInterval（录音前/后）和 ShadowingRecording（录音中）。
  bool _isInPauseState(ShadowingPhase phase) {
    return phase is WaitingInterval || phase is ShadowingRecording;
  }

  /// 判断是否应显示倒计时芯片
  ///
  /// 仅在自动模式、倒计时中、录音已完成时显示。
  bool _shouldShowCountdown(ShadowingSessionState ctrlState) {
    if (ctrlState.phase is! WaitingInterval) return false;
    final settings = ref.read(listenAndRepeatPlayerProvider).settings;
    if (settings.isManualMode) return false;
    // 有录音评分 = 录音已完成，正在 review 倒计时
    return ctrlState.recordingScore != null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // 监听 ShadowingController 状态变化（避免倒计时 tick 重建整个页面）
    ref.watch(
      shadowingControllerProvider.select(
        (s) => (
          s.sentenceIndex,
          s.totalSentences,
          s.repeatIndex,
          s.totalRepeats,
          s.phase.runtimeType,
          s.recordingScore,
          s.flowToken,
        ),
      ),
    );
    final ctrlState = ref.read(shadowingControllerProvider);
    final ctrl = ref.read(shadowingControllerProvider.notifier);

    // 监听旧 Player 的设置变化（设置面板仍写入旧 Player）
    ref.watch(
      listenAndRepeatPlayerProvider.select((s) => s.settings),
    );
    final settings = ref.read(listenAndRepeatPlayerProvider).settings;

    // watch 录音相关状态（仅监听 build 中实际使用的字段，避免转录更新触发重建）
    ref.watch(
      shadowingRecordingControllerProvider.select(
        (s) => (s.phase, s.currentAttempt, s.promptId),
      ),
    );
    final turnState = ref.read(shadowingRecordingControllerProvider);

    // 监听完成信号 → 触发完成弹窗
    ref.listen<ShadowingSessionState>(shadowingControllerProvider, (
      prev,
      next,
    ) {
      if (prev != null && !_isExiting) {
        if (next.phase is SessionCompleted && prev.phase is! SessionCompleted) {
          ref.read(learningSessionProvider.notifier).pauseStudyTimer();
          shortenIdleTimeout(5);
          _handleCompleted();
        }
      }
    });

    final currentSentence = ctrl.currentSentence;
    final currentPromptId = _currentPromptId(ctrlState);
    final currentAttempt = turnState.currentAttempt;
    final isRecordingCurrent = turnState.isRecordingPrompt(currentPromptId);

    final isPlaying = ctrlState.phase is PlayingPrompt;
    final isInPause = _isInPauseState(ctrlState.phase);
    final showCountdown = _shouldShowCountdown(ctrlState);

    // 句子时长（如 "2.8秒"）
    final hasDuration =
        currentSentence != null && currentSentence.duration > Duration.zero;
    final durationText = hasDuration
        ? l10n.sentenceDuration(
            (currentSentence.duration.inMilliseconds / 1000.0).toStringAsFixed(
              1,
            ),
          )
        : null;

    return wakelockBody(
      child: LearningHotkeyScope(
        onPlayPause: () {
          AppLogger.log(
            'ShadowScreen',
            '播放按钮: phase=${ctrlState.phase.runtimeType}',
          );
          unawaited(_cancelRecordingAndPlayback());
          if (isInPause) {
            ref
                .read(shadowingRecordingControllerProvider.notifier)
                .clearRecording();
            ctrl.replayCurrentSentence();
          } else if (isPlaying) {
            ctrl.pause();
          } else {
            ctrl.resume();
          }
        },
        onPrevious: () {
          unawaited(_cancelRecordingAndPlayback());
          ref
              .read(shadowingRecordingControllerProvider.notifier)
              .clearRecording();
          unawaited(ctrl.previousSentence());
        },
        onNext: () {
          unawaited(_cancelRecordingAndPlayback());
          ref
              .read(shadowingRecordingControllerProvider.notifier)
              .clearRecording();
          unawaited(ctrl.nextSentence());
        },
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            _handleExit();
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(l10n.listenAndRepeatAppBarTitle),
              centerTitle: true,
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: _handleExit,
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.tune),
                  onPressed: () =>
                      showListenAndRepeatSettingsSheet(context: context),
                ),
              ],
            ),
            body: Column(
              children: [
                // 进度条
                PracticeProgressSection(
                  current: ctrlState.sentenceIndex + 1,
                  total: ctrlState.totalSentences,
                  progressText: l10n.listenAndRepeatProgress(
                    ctrlState.sentenceIndex + 1,
                    ctrlState.totalSentences,
                  ),
                  durationText: durationText,
                ),

                // 主体内容：书签行 + 标注内容
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.l,
                    ),
                    child: currentSentence != null
                        ? Column(
                            children: [
                              const SizedBox(height: AppSpacing.s),
                              BookmarkToggleRow(
                                isDifficult: currentSentence.isBookmarked,
                                onTap: _handleToggleDifficult,
                              ),
                              const SizedBox(height: AppSpacing.m),
                              Expanded(
                                child: AnnotationContentView(
                                  text: currentSentence.text,
                                  aiNotifier: ref.read(
                                    sentenceAiNotifierProvider,
                                  ),
                                  audioItemId: widget.audioItemId,
                                  sentenceIndex: ctrlState.sentenceIndex,
                                  sentenceStartMs:
                                      currentSentence.startTime.inMilliseconds,
                                  sentenceEndMs:
                                      currentSentence.endTime.inMilliseconds,
                                  highlightedSegments:
                                      currentAttempt?.referenceSegments,
                                  onStopMainPlayer: () {
                                    ctrl.openLookup();
                                  },
                                  onToolbarButtonTapped: () {
                                    AppLogger.log(
                                      'ShadowScreen',
                                      '工具栏点击: 打断流程',
                                    );
                                    ctrl.openLookup();
                                  },
                                ),
                              ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                ),

                // 底部区域：录音/提示 + 播放控制 + 遍数
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppSpacing.l,
                    right: AppSpacing.l,
                    bottom: AppSpacing.m,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 评级 badge（点击播放录音），和复述页面同位置
                      if (currentAttempt != null &&
                          currentAttempt.score != null)
                        Padding(
                          padding: const EdgeInsets.only(
                            top: AppSpacing.s,
                            bottom: AppSpacing.xs,
                          ),
                          child: Center(
                            child: SpeechRatingBadge(
                              l10n: l10n,
                              attempt: currentAttempt,
                              isPlaying:
                                  ctrlState.phase is ReviewingRecording,
                              onTap: currentAttempt.hasRecording
                                  ? () => _handleAttemptPlaybackTap()
                                  : null,
                            ),
                          ),
                        ),
                      // 评估后倒计时 / 录音面板
                      // 固定高度，避免倒计时消失后 badge 位置跳动
                      SizedBox(
                        height: _kTurnAreaHeight,
                        child: showCountdown
                            ? Center(
                                child: Consumer(
                                  builder: (context, ref, _) {
                                    final s = ref.watch(
                                      shadowingControllerProvider.select(
                                        (s) => (
                                          s.intervalRemaining,
                                          s.intervalTotal,
                                        ),
                                      ),
                                    );
                                    final remaining = s.$1;
                                    final total = s.$2;
                                    return CountdownChip(
                                      remaining: remaining,
                                      total: total,
                                      isPaused: false,
                                      onTap: () =>
                                          ref
                                              .read(
                                                shadowingControllerProvider
                                                    .notifier,
                                              )
                                              .pauseInterval(),
                                      onFastForward: () =>
                                          ref
                                              .read(
                                                shadowingControllerProvider
                                                    .notifier,
                                              )
                                              .fastForwardInterval(),
                                    );
                                  },
                                ),
                              )
                            : isInPause
                                ? Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: AppSpacing.m,
                                    ),
                                    child: SpeechPracticeTurnPanel(
                                      l10n: l10n,
                                      turnState: turnState,
                                      isRecordingCurrent: isRecordingCurrent,
                                      onRecordTap: _handleRecordTap,
                                      currentAttempt: currentAttempt,
                                    ),
                                  )
                                : const SizedBox.shrink(),
                      ),
                      // 播放控制
                      PlaybackControls(
                        canGoPrev: !ctrlState.isFirstSentence,
                        isLast: ctrlState.isLastSentence,
                        centerIcon: isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        onPrevious: () {
                          unawaited(_cancelRecordingAndPlayback());
                          ref
                              .read(
                                shadowingRecordingControllerProvider.notifier,
                              )
                              .clearRecording();
                          unawaited(ctrl.previousSentence());
                        },
                        onNext: () {
                          unawaited(_cancelRecordingAndPlayback());
                          ref
                              .read(
                                shadowingRecordingControllerProvider.notifier,
                              )
                              .clearRecording();
                          if (ctrlState.isLastSentence) {
                            // 最后一句：停止播放，直接弹窗
                            ctrl.stopSession();
                            _handleCompleted();
                          } else {
                            unawaited(ctrl.nextSentence());
                          }
                        },
                        onCenter: () {
                          unawaited(_cancelRecordingAndPlayback());
                          if (isInPause) {
                            ref
                                .read(
                                  shadowingRecordingControllerProvider.notifier,
                                )
                                .clearRecording();
                            ctrl.replayCurrentSentence();
                          } else if (isPlaying) {
                            ctrl.pause();
                          } else {
                            ctrl.resume();
                          }
                        },
                      ),
                      // 遍数 + 模式指示器
                      PracticePlayCountLabel(
                        isManualMode: settings.isManualMode,
                        playCountText: l10n.listenAndRepeatPlayCount(
                          ctrlState.repeatIndex + 1,
                          ctrlState.totalRepeats,
                        ),
                        l10n: l10n,
                        theme: theme,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 判断子步骤是否有专用播放器页面
bool _hasPlayerScreen(SubStageType type) => switch (type) {
  SubStageType.blindListen => true,
  SubStageType.intensiveListen => true,
  SubStageType.listenAndRepeat => true,
  SubStageType.retell => true,
  SubStageType.reviewDifficultPractice => true,
  SubStageType.reviewRetellParagraph => true,
  SubStageType.reviewRetellSummary => true,
};

/// 获取子步骤的本地化名称
String _getSubStageName(SubStageType type, AppLocalizations l10n) =>
    switch (type) {
      SubStageType.blindListen => l10n.stepBlindListening,
      SubStageType.intensiveListen => l10n.stepIntensiveListening,
      SubStageType.listenAndRepeat => l10n.stepShadowing,
      SubStageType.retell => l10n.stepRetelling,
      SubStageType.reviewDifficultPractice => l10n.reviewDifficultPracticeTitle,
      SubStageType.reviewRetellParagraph => l10n.stepRetelling,
      SubStageType.reviewRetellSummary => l10n.stepRetelling,
    };
