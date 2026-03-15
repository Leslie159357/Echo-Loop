import 'package:flutter/material.dart';

import '../../database/enums.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';

/// 复习步骤提示弹窗。
///
/// 交互与首次学习保持一致：先展示当前步骤说明，再点击“开始练习”进入页面。
Future<void> showReviewBriefingSheet({
  required BuildContext context,
  required LearningStage stage,
  required SubStageType subStage,
  Duration? estimatedDuration,
  required VoidCallback onStartPractice,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _ReviewBriefingSheet(
      stage: stage,
      subStage: subStage,
      estimatedDuration: estimatedDuration,
      onStartPractice: onStartPractice,
    ),
  );
}

class _ReviewBriefingSheet extends StatelessWidget {
  final LearningStage stage;
  final SubStageType subStage;
  final Duration? estimatedDuration;
  final VoidCallback onStartPractice;

  const _ReviewBriefingSheet({
    required this.stage,
    required this.subStage,
    this.estimatedDuration,
    required this.onStartPractice,
  });

  /// 格式化预估时长
  String _formatEstimatedDuration(AppLocalizations l10n, Duration duration) {
    final minutes = (duration.inSeconds / 60).ceil();
    if (minutes < 1) return l10n.estimatedLessThanOneMinute;
    return l10n.estimatedMinutes(minutes);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isZh = Localizations.localeOf(context).languageCode == 'zh';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        AppSpacing.l,
        AppSpacing.l,
        AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppSpacing.l),
          Icon(
            _iconForSubStage(subStage),
            size: 56,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: AppSpacing.m),
          Text(
            _titleForSubStage(l10n, isZh, subStage),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _stageLabel(l10n, stage),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.l),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.m),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.s),
                Expanded(
                  child: Text(
                    _tipForSubStage(isZh, subStage),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (estimatedDuration != null) ...[
            const SizedBox(height: AppSpacing.m),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  _formatEstimatedDuration(l10n, estimatedDuration!),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.l),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                onStartPractice();
              },
              icon: const Icon(Icons.play_arrow),
              label: Text(l10n.startPractice),
            ),
          ),
        ],
      ),
    );
  }
}

IconData _iconForSubStage(SubStageType subStage) {
  return switch (subStage) {
    SubStageType.blindListen => Icons.headphones,
    SubStageType.reviewDifficultPractice => Icons.hearing,
    SubStageType.reviewRetellParagraph => Icons.notes,
    SubStageType.reviewRetellSummary => Icons.summarize,
    SubStageType.intensiveListen => Icons.hearing,
    SubStageType.listenAndRepeat => Icons.record_voice_over,
    SubStageType.retell => Icons.chat,
  };
}

String _titleForSubStage(
  AppLocalizations l10n,
  bool isZh,
  SubStageType subStage,
) {
  return switch (subStage) {
    SubStageType.blindListen => l10n.stepBlindListening,
    SubStageType.reviewDifficultPractice =>
      isZh ? '难句补练' : 'Difficult sentence practice',
    SubStageType.reviewRetellParagraph => isZh ? '段落复述' : 'Paragraph retelling',
    SubStageType.reviewRetellSummary => isZh ? '全文总结复述' : 'Summary retelling',
    SubStageType.intensiveListen => l10n.stepIntensiveListening,
    SubStageType.listenAndRepeat => l10n.stepShadowing,
    SubStageType.retell => l10n.stepRetelling,
  };
}

String _tipForSubStage(bool isZh, SubStageType subStage) {
  return switch (subStage) {
    SubStageType.blindListen =>
      isZh
          ? '全文盲听一遍，不看字幕先听大意。'
          : 'Listen once without subtitles and focus on the gist.',
    SubStageType.reviewDifficultPractice =>
      isZh
          ? '先盲听难句，听不懂再进入补练。'
          : 'Blind listen difficult sentences first, then do remedial practice.',
    SubStageType.reviewRetellParagraph =>
      isZh ? '按段复述本轮复习内容。' : 'Retell this review round paragraph by paragraph.',
    SubStageType.reviewRetellSummary =>
      isZh ? '用 3-5 句话总结全文大意。' : 'Summarize the full audio in 3-5 sentences.',
    SubStageType.intensiveListen =>
      isZh
          ? '逐句精听并处理听不懂的内容。'
          : 'Work sentence by sentence and resolve difficult parts.',
    SubStageType.listenAndRepeat =>
      isZh ? '针对关键句进行跟读巩固。' : 'Shadow key sentences for reinforcement.',
    SubStageType.retell =>
      isZh ? '按段复述主要内容。' : 'Retell the main points by paragraph.',
  };
}

String _stageLabel(AppLocalizations l10n, LearningStage stage) {
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
