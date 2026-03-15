/// 复述简报底部弹窗
///
/// 进入段落复述前显示，用户选择目标段落时长，
/// 实时预览段落数（切换时运行完整 DP 计算）。
library;

import 'package:flutter/material.dart';
import '../../database/enums.dart';
import '../../l10n/app_localizations.dart';
import '../../models/sentence.dart';
import '../../theme/app_theme.dart';
import '../../utils/paragraph_grouping.dart';

/// 根据学习阶段计算段落复述的默认目标段落时长（秒）
///
/// - 首次学习 + 首轮复习 → 0（逐句）
/// - review1 + review2 → 10s
/// - review4 + review7 → 20s
/// - review14 + review28 → 30s
int retellDefaultSeconds(LearningStage? stage) {
  return switch (stage) {
    null || LearningStage.firstLearn || LearningStage.review0 => 0,
    LearningStage.review1 || LearningStage.review2 => 10,
    LearningStage.review4 || LearningStage.review7 => 20,
    _ => 30,
  };
}

/// 可选的目标段落时长（秒）
/// 0 表示句子级别（每句一段，不按时间分割）
const _targetDurationOptions = [0, 10, 20, 30, 45, 60, 90];

/// 显示复述简报底部弹窗
///
/// [sentences] 完整句子列表（用于 DP 预览段落数）
/// [onStartPractice] 点击"开始练习"时回调，传递选中的目标时长
Future<void> showRetellBriefingSheet({
  required BuildContext context,
  required List<Sentence> sentences,
  required void Function(Duration targetDuration) onStartPractice,
  int defaultSeconds = 30,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _RetellBriefingSheet(
      sentences: sentences,
      onStartPractice: onStartPractice,
      defaultSeconds: defaultSeconds,
    ),
  );
}

class _RetellBriefingSheet extends StatefulWidget {
  final List<Sentence> sentences;
  final void Function(Duration targetDuration) onStartPractice;
  final int defaultSeconds;

  const _RetellBriefingSheet({
    required this.sentences,
    required this.onStartPractice,
    required this.defaultSeconds,
  });

  @override
  State<_RetellBriefingSheet> createState() => _RetellBriefingSheetState();
}

class _RetellBriefingSheetState extends State<_RetellBriefingSheet> {
  late int _selectedSeconds = widget.defaultSeconds;

  /// 根据当前选择计算段落数
  int get _paragraphCount {
    // 句子级别：每句一段
    if (_selectedSeconds == 0) return widget.sentences.length;

    final groups = groupSentencesIntoParagraphs(
      widget.sentences,
      Duration(seconds: _selectedSeconds),
    );
    return groups.length;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l, AppSpacing.l, AppSpacing.l, AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖拽指示条
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppSpacing.l),

          // 图标
          Icon(Icons.chat, size: 56, color: theme.colorScheme.primary),
          const SizedBox(height: AppSpacing.m),

          // 标题
          Text(
            l10n.retellBriefingTitle,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),

          // 说明
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
            child: Text(
              l10n.retellBriefingSubtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.l),

          // 目标段落时长选择
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              l10n.retellBriefingTargetDuration,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s),

          // ChoiceChips
          Wrap(
            spacing: AppSpacing.s,
            runSpacing: AppSpacing.s,
            children: _targetDurationOptions.map((seconds) {
              final label = seconds == 0
                  ? l10n.retellBriefingSentenceLevel
                  : l10n.retellBriefingSeconds(seconds);
              return ChoiceChip(
                label: Text(label),
                selected: _selectedSeconds == seconds,
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _selectedSeconds = seconds);
                  }
                },
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.m),

          // 段落数预览（句子级别显示句子数）
          Text(
            _selectedSeconds == 0
                ? l10n.retellBriefingSentenceCount(_paragraphCount)
                : l10n.retellBriefingParagraphCount(_paragraphCount),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.l),

          // 开始练习按钮
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onStartPractice(Duration(seconds: _selectedSeconds));
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
