/// 提醒设置页面
///
/// 独立页面，控制收藏复习提醒（开关 + 时间选择）和
/// 音频复习提醒（开关），通过 [ReminderSettingsNotifier] 持久化。
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../models/reminder_settings.dart';
import '../providers/reminder_settings_provider.dart';
import '../theme/app_theme.dart';

/// 分钟可选值（15 分钟间隔）
const _minuteOptions = [0, 15, 30, 45];

/// 提醒设置页面
class ReminderSettingsScreen extends ConsumerWidget {
  const ReminderSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(reminderSettingsNotifierProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.reminderSettings)),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.m,
          vertical: AppSpacing.s,
        ),
        children: [
          // ── 收藏复习提醒 ──
          _SectionHeader(title: l10n.savedReviewReminderSection),
          Card(
            child: Column(
              children: [
                // 开关行
                _SwitchRow(
                  icon: Icons.notifications_active_outlined,
                  iconColor: colorScheme.primary,
                  title: l10n.savedReviewReminderToggle,
                  value: settings.savedReviewReminderEnabled,
                  onChanged: (v) => _update(ref, settings.copyWith(
                    savedReviewReminderEnabled: v,
                  )),
                ),
                // 开关开启时显示时间选择
                if (settings.savedReviewReminderEnabled) ...[
                  const Divider(height: 1, indent: 56),
                  _TimeRow(
                    title: l10n.savedReviewReminderTime,
                    formattedTime: settings.formattedTime,
                    onTap: () => _showTimePickerSheet(
                      context, ref, settings,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // 说明文字
          _DescriptionText(text: l10n.savedReviewReminderDescription),

          const SizedBox(height: AppSpacing.l),

          // ── 复习到期提醒 ──
          _SectionHeader(title: l10n.audioReviewReminderSection),
          Card(
            child: _SwitchRow(
              icon: Icons.event_repeat_outlined,
              iconColor: colorScheme.primary,
              title: l10n.audioReviewReminderToggle,
              value: settings.perAudioReminderEnabled,
              onChanged: (v) => _update(ref, settings.copyWith(
                perAudioReminderEnabled: v,
              )),
            ),
          ),
          _DescriptionText(text: l10n.audioReviewReminderDescription),
        ],
      ),
    );
  }

  void _update(WidgetRef ref, ReminderSettings settings) {
    ref.read(reminderSettingsNotifierProvider.notifier).update(settings);
  }

  /// 底部弹窗时间选择器（双列滚轮：小时 0-23 + 分钟 0/15/30/45）
  Future<void> _showTimePickerSheet(
    BuildContext context,
    WidgetRef ref,
    ReminderSettings settings,
  ) async {
    var selectedHour = settings.savedReviewReminderHour;
    var selectedMinuteIndex = _nearestMinuteIndex(settings.savedReviewReminderMinute);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return _TimePickerSheet(
          initialHour: selectedHour,
          initialMinuteIndex: selectedMinuteIndex,
          onChanged: (hour, minuteIndex) {
            selectedHour = hour;
            selectedMinuteIndex = minuteIndex;
          },
        );
      },
    );

    final newMinute = _minuteOptions[selectedMinuteIndex];
    if (selectedHour != settings.savedReviewReminderHour ||
        newMinute != settings.savedReviewReminderMinute) {
      ref.read(reminderSettingsNotifierProvider.notifier).update(
        settings.copyWith(
          savedReviewReminderHour: selectedHour,
          savedReviewReminderMinute: newMinute,
        ),
      );
    }
  }

  /// 找到最接近 [minute] 的可选分钟索引
  static int _nearestMinuteIndex(int minute) {
    var bestIndex = 0;
    var bestDiff = 60;
    for (var i = 0; i < _minuteOptions.length; i++) {
      final diff = (minute - _minuteOptions[i]).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        bestIndex = i;
      }
    }
    return bestIndex;
  }
}

// ─────────────────────────────────────────────────────────
// 子组件
// ─────────────────────────────────────────────────────────

/// Section 标题
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.m, AppSpacing.s, AppSpacing.m, AppSpacing.s,
      ),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// 带图标的开关行
class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: iconColor),
      ),
      title: Text(title),
      value: value,
      onChanged: onChanged,
    );
  }
}

/// 时间选择行
class _TimeRow extends StatelessWidget {
  final String title;
  final String formattedTime;
  final VoidCallback onTap;

  const _TimeRow({
    required this.title,
    required this.formattedTime,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 72, right: 20),
      title: Text(title),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          formattedTime,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      onTap: onTap,
    );
  }
}

/// Section 下方灰色说明文字
class _DescriptionText extends StatelessWidget {
  final String text;
  const _DescriptionText({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.m + AppSpacing.xs, AppSpacing.s,
        AppSpacing.m, 0,
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// 时间选择器底部弹窗
// ─────────────────────────────────────────────────────────

const double _kItemExtent = 40;

/// 双列滚轮时间选择器
class _TimePickerSheet extends StatefulWidget {
  final int initialHour;
  final int initialMinuteIndex;
  final void Function(int hour, int minuteIndex) onChanged;

  const _TimePickerSheet({
    required this.initialHour,
    required this.initialMinuteIndex,
    required this.onChanged,
  });

  @override
  State<_TimePickerSheet> createState() => _TimePickerSheetState();
}

class _TimePickerSheetState extends State<_TimePickerSheet> {
  late final FixedExtentScrollController _hourController;
  late final FixedExtentScrollController _minuteController;
  late int _selectedHour;
  late int _selectedMinuteIndex;

  @override
  void initState() {
    super.initState();
    _selectedHour = widget.initialHour;
    _selectedMinuteIndex = widget.initialMinuteIndex;
    _hourController = FixedExtentScrollController(
      initialItem: _selectedHour,
    );
    _minuteController = FixedExtentScrollController(
      initialItem: _selectedMinuteIndex,
    );
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l, AppSpacing.s, AppSpacing.l, AppSpacing.l,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 拖拽把手
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            const SizedBox(height: AppSpacing.s),
            // 滚轮 + 选中行高亮条
            SizedBox(
              height: _kItemExtent * 5,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 选中行背景条（横跨整个宽度）
                  Container(
                    height: _kItemExtent,
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  // 滚轮
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 小时列
                      SizedBox(
                        width: 90,
                        child: CupertinoPicker.builder(
                          scrollController: _hourController,
                          itemExtent: _kItemExtent,
                          diameterRatio: 1.5,
                          squeeze: 1.0,
                          selectionOverlay: const SizedBox.shrink(),
                          onSelectedItemChanged: (index) {
                            setState(() => _selectedHour = index);
                            widget.onChanged(
                              _selectedHour, _selectedMinuteIndex,
                            );
                          },
                          itemBuilder: (_, index) => Center(
                            child: Text(
                              index.toString().padLeft(2, '0'),
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: index == _selectedHour
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: index == _selectedHour
                                    ? colorScheme.onSurface
                                    : colorScheme.onSurface
                                        .withValues(alpha: 0.35),
                              ),
                            ),
                          ),
                          childCount: 24,
                        ),
                      ),
                      // 冒号
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          ':',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                      // 分钟列
                      SizedBox(
                        width: 90,
                        child: CupertinoPicker.builder(
                          scrollController: _minuteController,
                          itemExtent: _kItemExtent,
                          diameterRatio: 1.5,
                          squeeze: 1.0,
                          selectionOverlay: const SizedBox.shrink(),
                          onSelectedItemChanged: (index) {
                            setState(() => _selectedMinuteIndex = index);
                            widget.onChanged(
                              _selectedHour, _selectedMinuteIndex,
                            );
                          },
                          itemBuilder: (_, index) => Center(
                            child: Text(
                              _minuteOptions[index]
                                  .toString()
                                  .padLeft(2, '0'),
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: index == _selectedMinuteIndex
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: index == _selectedMinuteIndex
                                    ? colorScheme.onSurface
                                    : colorScheme.onSurface
                                        .withValues(alpha: 0.35),
                              ),
                            ),
                          ),
                          childCount: _minuteOptions.length,
                        ),
                      ),
                    ],
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
