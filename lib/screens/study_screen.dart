import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../database/enums.dart';
import '../l10n/app_localizations.dart';
import '../providers/learning_progress_provider.dart';
import '../providers/study_stats_provider.dart';
import '../providers/study_task_provider.dart';
import '../providers/time_provider.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';
import '../widgets/learning_progress_icon.dart';
import '../widgets/study/study_stats_header.dart';

/// 学习任务列表页
///
/// 页面结构（从上到下）：
/// 1. AppBar（标题）
/// 2. 统计 Chips + 7天柱状图
/// 3. Ready to Review（可开始的复习）
/// 4. Upcoming Reviews（默认折叠）
/// 5. First Study（首次学习任务）
/// 6. Completed（默认折叠）
class StudyScreen extends ConsumerWidget {
  const StudyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tasks = ref.watch(studyTaskProvider);
    final completedAudios = ref.watch(completedAudioProvider);
    final now = ref.watch(nowProvider)();
    final statsAsync = ref.watch(studyStatsNotifierProvider);

    final readyReviews = tasks
        .where((t) => t.type == StudyTaskType.reviewReady)
        .toList();
    final upcomingReviews = tasks
        .where((t) => t.type == StudyTaskType.reviewUpcoming)
        .toList();
    final firstStudies = tasks
        .where((t) => t.type == StudyTaskType.firstStudy)
        .toList();

    // 判断空状态类型
    final hasAnyTask = tasks.isNotEmpty || completedAudios.isNotEmpty;

    // AppBar streak chip
    final streakChip = statsAsync.whenOrNull(
      data: (stats) => stats.streak > 0
          ? Padding(
              padding: const EdgeInsets.only(right: AppSpacing.m),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.local_fire_department_rounded,
                      size: 16,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      l10n.streakDays(stats.streak),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.studyTasks),
        actions: [if (streakChip != null) streakChip],
      ),
      body: !hasAnyTask
          ? const _EmptyState(type: _EmptyStateType.noTasks)
          : tasks.isEmpty && completedAudios.isNotEmpty
          ? _buildAllDoneContent(context, l10n, completedAudios)
          : ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.m,
                vertical: AppSpacing.s,
              ),
              children: [
                // 统计 Chips + 柱状图
                const StudyStatsHeader(),
                const SizedBox(height: AppSpacing.l),

                // Ready to Review
                if (readyReviews.isNotEmpty) ...[
                  _TaskSection(
                    title: l10n.readyToReview(readyReviews.length),
                    emoji: '🔁',
                    tasks: readyReviews,
                    l10n: l10n,
                    now: now,
                  ),
                  const SizedBox(height: AppSpacing.m),
                ],

                // Upcoming Reviews (默认折叠)
                if (upcomingReviews.isNotEmpty) ...[
                  _CollapsibleSection(
                    title: l10n.upcomingReviews(upcomingReviews.length),
                    summary: l10n.upcomingReviewsSummary(
                      upcomingReviews.length,
                    ),
                    initiallyExpanded: false,
                    children: upcomingReviews
                        .map((t) => _TaskCard(task: t, l10n: l10n, now: now))
                        .toList(),
                  ),
                  const SizedBox(height: AppSpacing.m),
                ],

                // First Study
                if (firstStudies.isNotEmpty) ...[
                  _TaskSection(
                    title: l10n.firstStudySection(firstStudies.length),
                    emoji: '🌱',
                    tasks: firstStudies,
                    l10n: l10n,
                    now: now,
                  ),
                  const SizedBox(height: AppSpacing.m),
                ],

                // Completed (默认折叠)
                if (completedAudios.isNotEmpty) ...[
                  _CompletedSection(completedAudios: completedAudios),
                  const SizedBox(height: AppSpacing.m),
                ],
              ],
            ),
    );
  }

  /// 全部完成时的内容
  Widget _buildAllDoneContent(
    BuildContext context,
    AppLocalizations l10n,
    List<({String audioId, String audioName})> completedAudios,
  ) {
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.s,
      ),
      children: [
        const StudyStatsHeader(),
        const SizedBox(height: AppSpacing.xl),
        const _EmptyState(type: _EmptyStateType.allDone),
        if (completedAudios.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.m),
          _CompletedSection(completedAudios: completedAudios),
        ],
      ],
    );
  }
}

// ============================================================
// Task Sections
// ============================================================

/// 任务区段（emoji + 标题 + 卡片列表）
class _TaskSection extends StatelessWidget {
  final String title;
  final String emoji;
  final List<StudyTask> tasks;
  final AppLocalizations l10n;
  final DateTime now;

  const _TaskSection({
    required this.title,
    required this.emoji,
    required this.tasks,
    required this.l10n,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 区段标题
        Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 6),
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s),
        ...tasks.map((task) => _TaskCard(task: task, l10n: l10n, now: now)),
      ],
    );
  }
}

/// 可折叠区段（标题 + 摘要 + 展开后的内容）
class _CollapsibleSection extends StatelessWidget {
  final String title;
  final String summary;
  final bool initiallyExpanded;
  final List<Widget> children;

  const _CollapsibleSection({
    required this.title,
    required this.summary,
    required this.initiallyExpanded,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ExpansionTile(
        title: Text(title, style: theme.textTheme.titleSmall),
        subtitle: Text(
          summary,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        initiallyExpanded: initiallyExpanded,
        shape: const Border(),
        collapsedShape: const Border(),
        childrenPadding: const EdgeInsets.only(
          left: AppSpacing.m,
          right: AppSpacing.m,
          bottom: AppSpacing.s,
        ),
        children: children,
      ),
    );
  }
}

// ============================================================
// Enhanced Task Card
// ============================================================

/// 增强版任务卡片
///
/// 左侧色条指示任务类型，显示子阶段、进度条、细化按钮文案、逾期视觉强调。
class _TaskCard extends StatelessWidget {
  final StudyTask task;
  final AppLocalizations l10n;
  final DateTime now;

  const _TaskCard({required this.task, required this.l10n, required this.now});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDisabled = task.type == StudyTaskType.reviewUpcoming;
    final stageLabel = _stageSubStageLabel(l10n, task.stage, task.subStage);
    final statusText = _statusText(context, l10n, task, now);
    final isOverdue = task.isOverdue;

    // 获取进度数据
    final container = ProviderScope.containerOf(context);
    final progressMap = container
        .read(learningProgressNotifierProvider)
        .progressMap;
    final progress = progressMap[task.audioId];
    final progressPercent = progress?.progressPercent ?? 0.0;

    // 左侧色条颜色
    final accentColor = isOverdue
        ? theme.colorScheme.error
        : task.type == StudyTaskType.firstStudy
        ? theme.colorScheme.tertiary
        : theme.colorScheme.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.s),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          children: [
            // 左侧色条
            Container(width: 4, color: accentColor),
            // 内容区
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, AppSpacing.m, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        LearningProgressIcon(
                          progress: progress,
                          size: 36,
                          iconSize: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                task.audioName,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      stageLabel,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (statusText.isNotEmpty) ...[
                                    const SizedBox(width: AppSpacing.s),
                                    _StatusBadge(
                                      text: statusText,
                                      isOverdue: isOverdue,
                                      isInProgress: statusText ==
                                          l10n.learningInProgress,
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s),
                        FilledButton.tonal(
                          onPressed: isDisabled
                              ? null
                              : () => context.push(
                                  AppRoutes.audioLearningPlan(task.audioId),
                                ),
                          child: Text(_actionLabel(l10n, task)),
                        ),
                      ],
                    ),
                    // 进度条
                    if (progressPercent > 0) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: progressPercent,
                          minHeight: 4,
                          color: accentColor,
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 从 LearningProgressState 获取任务进度百分比的闭包
// ============================================================
// Completed Section
// ============================================================

/// 已完成音频折叠区
class _CompletedSection extends StatelessWidget {
  final List<({String audioId, String audioName})> completedAudios;

  const _CompletedSection({required this.completedAudios});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Card(
      child: ExpansionTile(
        title: Text(
          l10n.completedSection(completedAudios.length),
          style: theme.textTheme.titleSmall,
        ),
        initiallyExpanded: false,
        shape: const Border(),
        collapsedShape: const Border(),
        childrenPadding: const EdgeInsets.only(
          left: AppSpacing.m,
          right: AppSpacing.m,
          bottom: AppSpacing.s,
        ),
        children: completedAudios
            .map(
              (audio) => ListTile(
                dense: true,
                leading: Icon(
                  Icons.check_circle,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                title: Text(audio.audioName),
                contentPadding: EdgeInsets.zero,
                onTap: () =>
                    context.push(AppRoutes.audioLearningPlan(audio.audioId)),
              ),
            )
            .toList(),
      ),
    );
  }
}

// ============================================================
// Empty States
// ============================================================

enum _EmptyStateType { noTasks, allDone }

/// 空状态组件
class _EmptyState extends StatelessWidget {
  final _EmptyStateType type;

  const _EmptyState({required this.type});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isNoTasks = type == _EmptyStateType.noTasks;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 图标容器
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: (isNoTasks ? theme.colorScheme.primary : Colors.amber)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                isNoTasks
                    ? Icons.library_music_outlined
                    : Icons.celebration_outlined,
                size: 40,
                color: isNoTasks
                    ? theme.colorScheme.primary
                    : Colors.amber.shade700,
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            Text(
              isNoTasks ? l10n.noStudyTasks : l10n.allDoneTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            Text(
              isNoTasks ? l10n.noStudyTasksHint : l10n.allDoneHint,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (isNoTasks) ...[
              const SizedBox(height: AppSpacing.l),
              FilledButton.tonal(
                onPressed: () {
                  final shell = StatefulNavigationShell.of(context);
                  shell.goBranch(0);
                },
                child: Text(l10n.goToLibrary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Helper functions
// ============================================================

/// 生成阶段+子阶段的组合标签
String _stageSubStageLabel(
  AppLocalizations l10n,
  LearningStage stage,
  SubStageType subStage,
) {
  final subStageName = _subStageName(l10n, subStage);
  if (stage == LearningStage.firstLearn) {
    return l10n.subStageLabelFirstLearn(subStageName);
  }
  final stageName = _stageName(l10n, stage);
  return l10n.subStageLabelReview(stageName, subStageName);
}

/// 子步骤本地化名称
String _subStageName(AppLocalizations l10n, SubStageType subStage) {
  return switch (subStage) {
    SubStageType.blindListen => l10n.stepBlindListening,
    SubStageType.intensiveListen => l10n.stepIntensiveListening,
    SubStageType.listenAndRepeat => l10n.stepShadowing,
    SubStageType.retell => l10n.stepRetelling,
    SubStageType.reviewDifficultPractice => l10n.reviewDifficultPracticeTitle,
    SubStageType.reviewRetellParagraph => l10n.retellBriefingTitle,
    SubStageType.reviewRetellSummary => l10n.retellBriefingTitle,
  };
}

/// 阶段本地化名称
String _stageName(AppLocalizations l10n, LearningStage stage) {
  return switch (stage) {
    LearningStage.firstLearn => l10n.firstStudy,
    LearningStage.review0 => l10n.reviewRound0,
    LearningStage.review1 => l10n.reviewRound1,
    LearningStage.review2 => l10n.reviewRound2,
    LearningStage.review4 => l10n.reviewRound4,
    LearningStage.review7 => l10n.reviewRound7,
    LearningStage.review14 => l10n.reviewRound14,
    LearningStage.review28 => l10n.reviewRound28,
    LearningStage.completed => l10n.learningCompleted,
  };
}

/// 按钮文案：未开始=开始，进行中=继续，复习=复习
String _actionLabel(AppLocalizations l10n, StudyTask task) {
  if (task.type == StudyTaskType.reviewReady ||
      task.type == StudyTaskType.reviewUpcoming) {
    return l10n.reviewButton;
  }
  if (task.subStage == SubStageType.blindListen &&
      task.stage == LearningStage.firstLearn) {
    return l10n.startButton;
  }
  return l10n.continueButton;
}

/// 状态标签（学习中 / 逾期 / 倒计时等）
///
/// "学习中"始终使用中性色，逾期使用 error 色，其余使用 surface 色。
class _StatusBadge extends StatelessWidget {
  final String text;
  final bool isOverdue;
  final bool isInProgress;

  const _StatusBadge({
    required this.text,
    required this.isOverdue,
    required this.isInProgress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // "学习中"统一使用中性色，不受逾期影响
    final useErrorStyle = isOverdue && !isInProgress;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: useErrorStyle
            ? theme.colorScheme.error.withValues(alpha: 0.1)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: 10,
          color: useErrorStyle
              ? theme.colorScheme.error
              : theme.colorScheme.onSurfaceVariant,
          fontWeight: useErrorStyle ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }
}

/// 状态文案（逾期、距离可复习时间等）
///
/// 已有进度（非首个子阶段）→ "学习中"
/// 逾期分级：无时长/>7天→"待复习"，≤7天→"待复习 · X天前到期"，<1天→"待复习 · X小时前到期"
String _statusText(
  BuildContext context,
  AppLocalizations l10n,
  StudyTask task,
  DateTime now,
) {
  // 已有进度（当前子阶段不是该阶段的第一个）→ 显示"学习中"
  final subStages = task.stage.subStages;
  if (subStages.isNotEmpty && task.subStage != subStages.first) {
    return l10n.learningInProgress;
  }
  if (task.isOverdue) {
    final overdue = task.overdueDuration;
    if (overdue == null || overdue.inDays > 7) return l10n.reviewDue;
    if (overdue.inDays > 0) return l10n.overdueDays(overdue.inDays);
    final hours = overdue.inHours.clamp(1, 999);
    return l10n.overdueHours(hours);
  }
  if (task.type == StudyTaskType.reviewUpcoming) {
    final nextAt = task.nextReviewAt;
    if (nextAt == null) return '';
    final diff = nextAt.difference(now);
    if (diff.inDays > 0) return l10n.availableInDays(diff.inDays);
    final hours = diff.inHours.clamp(1, 999);
    return l10n.availableInHours(hours);
  }
  return '';
}
