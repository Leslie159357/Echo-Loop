/// 跟读播放器页面
///
/// 难句跟读界面，逐句显示难句文本（带★标记），
/// 用户听完后在停顿时间内跟读。
///
/// 流程控制通过 [ListenAndRepeatController] 驱动（统一管理播放、录音、倒计时）。
/// 录音 UI 状态通过 [SpeechRecordingController] 读取（转录文本、评估结果）。
///
/// 完成处理：所有句子播完 → 完成对话框 → completeCurrentSubStage → 退出
/// 退出处理：PopScope → 保存断点 → exitLearningMode → pop
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../router/app_router.dart';
import '../database/enums.dart';
import '../utils/wakelock_mixin.dart';
import '../l10n/app_localizations.dart';
import '../providers/learning_progress_provider.dart';
import '../models/speech_practice_models.dart';
import '../providers/speech/speech_recording_controller.dart';
import '../providers/listen_and_repeat/listen_and_repeat_controller.dart';
import '../providers/listen_and_repeat/listen_and_repeat_phase.dart';
import '../providers/listen_and_repeat/listen_and_repeat_settings_provider.dart';
import '../providers/listen_and_repeat/listen_and_repeat_session_state.dart';
import '../services/app_logger.dart';
import '../theme/app_theme.dart';
import '../providers/sentence_ai_provider.dart';
import '../widgets/common/bookmark_toggle_row.dart';
import '../widgets/common/countdown_chip.dart';
import '../widgets/listen_and_repeat/listen_and_repeat_settings_sheet.dart';
import '../widgets/common/recording_button.dart'
    show RecordingButton, RecordingButtonMode;
import '../widgets/common/processing_indicator.dart';
import '../widgets/common/speech_rating_badge.dart';
import '../widgets/common/status_label.dart';
import '../widgets/dialogs/free_play_complete_dialog.dart';
import '../widgets/dialogs/step_complete_dialog.dart';
import '../widgets/review/review_briefing_sheet.dart';
import '../widgets/player_hotkey_scope.dart';
import '../widgets/practice/annotation_content_view.dart';
import '../widgets/common/repeat_practice_panel.dart';
import '../widgets/practice/practice_progress_section.dart';

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
    // Controller.initialize() 已在路由跳转前准备好数据，
    // 进入页面后开始播放。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(listenAndRepeatControllerProvider.notifier).startPlaying();
    });
  }

  /// 处理退出（close 按钮 / 系统返回）
  Future<void> _handleExit() async {
    _isExiting = true;
    final ctrl = ref.read(listenAndRepeatControllerProvider.notifier);
    ctrl.enterWaitingForUser();
    if (!mounted) return;

    final ctrlState = ref.read(listenAndRepeatControllerProvider);
    if (ctrlState.isFreePlay) {
      await ctrl.saveBreakpoint(isFreePlay: true);
      await ctrl.exitLearningMode();
      if (mounted) context.pop();
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

    await ctrl.saveBreakpoint(isFreePlay: false);
    await ctrl.exitLearningMode();
    if (mounted) context.pop();
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

    final ctrl = ref.read(listenAndRepeatControllerProvider.notifier);
    final ctrlState = ref.read(listenAndRepeatControllerProvider);

    if (!mounted) return;

    // 递增遍数统计
    await ctrl.incrementPassCount();

    if (!mounted) return;

    // 自由练习模式
    if (ctrlState.isFreePlay) {
      final l10n = AppLocalizations.of(context)!;
      await handleFreePlayComplete(
        context: context,
        title: l10n.listenAndRepeatCompleteTitle,
        message: l10n.listenAndRepeatCompleteMessage(ctrlState.totalSentences),
        onStudyAgain: () async {
          // 重新开始（从第一句，复用当前 config）
          await ctrl.prepareSession(
            sentences: ctrl.sentences,
            config: ctrl.config,
            startIndex: 0,
            isFreePlay: true,
          );
          await ctrl.startPlaying();
        },
        onExit: () async {
          await ctrl.clearBreakpoint(isFreePlay: true);
          await ctrl.exitLearningMode();
          if (mounted) context.pop();
        },
      );
      _isShowingDialog = false;
      return;
    }

    // 正式学习模式
    final stepCtx = _getStepContext();
    if (!mounted) return;

    final l10n = AppLocalizations.of(context)!;
    final result = await showStepCompleteDialog(
      context: context,
      title: l10n.listenAndRepeatCompleteTitle,
      contentBody: Text(
        l10n.listenAndRepeatCompleteMessage(ctrlState.totalSentences),
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

    // 清除断点 + 标记完成
    await ctrl.clearBreakpoint(isFreePlay: false);
    await ctrl.completeSubStage();
    await ctrl.exitLearningMode();
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

  /// 构建中间区域内容（倒计时 / 录音按钮+状态标签 / 加载动画）
  Widget _buildCenterContent({
    required bool showCountdown,
    required bool isInPause,
    required SpeechRecordingState turnState,
    required String currentPromptId,
    required bool isRecordingCurrent,
    required SpeechPracticeAttempt? currentAttempt,
    required AppLocalizations l10n,
  }) {
    if (showCountdown) {
      return Center(
        child: Consumer(
          builder: (context, ref, _) {
            final phase = ref.watch(
              listenAndRepeatControllerProvider.select((s) => s.phase),
            );
            if (phase is! WaitingInterval) {
              return const SizedBox.shrink();
            }
            final ctrl = ref.read(listenAndRepeatControllerProvider.notifier);
            return CountdownChip(
              remaining: phase.remaining,
              total: phase.total,
              isPaused: phase.isPaused,
              onPause: ctrl.pauseInterval,
              onResume: ctrl.resumeInterval,
            );
          },
        ),
      );
    }

    if (isInPause) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.m),
        child: Builder(
          builder: (context) {
            final isProcessing =
                turnState.promptId == currentPromptId &&
                turnState.phase == SpeechRecordingPhase.processing;

            if (isProcessing) {
              return ProcessingIndicator(text: l10n.listenAndRepeatAnalyzing);
            }

            final mode = isRecordingCurrent
                ? switch (turnState.phase) {
                    SpeechRecordingPhase.awaitingSpeech ||
                    SpeechRecordingPhase.speaking =>
                      RecordingButtonMode.recording,
                    _ => RecordingButtonMode.idle,
                  }
                : RecordingButtonMode.idle;

            final hasError = currentAttempt?.errorMessage != null;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StatusLabel(
                  text: hasError
                      ? currentAttempt!.errorMessage
                      : switch (mode) {
                          RecordingButtonMode.idle =>
                            l10n.listenAndRepeatTapToRecord,
                          RecordingButtonMode.recording =>
                            l10n.listenAndRepeatRecordingInProgress,
                          RecordingButtonMode.disabled => null,
                        },
                  color: hasError ? Theme.of(context).colorScheme.error : null,
                  bold: hasError,
                ),
                const SizedBox(height: AppSpacing.xs),
                RecordingButton(
                  mode: mode,
                  onTap: () => ref
                      .read(listenAndRepeatControllerProvider.notifier)
                      .onRecordButtonTapped(),
                ),
              ],
            );
          },
        ),
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // 监听 ListenAndRepeatController 状态变化（避免倒计时 tick 重建整个页面）
    ref.watch(
      listenAndRepeatControllerProvider.select(
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
    final ctrlState = ref.read(listenAndRepeatControllerProvider);
    final ctrl = ref.read(listenAndRepeatControllerProvider.notifier);

    // watch 录音相关状态（仅监听 build 中实际使用的字段，避免转录更新触发重建）
    ref.watch(
      speechRecordingControllerProvider.select(
        (s) => (s.phase, s.currentAttempt, s.promptId),
      ),
    );
    final turnState = ref.read(speechRecordingControllerProvider);

    // 监听完成信号 → 触发完成弹窗
    ref.listen<ListenAndRepeatSessionState>(listenAndRepeatControllerProvider, (
      prev,
      next,
    ) {
      if (prev != null && !_isExiting) {
        if (next.phase is SessionCompleted && prev.phase is! SessionCompleted) {
          ref
              .read(listenAndRepeatControllerProvider.notifier)
              .pauseStudyTimer();
          shortenIdleTimeout(5);
          _handleCompleted();
        }
      }
    });

    final currentSentence = ctrl.currentSentence;
    final currentPromptId = ctrl.currentPromptId;
    final currentAttempt = turnState.currentAttempt;
    final isRecordingCurrent = turnState.isRecordingPrompt(currentPromptId);

    final isPlaying = ctrlState.phase is PlayingPrompt;
    final isInPause = ctrlState.isInPause;
    final showCountdown = ctrlState.isCountingDown;

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
            'L&R Screen',
            '播放按钮: phase=${ctrlState.phase.runtimeType}',
          );

          if (isInPause) {
            ref
                .read(speechRecordingControllerProvider.notifier)
                .clearRecording();
            ctrl.replayCurrentSentence();
          } else if (isPlaying) {
            ctrl.enterWaitingForUser();
          } else {
            ctrl.replayCurrentSentence();
          }
        },
        onPrevious: () {
          ref.read(speechRecordingControllerProvider.notifier).clearRecording();
          unawaited(ctrl.previousSentence());
        },
        onNext: () {
          ref.read(speechRecordingControllerProvider.notifier).clearRecording();
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
                  onPressed: () {
                    ref
                        .read(listenAndRepeatControllerProvider.notifier)
                        .enterWaitingForUser();
                    showListenAndRepeatSettingsSheet(context: context);
                  },
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
                                onTap: () => ref
                                    .read(
                                      listenAndRepeatControllerProvider
                                          .notifier,
                                    )
                                    .toggleCurrentBookmark(),
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
                                    ctrl.onUserInteraction();
                                  },
                                  onToolbarButtonTapped: () {
                                    AppLogger.log('L&R Screen', '工具栏点击: 打断流程');
                                    ctrl.onUserInteraction();
                                  },
                                ),
                              ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                ),

                // 底部区域：评分 + 录音/倒计时 + 播放控制 + 遍数
                RepeatPracticePanel(
                  l10n: l10n,
                  theme: theme,
                  ratingBadge:
                      (currentAttempt != null && currentAttempt.score != null)
                      ? SpeechRatingBadge(
                          l10n: l10n,
                          attempt: currentAttempt,
                          isPlaying: ctrlState.phase is ReviewingRecording,
                          onTap: currentAttempt.hasRecording
                              ? () => ref
                                    .read(
                                      listenAndRepeatControllerProvider
                                          .notifier,
                                    )
                                    .togglePlayback()
                              : null,
                        )
                      : null,
                  centerContent: _buildCenterContent(
                    showCountdown: showCountdown,
                    isInPause: isInPause,
                    turnState: turnState,
                    currentPromptId: currentPromptId,
                    isRecordingCurrent: isRecordingCurrent,
                    currentAttempt: currentAttempt,
                    l10n: l10n,
                  ),
                  fastForwardButton: showCountdown
                      ? Consumer(
                          builder: (context, ref, _) {
                            final phase = ref.watch(
                              listenAndRepeatControllerProvider.select(
                                (s) => s.phase,
                              ),
                            );
                            if (phase is! WaitingInterval || phase.isPaused) {
                              return const SizedBox.shrink();
                            }
                            return GestureDetector(
                              onTap: ref
                                  .read(
                                    listenAndRepeatControllerProvider.notifier,
                                  )
                                  .fastForwardInterval,
                              child: Icon(
                                Icons.fast_forward_rounded,
                                size: 32,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            );
                          },
                        )
                      : null,
                  canGoPrev: !ctrlState.isFirstSentence,
                  isLast: ctrlState.isLastSentence,
                  centerIcon: isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  onPrevious: () {
                    ref
                        .read(speechRecordingControllerProvider.notifier)
                        .clearRecording();
                    unawaited(ctrl.previousSentence());
                  },
                  onNext: () {
                    ref
                        .read(speechRecordingControllerProvider.notifier)
                        .clearRecording();
                    if (ctrlState.isLastSentence) {
                      ctrl.stopSession();
                      _handleCompleted();
                    } else {
                      unawaited(ctrl.nextSentence());
                    }
                  },
                  onCenter: () {
                    if (isInPause) {
                      ref
                          .read(speechRecordingControllerProvider.notifier)
                          .clearRecording();
                      ctrl.replayCurrentSentence();
                    } else if (isPlaying) {
                      ctrl.enterWaitingForUser();
                    } else {
                      ctrl.replayCurrentSentence();
                    }
                  },
                  isManualMode: ref
                      .read(listenAndRepeatSettingsProvider)
                      .isManualMode,
                  playCountText: l10n.listenAndRepeatPlayCount(
                    ctrlState.repeatIndex + 1,
                    ctrlState.totalRepeats,
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
