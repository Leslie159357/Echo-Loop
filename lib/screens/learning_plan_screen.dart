// 学习计划表页面
//
// 展示音频的完整学习流程：首学（4步）和复习（7步）。
// 从 LearningProgressNotifier 读取真实进度数据，
// 步骤卡片支持三态：已完成、当前、未开始。
// 导航路径：合集详情 → 学习计划表 → 播放器
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:math' as math;
import '../database/enums.dart';
import '../models/audio_item.dart';
import '../models/learning_progress.dart';
import '../providers/audio_engine/audio_engine_provider.dart';
import '../providers/audio_library_provider.dart';
import '../providers/learning_progress_provider.dart';
import '../providers/learning_session/learning_session_provider.dart';
import '../providers/listening_practice/listening_practice_provider.dart';
import '../l10n/app_localizations.dart';
import '../router/app_router.dart';
import '../services/subtitle_parser.dart';
import '../theme/app_theme.dart';
import '../widgets/blind_listen_briefing_sheet.dart';
import '../widgets/intensive_listen/intensive_listen_briefing_sheet.dart';

/// 学习计划表页面
class LearningPlanScreen extends ConsumerStatefulWidget {
  /// 合集 ID（从独立音频路由进入时为 null）
  final String? collectionId;

  /// 音频项 ID
  final String audioItemId;

  const LearningPlanScreen({
    super.key,
    this.collectionId,
    required this.audioItemId,
  });

  @override
  ConsumerState<LearningPlanScreen> createState() => _LearningPlanScreenState();
}

class _LearningPlanScreenState extends ConsumerState<LearningPlanScreen> {
  /// 复习区域是否展开
  bool _isReviewExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 确保学习进度记录存在
      ref
          .read(learningProgressNotifierProvider.notifier)
          .ensureProgress(widget.audioItemId);

      // 检查并加载音频数据
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

  /// 处理"开始学习/继续学习"按钮点击
  void _handleStartLearning(BuildContext context, LearningProgress? progress) {
    final currentSubStage =
        progress?.currentSubStage ?? SubStageType.blindListen;

    if (currentSubStage == SubStageType.blindListen) {
      _startBlindListen(context, progress);
    } else if (currentSubStage == SubStageType.intensiveListen) {
      _startIntensiveListen(context);
    } else {
      // 其他子步骤 → 直接导航到播放器
      if (widget.collectionId != null) {
        context.push(
          AppRoutes.player(widget.collectionId!, widget.audioItemId),
        );
      } else {
        context.push(AppRoutes.audioPlayer(widget.audioItemId));
      }
    }
  }

  /// 进入全文盲听
  void _startBlindListen(BuildContext context, LearningProgress? progress) {
    final isFirstStudy =
        progress == null || progress.currentStage == LearningStage.firstLearn;
    final reviewRound = progress != null ? progress.currentStage.index : 0;
    final totalDuration = ref.read(audioEngineProvider).totalDuration;

    showBlindListenBriefingSheet(
      context: context,
      isFirstStudy: isFirstStudy,
      reviewRound: reviewRound,
      audioDuration: totalDuration,
      onStartPractice: () async {
        await ref
            .read(learningSessionProvider.notifier)
            .enterBlindListenMode(widget.audioItemId);
        if (mounted) {
          context.push(
            AppRoutes.blindListenPlayer(
              widget.collectionId,
              widget.audioItemId,
            ),
          );
        }
      },
    );
  }

  /// 进入逐句精听
  void _startIntensiveListen(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final lpState = ref.read(listeningPracticeProvider);

    // 无字幕则提示用户上传
    if (lpState.sentences.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.intensiveListenNoSubtitle),
          content: Text(l10n.intensiveListenNoSubtitleMessage),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.ok),
            ),
          ],
        ),
      );
      return;
    }

    showIntensiveListenBriefingSheet(
      context: context,
      sentenceCount: lpState.sentences.length,
      onStartPractice: () async {
        await ref
            .read(learningSessionProvider.notifier)
            .enterIntensiveListenMode(widget.audioItemId, lpState.sentences);
        if (mounted) {
          context.push(
            AppRoutes.intensiveListenPlayer(
              widget.collectionId,
              widget.audioItemId,
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final audioItem = ref.watch(
      audioLibraryProvider.select(
        (s) => s.audioItems
            .where((i) => i.id == widget.audioItemId)
            .firstOrNull,
      ),
    );

    // 监听学习进度
    final progress = ref.watch(
      learningProgressNotifierProvider.select(
        (s) => s.progressMap[widget.audioItemId],
      ),
    );

    // audioItem 找不到时显示错误页面
    if (audioItem == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l10n.audioFileNotFound)),
      );
    }

    // 当活跃阶段在复习区域时自动展开
    if (progress != null &&
        progress.currentStage.index >= LearningStage.review0.index &&
        !progress.isCompleted &&
        !_isReviewExpanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isReviewExpanded = true;
          });
        }
      });
    }

    final hasTranscript = audioItem.hasTranscript;

    return Scaffold(
      appBar: AppBar(title: Text(audioItem.name)),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.m),
              children: [
                _ProgressCard(l10n: l10n, progress: progress),
                const SizedBox(height: AppSpacing.s),
                _AudioInfoRow(l10n: l10n, audioItem: audioItem),
                if (!hasTranscript) ...[
                  const SizedBox(height: AppSpacing.s),
                  _NoTranscriptBanner(l10n: l10n),
                ],
                const SizedBox(height: AppSpacing.l),
                _FirstStudySection(
                  l10n: l10n,
                  progress: progress,
                  collectionId: widget.collectionId,
                  audioItemId: widget.audioItemId,
                ),
                const SizedBox(height: AppSpacing.l),
                _ReviewSection(
                  l10n: l10n,
                  progress: progress,
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
            progress: progress,
            onPressed: hasTranscript
                ? () => _handleStartLearning(context, progress)
                : null,
          ),
        ],
      ),
    );
  }
}

/// 顶部进度卡片 — 圆环进度 + 状态文字
class _ProgressCard extends StatelessWidget {
  final AppLocalizations l10n;
  final LearningProgress? progress;

  const _ProgressCard({required this.l10n, this.progress});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = progress?.progressPercent ?? 0.0;
    final percentText = '${(percent * 100).round()}%';

    // 状态文字
    final statusText = _getStatusText();

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
                  progress: percent,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  progressColor: theme.colorScheme.primary,
                ),
                child: Center(
                  child: Text(
                    percentText,
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
                    statusText,
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

  /// 获取状态文字
  String _getStatusText() {
    if (progress == null || !progress!.isStarted) {
      return l10n.learningPlanNotStarted;
    }
    if (progress!.isCompleted) {
      return l10n.learningCompleted;
    }
    return '${progress!.currentStage.label} ${l10n.learningInProgress}';
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
///
/// 已完成的盲听步骤支持点击进入自由练习模式。
class _FirstStudySection extends ConsumerWidget {
  final AppLocalizations l10n;
  final LearningProgress? progress;

  /// 合集 ID（导航用，从独立音频路由进入时为 null）
  final String? collectionId;

  /// 音频项 ID（导航用）
  final String audioItemId;

  const _FirstStudySection({
    required this.l10n,
    this.progress,
    required this.collectionId,
    required this.audioItemId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final completedCount = progress?.completedFirstStudySteps ?? 0;
    final firstLearnStage = LearningStage.firstLearn;

    /// 子步骤的 UI 数据映射
    final stepDataMap = {
      SubStageType.blindListen: _StepData(
        icon: Icons.headphones,
        name: l10n.stepBlindListening,
        description: l10n.stepBlindListeningDesc,
      ),
      SubStageType.intensiveListen: _StepData(
        icon: Icons.hearing,
        name: l10n.stepIntensiveListening,
        description: l10n.stepIntensiveListeningDesc,
      ),
      SubStageType.listenAndRepeat: _StepData(
        icon: Icons.record_voice_over,
        name: l10n.stepShadowing,
        description: l10n.stepShadowingDesc,
      ),
      SubStageType.retell: _StepData(
        icon: Icons.chat,
        name: l10n.stepRetelling,
        description: l10n.stepRetellingDesc,
      ),
    };

    final subStages = firstLearnStage.subStages;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Row(
            children: [
              Icon(Icons.school, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: AppSpacing.s),
              Text(
                l10n.firstStudy,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                l10n.stepProgress(completedCount, subStages.length),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        ...List.generate(subStages.length, (index) {
          final subStage = subStages[index];
          final stepData = stepDataMap[subStage]!;
          final isCompleted =
              progress?.isSubStageCompleted(firstLearnStage, subStage) ?? false;
          final isCurrent =
              progress?.isCurrentSubStage(firstLearnStage, subStage) ?? false;

          // 盲听步骤显示已听遍数 + 难度
          String? subtitle;
          if (subStage == SubStageType.blindListen) {
            final passCount = progress?.blindListenPassCount ?? 0;
            final parts = <String>[];
            if (passCount > 0) {
              parts.add(l10n.blindListenPassInfo(passCount));
            }
            // 盲听已完成时显示用户选择的难度
            if (progress?.isSubStageCompleted(firstLearnStage, subStage) ??
                false) {
              parts.add(l10n.difficultyLabel(progress!.difficulty.label));
            }
            if (parts.isNotEmpty) {
              subtitle = parts.join(' · ');
            }
          }

          // 已完成步骤支持点击进入自由练习
          VoidCallback? onTap;
          if (isCompleted && subStage == SubStageType.blindListen) {
            onTap = () => _startFreePlayBlindListen(context, ref);
          } else if (isCompleted && subStage == SubStageType.intensiveListen) {
            onTap = () => _startFreePlayIntensiveListen(context, ref);
          }

          return _StepCard(
            stepNumber: index + 1,
            icon: stepData.icon,
            name: stepData.name,
            description: stepData.description,
            isCompleted: isCompleted,
            isCurrent: isCurrent,
            isLast: index == subStages.length - 1,
            subtitle: subtitle,
            onTap: onTap,
          );
        }),
      ],
    );
  }

  /// 进入自由练习盲听模式（直接进入，不弹 briefing sheet）
  Future<void> _startFreePlayBlindListen(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await ref
        .read(learningSessionProvider.notifier)
        .enterBlindListenMode(audioItemId, isFreePlay: true);
    if (context.mounted) {
      context.push(AppRoutes.blindListenPlayer(collectionId, audioItemId));
    }
  }

  /// 进入自由练习精听模式（直接进入，不弹 briefing sheet）
  Future<void> _startFreePlayIntensiveListen(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final lpState = ref.read(listeningPracticeProvider);
    if (lpState.sentences.isEmpty) return;

    await ref
        .read(learningSessionProvider.notifier)
        .enterIntensiveListenMode(
          audioItemId,
          lpState.sentences,
          isFreePlay: true,
        );
    if (context.mounted) {
      context.push(AppRoutes.intensiveListenPlayer(collectionId, audioItemId));
    }
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

/// 单个步骤卡片 — 支持三态：已完成、当前、未开始
class _StepCard extends StatelessWidget {
  final int stepNumber;
  final IconData icon;
  final String name;
  final String description;
  final bool isCompleted;
  final bool isCurrent;
  final bool isLast;

  /// 可选的附加信息（如"已听 X 遍"）
  final String? subtitle;

  /// 点击回调（如已完成的盲听步骤可点击进入自由练习）
  final VoidCallback? onTap;

  const _StepCard({
    required this.stepNumber,
    required this.icon,
    required this.name,
    required this.description,
    required this.isCompleted,
    required this.isCurrent,
    required this.isLast,
    this.subtitle,
    this.onTap,
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
                        ? Colors.green.shade50
                        : isCurrent
                        ? null
                        : theme.colorScheme.surfaceContainerHighest,
                    border: isCurrent
                        ? Border.all(color: theme.colorScheme.primary, width: 2)
                        : null,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isCompleted
                        ? Icon(Icons.check, size: 16, color: Colors.green)
                        : Text(
                            '$stepNumber',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isCurrent
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
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
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.s),
              child: Card(
                clipBehavior: onTap != null ? Clip.antiAlias : Clip.none,
                child: InkWell(
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.m),
                    child: Row(
                      children: [
                        Icon(
                          icon,
                          color: isCompleted
                              ? theme.colorScheme.outline
                              : theme.colorScheme.primary,
                          size: 24,
                        ),
                        const SizedBox(width: AppSpacing.m),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isCompleted
                                      ? theme.colorScheme.outline
                                      : null,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                description,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isCompleted
                                      ? theme.colorScheme.outline
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              if (subtitle != null) ...[
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  subtitle!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
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

/// 复习区域 — 默认折叠，展开后显示 7 个复习阶段
class _ReviewSection extends StatelessWidget {
  final AppLocalizations l10n;
  final LearningProgress? progress;
  final bool isExpanded;
  final VoidCallback onToggle;

  const _ReviewSection({
    required this.l10n,
    this.progress,
    required this.isExpanded,
    required this.onToggle,
  });

  /// 获取当前复习阶段的倒计时文案
  String? _getReviewTimingText(LearningStage stage) {
    if (progress == null) return null;
    if (!progress!.isCurrentStage(stage)) return null;

    final nextReview = progress!.nextReviewAt;
    if (nextReview == null) return null;

    final now = DateTime.now();
    if (now.isAfter(nextReview) || now.isAtSameMomentAs(nextReview)) {
      return l10n.reviewReady;
    }

    final diff = nextReview.difference(now);
    if (diff.inDays > 0) {
      return l10n.reviewCountdown(diff.inDays);
    }
    return l10n.reviewCountdownHours(diff.inHours.clamp(1, 999));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final completedCount = progress?.completedReviewStages ?? 0;

    /// 复习阶段列表（review0 ~ review28，共 7 个）
    final reviews = [
      _ReviewData(
        name: l10n.reviewRound0,
        interval: l10n.reviewIntervalNow,
        stage: LearningStage.review0,
      ),
      _ReviewData(
        name: l10n.reviewRound1,
        interval: l10n.reviewInterval1d,
        stage: LearningStage.review1,
      ),
      _ReviewData(
        name: l10n.reviewRound2,
        interval: l10n.reviewInterval2d,
        stage: LearningStage.review2,
      ),
      _ReviewData(
        name: l10n.reviewRound4,
        interval: l10n.reviewInterval4d,
        stage: LearningStage.review4,
      ),
      _ReviewData(
        name: l10n.reviewRound7,
        interval: l10n.reviewInterval7d,
        stage: LearningStage.review7,
      ),
      _ReviewData(
        name: l10n.reviewRound14,
        interval: l10n.reviewInterval14d,
        stage: LearningStage.review14,
      ),
      _ReviewData(
        name: l10n.reviewRound28,
        interval: l10n.reviewInterval28d,
        stage: LearningStage.review28,
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
                  l10n.stepProgress(completedCount, 7),
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
                final isCompleted =
                    progress?.isStageCompleted(review.stage) ?? false;
                final isCurrent =
                    progress?.isCurrentStage(review.stage) ?? false;
                final timingText = _getReviewTimingText(review.stage);
                return _ReviewStepCard(
                  stepNumber: index + 1,
                  name: review.name,
                  interval: review.interval,
                  isCompleted: isCompleted,
                  isCurrent: isCurrent,
                  isLast: index == reviews.length - 1,
                  timingText: timingText,
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
  final LearningStage stage;

  const _ReviewData({
    required this.name,
    required this.interval,
    required this.stage,
  });
}

/// 复习步骤卡片 — 带竖向时间线，支持三态
class _ReviewStepCard extends StatelessWidget {
  final int stepNumber;
  final String name;
  final String interval;
  final bool isCompleted;
  final bool isCurrent;
  final bool isLast;

  /// 当前阶段的复习倒计时文案（仅 isCurrent 时显示）
  final String? timingText;

  const _ReviewStepCard({
    required this.stepNumber,
    required this.name,
    required this.interval,
    required this.isCompleted,
    required this.isCurrent,
    required this.isLast,
    this.timingText,
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
                        ? Colors.green.shade50
                        : isCurrent
                        ? null
                        : theme.colorScheme.surfaceContainerHighest,
                    border: isCurrent
                        ? Border.all(
                            color: theme.colorScheme.tertiary,
                            width: 2,
                          )
                        : null,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isCompleted
                        ? Icon(Icons.check, size: 16, color: Colors.green)
                        : Text(
                            '$stepNumber',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isCurrent
                                  ? theme.colorScheme.tertiary
                                  : theme.colorScheme.onSurfaceVariant,
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
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.s),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.m,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: isCompleted
                                    ? theme.colorScheme.outline
                                    : null,
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
                      // 复习倒计时提示
                      if (timingText != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          timingText!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.tertiary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
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

/// 音频信息行 — 显示时长、句子数、单词数
class _AudioInfoRow extends StatelessWidget {
  final AppLocalizations l10n;
  final AudioItem audioItem;

  const _AudioInfoRow({required this.l10n, required this.audioItem});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chips = <Widget>[];

    // 时长
    if (audioItem.totalDuration > 0) {
      chips.add(_InfoChip(
        icon: Icons.timer_outlined,
        label: SubtitleParser.formatDuration(
          Duration(seconds: audioItem.totalDuration),
        ),
        theme: theme,
      ));
    }

    // 句子数
    if (audioItem.sentenceCount > 0) {
      chips.add(_InfoChip(
        icon: Icons.format_list_numbered,
        label: l10n.sentenceCountLabel(audioItem.sentenceCount),
        theme: theme,
      ));
    }

    // 单词数
    if (audioItem.wordCount > 0) {
      chips.add(_InfoChip(
        icon: Icons.text_fields,
        label: l10n.wordCountLabel(audioItem.wordCount),
        theme: theme,
      ));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Wrap(spacing: AppSpacing.s, runSpacing: AppSpacing.xs, children: chips),
    );
  }
}

/// 单个信息标签
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final ThemeData theme;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// 无字幕提醒横幅 — 提示用户需要上传字幕
class _NoTranscriptBanner extends StatelessWidget {
  final AppLocalizations l10n;

  const _NoTranscriptBanner({required this.l10n});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: theme.colorScheme.onErrorContainer,
              size: 24,
            ),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: Text(
                l10n.noTranscriptWarning,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 底部固定按钮 — 根据进度显示不同文案
///
/// [onPressed] 为 null 时按钮禁用（例如无字幕时）。
class _BottomButton extends StatelessWidget {
  final AppLocalizations l10n;
  final LearningProgress? progress;
  final VoidCallback? onPressed;

  const _BottomButton({
    required this.l10n,
    this.progress,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final buttonText = (progress != null && progress!.isStarted)
        ? l10n.continueLearning
        : l10n.startLearning;

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
          child: FilledButton(onPressed: onPressed, child: Text(buttonText)),
        ),
      ),
    );
  }
}
