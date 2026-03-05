/// 复述播放器页面
///
/// 段级复述的核心交互页面。
/// 布局: AppBar → 进度条 → 句子列表 → 阶段指示器 → 底部控制。
/// 支持 listening/retelling 双阶段切换、显示模式循环、倒计时跳过。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../database/enums.dart';
import '../l10n/app_localizations.dart';
import '../models/retell_settings.dart';
import '../providers/learning_progress_provider.dart';
import '../providers/learning_session/learning_session_provider.dart';
import '../providers/learning_session/retell_player_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/intensive_listen/word_dictionary_sheet.dart';
import '../widgets/retell/retell_sentence_tile.dart';
import '../widgets/retell/retell_settings_sheet.dart';

/// 复述播放器页面
class RetellPlayerScreen extends ConsumerStatefulWidget {
  /// 合集 ID（独立音频路由时为 null）
  final String? collectionId;

  /// 音频项 ID
  final String audioItemId;

  const RetellPlayerScreen({
    super.key,
    this.collectionId,
    required this.audioItemId,
  });

  @override
  ConsumerState<RetellPlayerScreen> createState() => _RetellPlayerScreenState();
}

class _RetellPlayerScreenState extends ConsumerState<RetellPlayerScreen> {
  bool _isShowingDialog = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(retellPlayerProvider.notifier).startPlaying();
    });
  }

  /// 格式化时长（纯秒数 + 单位）
  String _formatDuration(Duration d) {
    return '${d.inSeconds}s';
  }

  /// 处理退出
  Future<void> _handleExit() async {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.read(retellPlayerProvider);

    // 已完成直接退出
    if (state.isCompleted) {
      await _exit();
      return;
    }

    // 确认对话框
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.retellExitConfirmTitle),
        content: Text(l10n.retellExitConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // 保存断点（存当前段落第一句的全局索引，分段无关）
      final sentenceIndex = ref
          .read(retellPlayerProvider.notifier)
          .currentParagraphFirstSentenceIndex;
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .saveRetellParagraphIndex(widget.audioItemId, sentenceIndex);
      await _exit();
    }
  }

  /// 执行退出
  Future<void> _exit() async {
    await ref.read(learningSessionProvider.notifier).exitLearningMode();
    if (mounted) context.pop();
  }

  /// 获取当前步骤的上下文信息（步骤序号、总步骤数、阶段名称）
  ({int stepIndex, int totalSteps, String stageName}) _getStepContext() {
    final progress = ref
        .read(learningProgressNotifierProvider)
        .progressMap[widget.audioItemId];

    if (progress == null) {
      final subStages = LearningStage.firstLearn.subStages;
      final idx = subStages.indexOf(SubStageType.retell);
      return (
        stepIndex: idx,
        totalSteps: subStages.length,
        stageName: LearningStage.firstLearn.label,
      );
    }

    final stage = progress.currentStage;
    final subStages = stage.subStages;
    final currentIdx = subStages.indexOf(progress.currentSubStage);
    return (
      stepIndex: currentIdx,
      totalSteps: subStages.length,
      stageName: stage.label,
    );
  }

  /// 处理完成
  ///
  /// 弹出完成对话框，提供"再来一遍"和"完成/返回"两个操作。
  /// 步骤完成标记推迟到用户确认后才执行。
  Future<void> _handleComplete() async {
    if (_isShowingDialog || !mounted) return;
    _isShowingDialog = true;

    final l10n = AppLocalizations.of(context)!;
    final sessionState = ref.read(learningSessionProvider);
    final retellState = ref.read(retellPlayerProvider);
    final progress = ref
        .read(learningProgressNotifierProvider)
        .progressMap[widget.audioItemId];

    // 确定完成按钮文案
    final String completeButtonText;
    if (sessionState.isFreePlay) {
      completeButtonText = l10n.retellCompleteFreePlay;
    } else if (progress?.currentStage == LearningStage.firstLearn) {
      completeButtonText = l10n.retellCompleteFirstStudy;
    } else {
      completeButtonText = l10n.retellCompleteReview;
    }

    // 获取步骤上下文
    final stepCtx = sessionState.isFreePlay ? null : _getStepContext();

    // 弹出完成对话框：true = 完成退出, null = 再来一遍
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _RetellCompleteDialog(
        completeButtonText: completeButtonText,
        totalParagraphs: retellState.totalParagraphs,
        stepIndex: stepCtx?.stepIndex,
        totalSteps: stepCtx?.totalSteps,
        stageName: stepCtx?.stageName,
      ),
    );

    _isShowingDialog = false;
    if (!mounted) return;

    // 递增复述遍数（无论再来一遍还是完成，都算一遍）
    await ref
        .read(learningProgressNotifierProvider.notifier)
        .incrementRetellPassCount(widget.audioItemId);

    if (result == true) {
      // 完成退出
      if (!sessionState.isFreePlay) {
        await ref
            .read(learningProgressNotifierProvider.notifier)
            .completeCurrentSubStage(widget.audioItemId);
      }
      await _exit();
    } else {
      // 再来一遍：重置到第一段
      await ref.read(retellPlayerProvider.notifier).restart();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final state = ref.watch(retellPlayerProvider);
    final player = ref.read(retellPlayerProvider.notifier);

    // 监听完成状态
    ref.listen<RetellPlayerState>(retellPlayerProvider, (prev, next) {
      if (next.isCompleted && !(prev?.isCompleted ?? false)) {
        _handleComplete();
      }
    });

    final sentences = player.currentParagraphSentences;
    final paragraphDuration = player.currentParagraphDuration;
    final keywords = player.keywordsMap;
    final progress = (state.totalParagraphs > 0)
        ? (state.currentParagraphIndex + 1) / state.totalParagraphs
        : 0.0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _handleExit();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.retellTitle),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleExit,
          ),
          actions: [
            // 设置按钮
            IconButton(
              icon: const Icon(Icons.tune),
              onPressed: () => showRetellSettingsSheet(context),
            ),
          ],
        ),
        body: Column(
          children: [
            // 进度条
            LinearProgressIndicator(value: progress),

            // 段落进度文字
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.m,
                vertical: AppSpacing.s,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.retellParagraphProgress(
                      state.currentParagraphIndex + 1,
                      state.totalParagraphs,
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    l10n.retellParagraphDuration(
                      _formatDuration(paragraphDuration),
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            // 显示模式切换（仅当前段落生效，可见词关闭时隐藏）
            if (state.settings.keywordMethod != KeywordMethod.off)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
                child: SegmentedButton<RetellDisplayMode>(
                  segments: [
                    ButtonSegment(
                      value: RetellDisplayMode.keywordsOnly,
                      label: Text(l10n.retellDisplayKeywordsOnly),
                    ),
                    ButtonSegment(
                      value: RetellDisplayMode.showAll,
                      label: Text(l10n.retellDisplayShowAll),
                    ),
                    ButtonSegment(
                      value: RetellDisplayMode.hideAll,
                      label: Text(l10n.retellDisplayHideAll),
                    ),
                  ],
                  selected: {state.displayMode},
                  onSelectionChanged: (selected) =>
                      player.setDisplayMode(selected.first),
                ),
              ),
            const SizedBox(height: AppSpacing.s),

            // 句子列表
            Expanded(
              child: Card(
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
                  itemCount: sentences.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    indent: AppSpacing.m,
                    endIndent: AppSpacing.m,
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.3,
                    ),
                  ),
                  itemBuilder: (context, index) {
                    final sentence = sentences[index];
                    // 使用句子的全局索引来查找关键词
                    final sentenceKeywords =
                        keywords[sentence.index] ?? const {};

                    return RetellSentenceTile(
                      sentence: sentence,
                      phase: state.phase,
                      displayMode:
                          state.settings.keywordMethod != KeywordMethod.off
                          ? state.displayMode
                          : RetellDisplayMode.hideAll,
                      keywordIndices: sentenceKeywords,
                      isPlayingSentence:
                          state.phase == RetellPhase.listening &&
                          index == state.playingSentenceIndex,
                      onWordTap: (word) =>
                          showWordDictionarySheet(context: context, word: word),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.s),

            // 阶段指示器
            _PhaseIndicator(state: state, l10n: l10n),

            // 倒计时控制按钮（仅在复述倒计时期间显示）
            if (state.isRetellCountdown)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: state.isCountdownPaused
                        ? () => player.resumeCountdown()
                        : () => player.pauseCountdown(),
                    icon: Icon(
                      state.isCountdownPaused ? Icons.play_arrow : Icons.pause,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.l),
                  IconButton(
                    onPressed: () => player.toggleCountdownFastForward(),
                    icon: Icon(
                      Icons.fast_forward,
                      color: state.isCountdownFastForward
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ),
                ],
              ),

            const SizedBox(height: AppSpacing.s),

            // 底部控制
            _BottomControls(state: state, player: player, l10n: l10n),

            const SizedBox(height: AppSpacing.m),
          ],
        ),
      ),
    );
  }
}

/// 阶段指示器：listening/retelling 状态 + 倒计时
///
/// 布局与精听/跟读页面的倒计时指示器保持一致：
/// 文字标签居中 + 120px 短进度条，固定 64px 高度防止阶段切换跳动。
class _PhaseIndicator extends StatelessWidget {
  final RetellPlayerState state;
  final AppLocalizations l10n;

  const _PhaseIndicator({required this.state, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 64,
      child: Center(
        child: state.phase == RetellPhase.listening
            ? _buildListeningIndicator(theme)
            : _buildRetellingIndicator(theme),
      ),
    );
  }

  /// listening 阶段：图标+文字（上行） + 遍数（下行）
  Widget _buildListeningIndicator(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.headphones, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.s),
            Text(
              l10n.retellListeningPhase,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        if (state.settings.repeatCount > 1) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.retellRepeatInfo(
              state.currentRepeatCount,
              state.settings.repeatCount,
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  /// retelling 阶段：与精听/跟读的 _PauseCountdownIndicator 一致
  /// 文字标签 + 120px 短进度条，毫秒级平滑进度
  Widget _buildRetellingIndicator(ThemeData theme) {
    final totalMs = state.pauseDuration.inMilliseconds;
    final remainingMs = state.pauseRemaining.inMilliseconds;
    final progress = totalMs > 0 ? 1.0 - (remainingMs / totalMs) : 1.0;
    final seconds = (remainingMs / 1000).ceil();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.retellRetellingCountdown(seconds),
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

/// 底部控制栏
class _BottomControls extends StatelessWidget {
  final RetellPlayerState state;
  final RetellPlayer player;
  final AppLocalizations l10n;

  const _BottomControls({
    required this.state,
    required this.player,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFirst = state.currentParagraphIndex <= 0;
    final isLast = state.currentParagraphIndex >= state.totalParagraphs - 1;

    // 中间大按钮：listening → play/pause，retelling countdown → replay
    final IconData centerIcon;
    final VoidCallback centerOnPressed;
    if (state.phase == RetellPhase.listening) {
      centerIcon = state.isPlaying ? Icons.pause : Icons.play_arrow;
      centerOnPressed = state.isPlaying ? player.pause : player.resume;
    } else if (state.isRetellCountdown) {
      centerIcon = Icons.play_arrow;
      centerOnPressed = player.replayDuringCountdown;
    } else {
      centerIcon = Icons.play_arrow;
      centerOnPressed = player.resume;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 上一段
        IconButton(
          onPressed: isFirst ? null : player.goToPreviousParagraph,
          icon: const Icon(Icons.skip_previous, size: 32),
          color: theme.colorScheme.onSurface,
        ),
        const SizedBox(width: AppSpacing.l),

        // 中间大按钮（与跟读页一致的圆形样式）
        GestureDetector(
          onTap: centerOnPressed,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              centerIcon,
              size: 32,
              color: theme.colorScheme.onPrimary,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.l),

        // 下一段
        IconButton(
          onPressed: isLast ? null : player.goToNextParagraph,
          icon: const Icon(Icons.skip_next, size: 32),
          color: theme.colorScheme.onSurface,
        ),
      ],
    );
  }
}

/// 复述完成对话框
///
/// 布局与精听/跟读完成对话框保持一致：
/// 标题行（Icon + 文本）→ 内容区（步骤进度 + 统计）→ 底部按钮区。
/// 返回 true = 完成退出，返回 null = 再来一遍。
class _RetellCompleteDialog extends StatelessWidget {
  final String completeButtonText;
  final int totalParagraphs;
  final int? stepIndex;
  final int? totalSteps;
  final String? stageName;

  const _RetellCompleteDialog({
    required this.completeButtonText,
    required this.totalParagraphs,
    this.stepIndex,
    this.totalSteps,
    this.stageName,
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
            Flexible(child: Text(l10n.retellCompleteTitle)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 步骤进度（非自由练习模式）
            if (stepIndex != null && totalSteps != null && stageName != null)
              Text(
                l10n.stepProgressLabel(stepIndex! + 1, totalSteps!, stageName!),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            if (stepIndex != null) const SizedBox(height: AppSpacing.s),
            // 完成统计
            Text(
              l10n.retellCompleteMessage(totalParagraphs),
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: Text(l10n.retellPracticeAgain),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(completeButtonText),
            ),
          ),
        ],
      ),
    );
  }
}
