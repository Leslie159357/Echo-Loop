import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/study_stats_provider.dart';
import '../../theme/app_theme.dart';
import 'learned_word_forms_sheet.dart';

/// 学习统计头部组件
///
/// 包含 2 个统计指标卡片（今日时长、本周时长）和 7 天柱状图。
class StudyStatsHeader extends ConsumerWidget {
  const StudyStatsHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(studyStatsNotifierProvider);

    return statsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (stats) => Column(
        children: [
          _StatsChips(stats: stats),
          if (stats.dailySeconds.any((s) => s > 0)) ...[
            const SizedBox(height: AppSpacing.m),
            _WeeklyBarChart(
              dailyInputSeconds: stats.dailyInputSeconds,
              dailyOutputSeconds: stats.dailyOutputSeconds,
              dailyTotalSeconds: stats.dailySeconds,
            ),
          ],
        ],
      ),
    );
  }
}

/// 2 个统计指标：今日时长、本周时长
///
/// 使用自定义样式容器替代默认 Chip，增加视觉层次。
class _StatsChips extends StatelessWidget {
  final StudyStats stats;

  const _StatsChips({required this.stats});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Wrap(
      spacing: AppSpacing.s,
      runSpacing: AppSpacing.xs,
      children: [
        _StatChip(
          icon: Icons.timer_outlined,
          iconColor: theme.colorScheme.primary,
          label:
              '${l10n.todayStudyTimeShort}: ${_formatTime(l10n, stats.todaySeconds)}',
        ),
        _StatChip(
          icon: Icons.date_range_outlined,
          iconColor: theme.colorScheme.tertiary,
          label:
              '${l10n.weekStudyTimeShort}: ${_formatTime(l10n, stats.weekTotalSeconds)}',
        ),
        _StatChip(
          icon: Icons.headphones_outlined,
          iconColor: Colors.teal,
          label: l10n.listenTimeWords(
            _formatTimeShort(stats.todayInputSeconds),
            _formatWordCount(stats.todayInputWords),
          ),
        ),
        _StatChip(
          icon: Icons.mic_outlined,
          iconColor: Colors.deepPurple,
          label: l10n.speakTimeWords(
            _formatTimeShort(stats.todayOutputSeconds),
            _formatWordCount(stats.todayOutputWords),
          ),
        ),
        _StatChip(
          icon: Icons.spellcheck_rounded,
          iconColor: Colors.indigo,
          label:
              '${l10n.learnedWordFormsShort}: ${_formatWordCount(stats.learnedWordFormCount)} · ${l10n.todayNewShort} +${_formatWordCount(stats.todayNewWordForms)}',
          onTap: () {
            showLearnedWordFormsSheet(context: context);
          },
        ),
      ],
    );
  }
}

/// 单个统计指标
///
/// 自定义样式：圆角容器 + 图标 + 文字，比默认 Chip 更精致。
class _StatChip extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback? onTap;

  const _StatChip({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: iconColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

/// 7 天学习时长柱状图（双色堆叠）
///
/// 底部 teal = 输入时间，顶部 deepPurple = 输出时间。
/// 柱高 = 输入 + 输出（不含暂停等非听说时间）。
/// 如果输入/输出时间都为 0，回退到总学习时间单色显示。
class _WeeklyBarChart extends StatelessWidget {
  final List<int> dailyInputSeconds;
  final List<int> dailyOutputSeconds;
  final List<int> dailyTotalSeconds;

  const _WeeklyBarChart({
    required this.dailyInputSeconds,
    required this.dailyOutputSeconds,
    required this.dailyTotalSeconds,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 向前兼容：旧数据无 input/output 时，用 totalSeconds 当作输入
    final dailyBarSeconds = List.generate(7, (i) {
      final io = dailyInputSeconds[i] + dailyOutputSeconds[i];
      return io > 0 ? io : dailyTotalSeconds[i];
    });

    final maxSeconds = dailyBarSeconds.reduce((a, b) => a > b ? a : b);
    const maxBarHeight = 56.0;

    // 计算最近 7 天的星期标签
    final now = DateTime.now();
    final weekdayLabels = List.generate(7, (i) {
      final date = now.subtract(Duration(days: 6 - i));
      return _weekdayShort(date.weekday);
    });

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.m,
          AppSpacing.m,
          AppSpacing.m,
          12,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(7, (i) {
            final isToday = i == 6;
            final totalSec = dailyBarSeconds[i];
            final ratio = maxSeconds > 0 ? totalSec / maxSeconds : 0.0;
            final barHeight = (ratio * maxBarHeight).clamp(3.0, maxBarHeight);

            // 双色比例（旧数据无 input/output 时全部算输入）
            final hasBreakdown =
                dailyInputSeconds[i] > 0 || dailyOutputSeconds[i] > 0;
            final inputSec =
                hasBreakdown ? dailyInputSeconds[i] : dailyTotalSeconds[i];
            final outputSec =
                hasBreakdown ? dailyOutputSeconds[i] : 0;
            final inputRatio = totalSec > 0 ? inputSec / totalSec : 1.0;

            return Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 柱顶数值
                  if (totalSec > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        _formatMinutes(totalSec),
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 9,
                          fontWeight: isToday
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: isToday
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  // 柱体（双色堆叠或纯输入单色）
                  if (outputSec > 0)
                    _buildStackedBar(
                      barHeight: barHeight,
                      inputRatio: inputRatio,
                      isToday: isToday,
                    )
                  else
                    Container(
                      height: barHeight,
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        color: isToday
                            ? Colors.teal
                            : Colors.teal.withValues(alpha: 0.2),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                          bottom: Radius.circular(2),
                        ),
                      ),
                    ),
                  const SizedBox(height: 5),
                  // 星期标签
                  Text(
                    weekdayLabels[i],
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 10,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                      color: isToday
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  /// 构建双色堆叠柱体
  Widget _buildStackedBar({
    required double barHeight,
    required double inputRatio,
    required bool isToday,
  }) {
    final inputHeight = (barHeight * inputRatio).clamp(1.0, barHeight - 1);
    final outputHeight = barHeight - inputHeight;
    final alpha = isToday ? 1.0 : 0.3;

    return Container(
      height: barHeight,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      child: Column(
        children: [
          // 顶部：输出（deepPurple）
          Container(
            height: outputHeight,
            decoration: BoxDecoration(
              color: Colors.deepPurple.withValues(alpha: alpha),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(4),
              ),
            ),
          ),
          // 底部：输入（teal）
          Container(
            height: inputHeight,
            decoration: BoxDecoration(
              color: Colors.teal.withValues(alpha: alpha),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 格式化秒数为分钟显示（柱状图上方的数字）
  String _formatMinutes(int seconds) {
    final minutes = (seconds / 60).ceil();
    if (minutes < 60) return '${minutes}m';
    return '${minutes ~/ 60}h';
  }

  /// 星期几缩写
  String _weekdayShort(int weekday) {
    return switch (weekday) {
      1 => 'Mon',
      2 => 'Tue',
      3 => 'Wed',
      4 => 'Thu',
      5 => 'Fri',
      6 => 'Sat',
      7 => 'Sun',
      _ => '',
    };
  }
}

/// 格式化秒数为简短时间显示（用于 Chip）
///
/// 0 → "0分", < 60 → "< 1分", < 3600 → "N分", >= 3600 → "Nh Mm"
String _formatTimeShort(int seconds) {
  if (seconds <= 0) return '0分';
  final totalMinutes = (seconds / 60).ceil();
  if (totalMinutes < 60) return '$totalMinutes分';
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (minutes == 0) return '${hours}h';
  return '${hours}h${minutes}m';
}

/// 格式化词数显示
///
/// < 1000 → "856", >= 1000 → "1,234", >= 10000 → "12.3k"
String _formatWordCount(int count) {
  if (count >= 10000) {
    final k = count / 1000;
    return '${k.toStringAsFixed(1)}k';
  }
  if (count >= 1000) {
    final str = count.toString();
    return '${str.substring(0, str.length - 3)},${str.substring(str.length - 3)}';
  }
  return count.toString();
}

/// 格式化学习时长显示
String _formatTime(AppLocalizations l10n, int seconds) {
  final totalMinutes = (seconds / 60).ceil();
  if (totalMinutes <= 0) return l10n.studyTimeMinutes(0);
  if (totalMinutes < 60) return l10n.studyTimeMinutes(totalMinutes);
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  return l10n.studyTimeHoursMinutes(hours, minutes);
}
