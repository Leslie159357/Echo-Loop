/// 段落选择底部弹窗（通用）
///
/// 盲听和复述共用的段落时长选择弹窗。
/// 显示图标 + 标题 + 说明 + 段落时长下拉 + (可选)段间停顿下拉 + 段落数预览 + 开始按钮。
library;

import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/blind_listen_settings.dart';
import '../../models/sentence.dart';
import '../../theme/app_theme.dart';
import '../../utils/paragraph_grouping.dart';
import '../review/review_briefing_sheet.dart' show formatEstimatedDuration;

/// 目标段落时长选项（秒）
/// 0 = 逐句，-1 = 不分段（全文一段）
const paragraphDurationOptions = [0, 10, 20, 30, 45, 60, 90, -1];

/// 显示段落选择弹窗
///
/// [icon] 顶部图标
/// [title] 标题文字
/// [subtitle] 说明文字
/// [sentences] 字幕句子列表
/// [defaultSeconds] 默认段落时长（秒）
/// [showPauseMultiplier] 是否显示段间停顿行
/// [stageLabel] 标题下方显示的阶段名（如"第三轮复习"），可选
/// [estimatedDurationText] 说明下方显示的预估时长文本，可选（静态文案，不随选项变化）
/// [estimateDurationBuilder] 动态预估时长 builder，根据当前选中的段落时长 + 停顿倍数实时计算；
///   优先级高于 [estimatedDurationText]，二者同时传入时取 builder
/// [onStartPractice] 回调，传递 (目标时长, 停顿倍数)
Future<void> showParagraphSelectionSheet({
  required BuildContext context,
  required IconData icon,
  required String title,
  required String subtitle,
  required List<Sentence> sentences,
  int defaultSeconds = 30,
  bool showPauseMultiplier = false,
  List<double>? pauseMultiplierOptions,
  String? stageLabel,
  String? estimatedDurationText,
  Duration Function(int targetSeconds, double pauseMultiplier)?
      estimateDurationBuilder,
  required void Function(Duration targetDuration, double pauseMultiplier)
      onStartPractice,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _ParagraphSelectionSheet(
      icon: icon,
      title: title,
      subtitle: subtitle,
      sentences: sentences,
      defaultSeconds: defaultSeconds,
      showPauseMultiplier: showPauseMultiplier,
      pauseMultiplierOptions: pauseMultiplierOptions,
      stageLabel: stageLabel,
      estimatedDurationText: estimatedDurationText,
      estimateDurationBuilder: estimateDurationBuilder,
      onStartPractice: onStartPractice,
    ),
  );
}

class _ParagraphSelectionSheet extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Sentence> sentences;
  final int defaultSeconds;
  final bool showPauseMultiplier;
  final List<double>? pauseMultiplierOptions;
  final String? stageLabel;
  final String? estimatedDurationText;
  final Duration Function(int targetSeconds, double pauseMultiplier)?
      estimateDurationBuilder;
  final void Function(Duration targetDuration, double pauseMultiplier)
      onStartPractice;

  const _ParagraphSelectionSheet({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.sentences,
    required this.defaultSeconds,
    required this.showPauseMultiplier,
    this.pauseMultiplierOptions,
    this.stageLabel,
    this.estimatedDurationText,
    this.estimateDurationBuilder,
    required this.onStartPractice,
  });

  @override
  State<_ParagraphSelectionSheet> createState() =>
      _ParagraphSelectionSheetState();
}

class _ParagraphSelectionSheetState extends State<_ParagraphSelectionSheet> {
  late int _targetSeconds = widget.defaultSeconds;
  /// -1.0 = 自动（智能模式）
  double _pauseMultiplier = -1.0;

  int get _paragraphCount {
    if (_targetSeconds == 0) return widget.sentences.length;
    if (_targetSeconds < 0) return 1;
    return groupSentencesIntoParagraphs(
      widget.sentences,
      Duration(seconds: _targetSeconds),
    ).length;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l, AppSpacing.s, AppSpacing.l, AppSpacing.l,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 拖拽指示条
            Center(
              child: Container(
                width: 32,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.m),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant
                      .withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // 图标
            Icon(widget.icon, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: AppSpacing.m),

            // 标题
            Text(
              widget.title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            // 阶段名（可选，如"第三轮复习"）
            if (widget.stageLabel != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                widget.stageLabel!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.xs),

            // 说明
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
              child: Text(
                widget.subtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),

            // 预估时长（可选，如"预计 3 分钟"）
            // 优先用 builder 动态计算（随段长/停顿倍数实时刷新），否则回退到静态文案
            Builder(builder: (_) {
              final dynamicText = widget.estimateDurationBuilder != null
                  ? formatEstimatedDuration(
                      l10n,
                      widget.estimateDurationBuilder!(
                        _targetSeconds,
                        _pauseMultiplier,
                      ),
                    )
                  : null;
              final text = dynamicText ?? widget.estimatedDurationText;
              if (text == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: AppSpacing.s),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      text,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: AppSpacing.l),

            // 段落时长行
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.blindListenTargetDuration,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: DropdownButton<int>(
                    value: _targetSeconds,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    items: paragraphDurationOptions.map((s) {
                      final label = switch (s) {
                        0 => l10n.retellBriefingSentenceLevel,
                        -1 => l10n.blindListenNoParagraph,
                        _ => '${s}s',
                      };
                      return DropdownMenuItem(
                        value: s,
                        child: Text(label),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _targetSeconds = v);
                    },
                  ),
                ),
              ],
            ),

            // 段间停顿行（仅盲听显示，且不分段时无段间隔可言，隐藏）
            if (widget.showPauseMultiplier && _targetSeconds != -1) ...[
              const SizedBox(height: AppSpacing.s),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.blindListenPauseBetween,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(
                    width: 80,
                    child: DropdownButton<double>(
                    value: _pauseMultiplier,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    items: [
                      DropdownMenuItem(
                        value: -1.0,
                        child: Text(l10n.pauseModeSmart),
                      ),
                      ...(widget.pauseMultiplierOptions ??
                              BlindListenSettings.multiplierOptions)
                          .map((m) {
                        final label = m == m.roundToDouble()
                            ? '${m.toInt()}x'
                            : '${m}x';
                        return DropdownMenuItem(
                          value: m,
                          child: Text(label),
                        );
                      }),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _pauseMultiplier = v);
                    },
                  ),
                  ),
                ],
              ),
            ],

            // 段落数预览（不分段时无意义，隐藏）
            if (_targetSeconds != -1) ...[
              const SizedBox(height: AppSpacing.m),
              Text(
                l10n.blindListenParagraphCount(_paragraphCount),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.l),

            // 开始练习按钮
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  final duration = _targetSeconds < 0
                      ? const Duration(hours: 24)
                      : Duration(seconds: _targetSeconds);
                  widget.onStartPractice(duration, _pauseMultiplier);
                },
                icon: const Icon(Icons.play_arrow),
                label: Text(l10n.startPractice),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
