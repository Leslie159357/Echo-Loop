/// 学习设置页面
///
/// 控制全局学习行为偏好，本期只支持「自动跳过复述」开关。
/// 默认关闭：复述类子阶段照常参与计划，用户在简报弹窗里可手动跳过。
/// 开启后：所有推进到复述子阶段的位置都自动调用 `skipCurrentSubStage`，
/// 效果与用户手动点跳过一致。设置切换瞬间会触发对所有 progress 的扫描，
/// 把当前停在复述位置的音频立刻推进。自由练习入口不受影响。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analytics/analytics_providers.dart';
import '../analytics/models/event_names.dart';
import '../l10n/app_localizations.dart';
import '../providers/learning_progress_provider.dart';
import '../providers/learning_settings_provider.dart';
import '../theme/app_theme.dart';

/// 学习设置页面
class LearningSettingsScreen extends ConsumerWidget {
  const LearningSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(learningSettingsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.learningSettings)),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.m,
          vertical: AppSpacing.s,
        ),
        children: [
          Card(
            child: SwitchListTile(
              secondary: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.auto_awesome,
                  size: 20,
                  color: colorScheme.primary,
                ),
              ),
              title: Text(l10n.autoExpandCachedAnnotationToggle),
              subtitle: Text(
                l10n.autoExpandCachedAnnotationSubtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
              value: settings.autoExpandCachedAnnotation,
              onChanged: (value) async {
                await ref
                    .read(learningSettingsProvider.notifier)
                    .setAutoExpandCachedAnnotation(value);
              },
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          Card(
            child: SwitchListTile(
              secondary: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.chat, size: 20, color: colorScheme.primary),
              ),
              title: Text(l10n.autoSkipRetellToggle),
              subtitle: Text(
                l10n.autoSkipRetellSubtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
              value: settings.autoSkipRetell,
              onChanged: (value) async {
                await ref
                    .read(learningSettingsProvider.notifier)
                    .setAutoSkipRetell(value);
                if (value) {
                  await ref
                      .read(learningProgressNotifierProvider.notifier)
                      .triggerAutoSkipScan();
                }
                ref.read(analyticsServiceProvider).track(
                  Events.retellToggleChanged,
                  {
                    EventParams.enabled: value,
                    EventParams.source: 'settings_page',
                  },
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          Card(
            child: SwitchListTile(
              secondary: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.record_voice_over,
                  size: 20,
                  color: colorScheme.primary,
                ),
              ),
              title: Text(l10n.autoPlayRetellRecordingToggle),
              subtitle: Text(
                l10n.autoPlayRetellRecordingSubtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
              value: settings.autoPlayRetellRecordingAfterCompletion,
              onChanged: (value) async {
                final notifier = ref.read(learningSettingsProvider.notifier);
                await notifier.setAutoPlayRetellRecordingAfterCompletion(value);
                // 在设置页显式配置过（开或关）即视为已知晓该功能，
                // 不再弹复述完成后的首次提示。
                await notifier.markRetellAutoPlaybackPromptShown();
              },
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          Card(
            child: SwitchListTile(
              secondary: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.speed_rounded,
                  size: 20,
                  color: colorScheme.primary,
                ),
              ),
              title: Text(l10n.retellRatingToggle),
              subtitle: Text(
                l10n.retellRatingSubtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
              value: settings.retellRatingEnabled,
              onChanged: (value) async {
                await ref
                    .read(learningSettingsProvider.notifier)
                    .setRetellRatingEnabled(value);
              },
            ),
          ),
        ],
      ),
    );
  }
}
