/// 复习难句补练页面
///
/// 仅加载已标记为难句的句子，逐句执行：
/// 1. 盲听一遍（不显示字幕）
/// 2. 句间停顿 → 自动推进下一句
/// 3. 用户可随时「偷看」字幕或按「听不懂」进入标注模式
/// 4. 标注模式：暂停 + 揭示文本 → "继续" → 带字幕重播 → 自动推进
///
/// 交互与逐句精听页面（IntensiveListenPlayerScreen）一致。
/// R1+ 可取消难句标记（听懂的句子 unbookmark）。
/// 完成后弹完成对话框，支持"继续下一步"或"返回计划"。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../database/providers.dart';
import '../l10n/app_localizations.dart';
import '../providers/learning_progress_provider.dart';
import '../providers/learning_session/learning_session_provider.dart';
import '../providers/learning_session/review_difficult_practice_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/intensive_listen/sentence_annotation_card.dart';

/// 复习难句补练页面
class ReviewDifficultPracticeScreen extends ConsumerStatefulWidget {
  /// 合集 ID（独立音频路由时为 null）
  final String? collectionId;

  /// 音频项 ID
  final String audioItemId;

  const ReviewDifficultPracticeScreen({
    super.key,
    this.collectionId,
    required this.audioItemId,
  });

  @override
  ConsumerState<ReviewDifficultPracticeScreen> createState() =>
      _ReviewDifficultPracticeScreenState();
}

class _ReviewDifficultPracticeScreenState
    extends ConsumerState<ReviewDifficultPracticeScreen> {
  bool _isShowingDialog = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(reviewDifficultPracticeProvider.notifier).startPlaying();
    });
  }

  /// 处理退出
  Future<void> _handleExit() async {
    final player = ref.read(reviewDifficultPracticeProvider.notifier);
    player.pause();
    if (!mounted) return;

    final l10n = AppLocalizations.of(context)!;
    final playerState = ref.read(reviewDifficultPracticeProvider);

    // 已完成直接退出
    if (playerState.isCompleted) {
      await _exit();
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.exitReviewDifficultPracticeTitle),
        content: Text(l10n.exitReviewDifficultPracticeMessage),
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
      // 取消退出 → 恢复播放（标注模式下不恢复）
      if (mounted) {
        final currentState = ref.read(reviewDifficultPracticeProvider);
        if (!currentState.isAnnotationMode) {
          player.resume();
        }
      }
      return;
    }

    await _exit();
  }

  /// 执行退出（保存断点后退出）
  Future<void> _exit() async {
    // 保存当前句子索引作为断点
    final player = ref.read(reviewDifficultPracticeProvider.notifier);
    await ref
        .read(learningProgressNotifierProvider.notifier)
        .saveDifficultPracticeSentenceIndex(
          widget.audioItemId,
          player.currentIndex,
        );

    await ref.read(learningSessionProvider.notifier).exitLearningMode();
    if (mounted) context.pop();
  }

  /// 取消当前句子的难句标记
  Future<void> _handleRemoveDifficult() async {
    final player = ref.read(reviewDifficultPracticeProvider.notifier);
    final removed = player.removeDifficultMark();

    if (removed != null) {
      final bookmarkDao = ref.read(bookmarkDaoProvider);
      await bookmarkDao.removeBookmark(widget.audioItemId, removed.index);
    }

    // 如果还有句子且未完成，自动开始播放下一句
    final playerState = ref.read(reviewDifficultPracticeProvider);
    if (!playerState.isCompleted && playerState.totalSentences > 0) {
      await player.startPlaying();
    }
  }

  /// 获取当前步骤上下文
  ({
    int stepIndex,
    int totalSteps,
    String stageName,
    String? nextStepName,
    bool isLastStep,
  })
  _getStepContext() {
    final progress = ref
        .read(learningProgressNotifierProvider)
        .progressMap[widget.audioItemId];

    if (progress == null) {
      return (
        stepIndex: 0,
        totalSteps: 1,
        stageName: '',
        nextStepName: null,
        isLastStep: true,
      );
    }

    final stage = progress.currentStage;
    final subStages = stage.subStages;
    final currentIdx = subStages.indexOf(progress.currentSubStage);
    final isLast = currentIdx >= subStages.length - 1;

    String? nextStepName;
    if (!isLast) {
      final nextSubStage = subStages[currentIdx + 1];
      nextStepName = nextSubStage.label;
    }

    return (
      stepIndex: currentIdx,
      totalSteps: subStages.length,
      stageName: stage.label,
      nextStepName: nextStepName,
      isLastStep: isLast,
    );
  }

  /// 处理完成
  Future<void> _handleCompleted() async {
    if (_isShowingDialog || !mounted) return;
    _isShowingDialog = true;

    final session = ref.read(learningSessionProvider);

    // 自由练习模式：直接退出，不弹完成对话框、不推进步骤
    if (session.isFreePlay) {
      // 清除断点（已全部完成）
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .saveDifficultPracticeSentenceIndex(widget.audioItemId, null);
      await ref.read(learningSessionProvider.notifier).exitLearningMode();
      _isShowingDialog = false;
      if (mounted) context.pop();
      return;
    }

    final playerState = ref.read(reviewDifficultPracticeProvider);
    final stepCtx = _getStepContext();

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _CompleteDialog(
        totalSentences: playerState.totalSentences,
        stepIndex: stepCtx.stepIndex,
        totalSteps: stepCtx.totalSteps,
        stageName: stepCtx.stageName,
        nextStepName: stepCtx.nextStepName,
        isLastStep: stepCtx.isLastStep,
      ),
    );

    _isShowingDialog = false;
    if (!mounted) return;

    if (result != null) {
      // 清除断点（已全部完成）并推进子步骤
      try {
        await ref
            .read(learningProgressNotifierProvider.notifier)
            .saveDifficultPracticeSentenceIndex(widget.audioItemId, null);
        await ref
            .read(learningProgressNotifierProvider.notifier)
            .completeCurrentSubStage(widget.audioItemId);
      } catch (e) {
        debugPrint('难句补练完成处理出错: $e');
      }

      if (result == true && stepCtx.nextStepName != null) {
        // 继续下一步 → 退出当前模式，返回计划页让路由分发
        await ref.read(learningSessionProvider.notifier).exitLearningMode();
        if (mounted) context.pop();
      } else {
        // 返回计划页
        await ref.read(learningSessionProvider.notifier).exitLearningMode();
        if (mounted) context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final playerState = ref.watch(reviewDifficultPracticeProvider);
    final player = ref.read(reviewDifficultPracticeProvider.notifier);

    // 监听完成状态
    ref.listen<ReviewDifficultPracticeState>(reviewDifficultPracticeProvider, (
      prev,
      next,
    ) {
      if (next.isCompleted && !(prev?.isCompleted ?? false)) {
        _handleCompleted();
      }
    });

    final currentSentence = player.currentSentence;

    // 句子时长和时间戳
    final hasDuration =
        currentSentence != null && currentSentence.duration > Duration.zero;
    final durationText = hasDuration
        ? l10n.sentenceDuration(
            (currentSentence.duration.inMilliseconds / 1000.0).toStringAsFixed(
              1,
            ),
          )
        : null;
    final timestampText = hasDuration
        ? '${_formatTimestamp(currentSentence.startTime)}'
              ' - ${_formatTimestamp(currentSentence.endTime)}'
        : null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleExit();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.reviewDifficultPracticeTitle),
          centerTitle: true,
        ),
        body: Column(
          children: [
            // 进度区域
            _ProgressSection(
              playerState: playerState,
              l10n: l10n,
              durationText: durationText,
              timestampText: timestampText,
            ),

            // 主体内容：三态切换
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: playerState.isAnnotationReplay
                    ? _AnnotationReplayView(
                        key: const ValueKey('replay'),
                        text: currentSentence?.text ?? '',
                        l10n: l10n,
                      )
                    : playerState.isAnnotationMode
                    ? _AnnotationModeView(
                        key: const ValueKey('annotation'),
                        text: currentSentence?.text ?? '',
                        l10n: l10n,
                        onContinue: () => player.exitAnnotationMode(),
                        onRemoveDifficult: _handleRemoveDifficult,
                      )
                    : _NormalModeView(
                        key: const ValueKey('normal'),
                        playerState: playerState,
                        l10n: l10n,
                        theme: theme,
                        onPeekStart: () => player.setTextRevealed(true),
                        onPeekEnd: () => player.setTextRevealed(false),
                        onCantUnderstand: () => player.enterAnnotationMode(),
                        onRemoveDifficult: _handleRemoveDifficult,
                        onPauseCountdown: () => playerState.isCountdownPaused
                            ? player.resumeCountdown()
                            : player.pauseCountdown(),
                        onFastForward: () =>
                            player.toggleCountdownFastForward(),
                        sentenceText: currentSentence?.text,
                      ),
              ),
            ),

            // 底部播放控制
            _PlaybackControls(
              playerState: playerState,
              onPrevious: () => player.goToPrevious(),
              onNext: () => player.goToNext(),
              onPlayPause: () {
                if (playerState.isAnnotationMode) {
                  player.replayInAnnotationMode();
                } else if (playerState.isPauseBetweenPlays) {
                  player.replayDuringCountdown();
                } else if (playerState.isPlaying) {
                  player.pause();
                } else {
                  player.resume();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// 顶部进度条区域
class _ProgressSection extends StatelessWidget {
  final ReviewDifficultPracticeState playerState;
  final AppLocalizations l10n;
  final String? durationText;
  final String? timestampText;

  const _ProgressSection({
    required this.playerState,
    required this.l10n,
    this.durationText,
    this.timestampText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = playerState.totalSentences;
    final current = playerState.currentSentenceIndex + 1;
    final progress = total > 0 ? current / total : 0.0;
    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final timestampStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.s,
      ),
      child: Column(
        children: [
          LinearProgressIndicator(
            value: progress,
            borderRadius: BorderRadius.circular(2),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Text(
                l10n.reviewDifficultPracticeProgress(current, total),
                style: subtitleStyle,
              ),
              const Spacer(),
              if (durationText case final dur?) Text(dur, style: subtitleStyle),
              if (timestampText case final ts?) ...[
                const SizedBox(width: 6),
                Text(ts, style: timestampStyle),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// 普通模式视图（文字遮盖 / 偷看）
class _NormalModeView extends StatelessWidget {
  final ReviewDifficultPracticeState playerState;
  final AppLocalizations l10n;
  final ThemeData theme;
  final VoidCallback onPeekStart;
  final VoidCallback onPeekEnd;
  final VoidCallback onCantUnderstand;
  final VoidCallback onRemoveDifficult;
  final VoidCallback onPauseCountdown;
  final VoidCallback onFastForward;
  final String? sentenceText;

  const _NormalModeView({
    super.key,
    required this.playerState,
    required this.l10n,
    required this.theme,
    required this.onPeekStart,
    required this.onPeekEnd,
    required this.onCantUnderstand,
    required this.onRemoveDifficult,
    required this.onPauseCountdown,
    required this.onFastForward,
    this.sentenceText,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 难句标记行（始终已标记，点击可取消）
          GestureDetector(
            onTap: onRemoveDifficult,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    l10n.intensiveListenMarkedDifficult,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.amber.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                const Icon(Icons.star, color: Colors.amber, size: 18),
              ],
            ),
          ),

          // 遮盖/偷看区域
          Expanded(
            child: Center(
              child: playerState.isTextRevealed && sentenceText != null
                  ? Text(
                      sentenceText!,
                      style: theme.textTheme.titleMedium?.copyWith(height: 1.6),
                      textAlign: TextAlign.center,
                    )
                  : _HiddenTextPlaceholder(),
            ),
          ),

          // 固定高度区域：盲听状态（播放中显示）+ 倒计时（倒计时期间显示）
          SizedBox(
            height: 80,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (playerState.isPlaying)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.headphones,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: AppSpacing.s),
                      Text(
                        l10n.reviewDifficultPracticeBlindListen,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                if (playerState.isPauseBetweenPlays)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: _PauseCountdownIndicator(
                      remaining: playerState.pauseRemaining,
                      total: playerState.pauseDuration,
                      l10n: l10n,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.l),

          // 固定高度的底部按钮区域，避免倒计时控制按钮出现时布局跳动
          SizedBox(
            height: 96,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // 倒计时控制按钮行（仅倒计时期间显示）
                if (playerState.isPauseBetweenPlays)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: onPauseCountdown,
                        icon: Icon(
                          playerState.isCountdownPaused
                              ? Icons.play_arrow
                              : Icons.pause,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.l),
                      IconButton(
                        onPressed: onFastForward,
                        icon: Icon(
                          Icons.fast_forward,
                          color: playerState.isCountdownFastForward
                              ? theme.colorScheme.primary
                              : null,
                        ),
                      ),
                    ],
                  ),

                if (playerState.isPauseBetweenPlays)
                  const SizedBox(height: AppSpacing.s),

                // 偷看/听不懂按钮（始终显示）
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Listener(
                      onPointerDown: (_) => onPeekStart(),
                      onPointerUp: (_) => onPeekEnd(),
                      onPointerCancel: (_) => onPeekEnd(),
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.visibility),
                        label: Text(l10n.intensiveListenPeek),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.m),
                    FilledButton.tonal(
                      onPressed: onCantUnderstand,
                      child: Text(l10n.intensiveListenCantUnderstand),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 隐藏文本占位（灰色线条）
class _HiddenTextPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.hearing,
          size: 48,
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
        const SizedBox(height: AppSpacing.l),
        for (int i = 0; i < 3; i++) ...[
          Container(
            width: 200 - i * 40,
            height: 8,
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ],
    );
  }
}

/// 句间停顿倒计时指示器
class _PauseCountdownIndicator extends StatelessWidget {
  final Duration remaining;
  final Duration total;
  final AppLocalizations l10n;

  const _PauseCountdownIndicator({
    required this.remaining,
    required this.total,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalMs = total.inMilliseconds;
    final remainingMs = remaining.inMilliseconds;
    final progress = totalMs > 0 ? 1.0 - (remainingMs / totalMs) : 1.0;
    final seconds = (remainingMs / 1000).ceil();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.reviewDifficultPracticeAdvancing(seconds),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        SizedBox(
          width: 120,
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}

/// 标注模式视图（听不懂 → 揭示文本）
class _AnnotationModeView extends StatelessWidget {
  final String text;
  final AppLocalizations l10n;
  final VoidCallback onContinue;
  final VoidCallback onRemoveDifficult;

  const _AnnotationModeView({
    super.key,
    required this.text,
    required this.l10n,
    required this.onContinue,
    required this.onRemoveDifficult,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: SentenceAnnotationCard(
                text: text,
                isDifficult: true,
                onToggle: onRemoveDifficult,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onContinue,
              child: Text(l10n.intensiveListenContinue),
            ),
          ),
        ],
      ),
    );
  }
}

/// 标注重播模式视图（带字幕重播中）
class _AnnotationReplayView extends StatelessWidget {
  final String text;
  final AppLocalizations l10n;

  const _AnnotationReplayView({
    super.key,
    required this.text,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: theme.textTheme.titleMedium?.copyWith(height: 1.6),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.l),
            CircularProgressIndicator(strokeWidth: 2),
            const SizedBox(height: AppSpacing.s),
            Text(
              l10n.intensiveListenReplayingWithSubtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 底部播放控制
class _PlaybackControls extends StatelessWidget {
  final ReviewDifficultPracticeState playerState;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPlayPause;

  const _PlaybackControls({
    required this.playerState,
    required this.onPrevious,
    required this.onNext,
    required this.onPlayPause,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 标注重播模式下播放按钮禁用
    final isPlayDisabled = playerState.isAnnotationReplay;

    // 标注模式和标注重播模式下禁用导航
    // 仅标注重播模式下禁用（自动播放中不应干预）
    final isNavDisabled = playerState.isAnnotationReplay;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        AppSpacing.m,
        AppSpacing.l,
        AppSpacing.xl,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 上一句
          IconButton(
            onPressed: isNavDisabled || playerState.currentSentenceIndex <= 0
                ? null
                : onPrevious,
            icon: const Icon(Icons.skip_previous, size: 32),
            color: theme.colorScheme.onSurface,
          ),
          const SizedBox(width: AppSpacing.l),

          // 播放/暂停
          GestureDetector(
            onTap: isPlayDisabled ? null : onPlayPause,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: isPlayDisabled
                    ? theme.colorScheme.surfaceContainerHighest
                    : theme.colorScheme.primary,
                shape: BoxShape.circle,
                boxShadow: isPlayDisabled
                    ? null
                    : [
                        BoxShadow(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.3,
                          ),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Icon(
                playerState.isPlaying ? Icons.pause : Icons.play_arrow,
                size: 32,
                color: isPlayDisabled
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.onPrimary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.l),

          // 下一句
          IconButton(
            onPressed:
                isNavDisabled ||
                    playerState.currentSentenceIndex >=
                        playerState.totalSentences - 1
                ? null
                : onNext,
            icon: const Icon(Icons.skip_next, size: 32),
            color: theme.colorScheme.onSurface,
          ),
        ],
      ),
    );
  }
}

/// 完成对话框
class _CompleteDialog extends StatelessWidget {
  final int totalSentences;
  final int stepIndex;
  final int totalSteps;
  final String stageName;
  final String? nextStepName;
  final bool isLastStep;

  const _CompleteDialog({
    required this.totalSentences,
    required this.stepIndex,
    required this.totalSteps,
    required this.stageName,
    this.nextStepName,
    this.isLastStep = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.s),
            Flexible(child: Text(l10n.reviewDifficultPracticeCompleteTitle)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.stepProgressLabel(stepIndex + 1, totalSteps, stageName),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            Text(
              l10n.reviewDifficultPracticeCompleteMessage(totalSentences),
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
        actions: _buildActions(context, l10n),
      ),
    );
  }

  List<Widget> _buildActions(BuildContext context, AppLocalizations l10n) {
    if (nextStepName != null) {
      return [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.backToPlan),
              ),
            ),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.continueToStep(nextStepName!)),
              ),
            ),
          ],
        ),
      ];
    } else if (isLastStep) {
      return [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.completeReview),
          ),
        ),
      ];
    } else {
      return [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.backToPlan),
          ),
        ),
      ];
    }
  }
}

/// 格式化时间戳为 MM:SS.m 格式
String _formatTimestamp(Duration d) {
  final hours = d.inHours;
  final minutes = d.inMinutes % 60;
  final seconds = d.inSeconds % 60;
  final tenths = (d.inMilliseconds % 1000) ~/ 100;
  final mm = minutes.toString().padLeft(2, '0');
  final ss = seconds.toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:$mm:$ss.$tenths';
  }
  return '$mm:$ss.$tenths';
}
