// 学习计划表页面
//
// 展示音频的完整学习流程：首学（4步）和复习（9步）。
// 纯 UI 页面，使用静态 mock 数据展示效果。
// 导航路径：合集详情 → 学习计划表 → 播放器
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:math' as math;
import '../providers/audio_library_provider.dart';
import '../providers/listening_practice/listening_practice_provider.dart';
import '../l10n/app_localizations.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';

/// 学习计划表页面
class LearningPlanScreen extends ConsumerStatefulWidget {
  /// 合集 ID
  final String collectionId;

  /// 音频项 ID
  final String audioItemId;

  const LearningPlanScreen({
    super.key,
    required this.collectionId,
    required this.audioItemId,
  });

  @override
  ConsumerState<LearningPlanScreen> createState() =>
      _LearningPlanScreenState();
}

class _LearningPlanScreenState extends ConsumerState<LearningPlanScreen> {
  /// 复习区域是否展开
  bool _isReviewExpanded = false;

  @override
  void initState() {
    super.initState();
    // 检查并加载音频数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final audioItem = ref
          .read(audioLibraryProvider.notifier)
          .getItemById(widget.audioItemId);
      if (audioItem == null) return;

      final practiceState = ref.read(listeningPracticeProvider);
      if (practiceState.currentAudioItem?.id != audioItem.id) {
        ref.read(listeningPracticeProvider.notifier).loadAudio(audioItem);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final audioItem = ref
        .watch(audioLibraryProvider.notifier)
        .getItemById(widget.audioItemId);

    // audioItem 找不到时显示错误页面
    if (audioItem == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l10n.audioFileNotFound)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(audioItem.name)),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.m),
              children: [
                _ProgressCard(l10n: l10n),
                const SizedBox(height: AppSpacing.l),
                _FirstStudySection(l10n: l10n),
                const SizedBox(height: AppSpacing.l),
                _ReviewSection(
                  l10n: l10n,
                  isExpanded: _isReviewExpanded,
                  onToggle: () {
                    setState(() {
                      _isReviewExpanded = !_isReviewExpanded;
                    });
                  },
                ),
              ],
            ),
          ),
          _BottomButton(
            l10n: l10n,
            onPressed: () {
              context.push(
                AppRoutes.player(widget.collectionId, widget.audioItemId),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// 顶部进度卡片 — 圆环进度 + 状态文字
class _ProgressCard extends StatelessWidget {
  final AppLocalizations l10n;

  const _ProgressCard({required this.l10n});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: CustomPaint(
                painter: _ProgressRingPainter(
                  progress: 0.0,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  progressColor: theme.colorScheme.primary,
                ),
                child: Center(
                  child: Text(
                    '0%',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.learningPlanProgress,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.learningPlanNotStarted,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 圆环进度绘制器
class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final Color backgroundColor;
  final Color progressColor;

  _ProgressRingPainter({
    required this.progress,
    required this.backgroundColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 4;
    const strokeWidth = 6.0;

    // 背景圆环
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // 进度圆弧
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_ProgressRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// 首学区域 — 默认展开，显示 4 个步骤
class _FirstStudySection extends StatelessWidget {
  final AppLocalizations l10n;

  const _FirstStudySection({required this.l10n});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final steps = [
      _StepData(
        icon: Icons.headphones,
        name: l10n.stepBlindListening,
        description: l10n.stepBlindListeningDesc,
      ),
      _StepData(
        icon: Icons.hearing,
        name: l10n.stepIntensiveListening,
        description: l10n.stepIntensiveListeningDesc,
      ),
      _StepData(
        icon: Icons.record_voice_over,
        name: l10n.stepShadowing,
        description: l10n.stepShadowingDesc,
      ),
      _StepData(
        icon: Icons.chat,
        name: l10n.stepRetelling,
        description: l10n.stepRetellingDesc,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Row(
            children: [
              Icon(
                Icons.school,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.s),
              Text(
                l10n.firstStudy,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                l10n.stepProgress(0, 4),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        ...List.generate(steps.length, (index) {
          final step = steps[index];
          return _StepCard(
            stepNumber: index + 1,
            icon: step.icon,
            name: step.name,
            description: step.description,
            isCompleted: false,
            isLast: index == steps.length - 1,
          );
        }),
      ],
    );
  }
}

/// 步骤数据模型（内部使用）
class _StepData {
  final IconData icon;
  final String name;
  final String description;

  const _StepData({
    required this.icon,
    required this.name,
    required this.description,
  });
}

/// 单个步骤卡片
class _StepCard extends StatelessWidget {
  final int stepNumber;
  final IconData icon;
  final String name;
  final String description;
  final bool isCompleted;
  final bool isLast;

  const _StepCard({
    required this.stepNumber,
    required this.icon,
    required this.name,
    required this.description,
    required this.isCompleted,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 左侧时间线
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isCompleted
                        ? Icon(
                            Icons.check,
                            size: 16,
                            color: theme.colorScheme.onPrimary,
                          )
                        : Text(
                            '$stepNumber',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
              ],
            ),
          ),
          // 右侧卡片内容
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: isLast ? 0 : AppSpacing.s,
              ),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.m),
                  child: Row(
                    children: [
                      Icon(icon, color: theme.colorScheme.primary, size: 24),
                      const SizedBox(width: AppSpacing.m),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              description,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 复习区域 — 默认折叠，展开后显示 9 个复习阶段
class _ReviewSection extends StatelessWidget {
  final AppLocalizations l10n;
  final bool isExpanded;
  final VoidCallback onToggle;

  const _ReviewSection({
    required this.l10n,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final reviews = [
      _ReviewData(name: l10n.review1, interval: l10n.reviewInterval6h),
      _ReviewData(name: l10n.review2, interval: l10n.reviewInterval1d),
      _ReviewData(name: l10n.review3, interval: l10n.reviewInterval3d),
      _ReviewData(name: l10n.review4, interval: l10n.reviewInterval5d),
      _ReviewData(name: l10n.review5, interval: l10n.reviewInterval8d),
      _ReviewData(name: l10n.review6, interval: l10n.reviewInterval11d),
      _ReviewData(name: l10n.review7, interval: l10n.reviewInterval14d),
      _ReviewData(name: l10n.reviewEarTraining, interval: l10n.reviewInterval21d),
      _ReviewData(
        name: l10n.reviewGraduation,
        interval: l10n.reviewInterval28d,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题行（可点击展开/折叠）
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.refresh,
                  color: theme.colorScheme.tertiary,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.s),
                Text(
                  l10n.review,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  l10n.stepProgress(0, 9),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.expand_more,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        // 展开的复习步骤列表
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.s),
            child: Column(
              children: List.generate(reviews.length, (index) {
                final review = reviews[index];
                return _ReviewStepCard(
                  stepNumber: index + 1,
                  name: review.name,
                  interval: review.interval,
                  isCompleted: false,
                  isLast: index == reviews.length - 1,
                );
              }),
            ),
          ),
          crossFadeState: isExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 300),
        ),
      ],
    );
  }
}

/// 复习数据模型（内部使用）
class _ReviewData {
  final String name;
  final String interval;

  const _ReviewData({required this.name, required this.interval});
}

/// 复习步骤卡片 — 带竖向时间线
class _ReviewStepCard extends StatelessWidget {
  final int stepNumber;
  final String name;
  final String interval;
  final bool isCompleted;
  final bool isLast;

  const _ReviewStepCard({
    required this.stepNumber,
    required this.name,
    required this.interval,
    required this.isCompleted,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 左侧时间线
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? theme.colorScheme.tertiary
                        : theme.colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isCompleted
                        ? Icon(
                            Icons.check,
                            size: 16,
                            color: theme.colorScheme.onTertiary,
                          )
                        : Text(
                            '$stepNumber',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
              ],
            ),
          ),
          // 右侧卡片
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: isLast ? 0 : AppSpacing.s,
              ),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.m,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          interval,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onTertiaryContainer,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 底部固定按钮
class _BottomButton extends StatelessWidget {
  final AppLocalizations l10n;
  final VoidCallback onPressed;

  const _BottomButton({required this.l10n, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: onPressed,
            child: Text(l10n.startLearning),
          ),
        ),
      ),
    );
  }
}
