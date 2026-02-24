/// 跟读设置底部弹窗
///
/// 支持配置每句循环次数和句间停顿模式（智能/固定/倍数）。
/// 所有修改即时生效（直接写回 Provider），设置仅对当次跟读有效。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../models/intensive_listen_settings.dart';
import '../../providers/learning_session/listen_and_repeat_player_provider.dart';
import '../../theme/app_theme.dart';

/// 显示跟读设置底部弹窗
void showListenAndRepeatSettingsSheet({required BuildContext context}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => const _ListenAndRepeatSettingsSheet(),
  );
}

/// 跟读设置面板（即时生效，无需确认按钮）
class _ListenAndRepeatSettingsSheet extends ConsumerWidget {
  const _ListenAndRepeatSettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final settings = ref.watch(
      listenAndRepeatPlayerProvider.select((s) => s.settings),
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l,
          AppSpacing.s,
          AppSpacing.l,
          AppSpacing.l,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 拖拽条
            Center(
              child: Container(
                width: 32,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.m),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.4,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // 标题
            Text(
              l10n.listenAndRepeatSettings,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),

            // 临时提示
            Text(
              l10n.listenAndRepeatSettingsTemporaryHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.l),

            // 每句循环次数
            _buildRepeatCountRow(l10n, theme, settings, ref),
            const SizedBox(height: AppSpacing.l),

            // 句间停顿
            Text(
              l10n.intensiveListenPauseLabel,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.s),

            // 模式切换
            _buildPauseModeSelector(l10n, settings, ref),
            const SizedBox(height: AppSpacing.m),

            // 模式详情
            _buildPauseModeDetail(l10n, theme, settings, ref),
          ],
        ),
      ),
    );
  }

  /// 每句循环次数选择行
  Widget _buildRepeatCountRow(
    AppLocalizations l10n,
    ThemeData theme,
    IntensiveListenSettings settings,
    WidgetRef ref,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(l10n.intensiveListenRepeatCount, style: theme.textTheme.bodyLarge),
        DropdownButton<int>(
          value: settings.repeatCount,
          underline: const SizedBox.shrink(),
          items: List.generate(10, (i) => i + 1).map((count) {
            return DropdownMenuItem(
              value: count,
              child: Text(l10n.intensiveListenRepeatCountValue(count)),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              ref
                  .read(listenAndRepeatPlayerProvider.notifier)
                  .updateSettings(settings.copyWith(repeatCount: value));
            }
          },
        ),
      ],
    );
  }

  /// 停顿模式切换（SegmentedButton）
  Widget _buildPauseModeSelector(
    AppLocalizations l10n,
    IntensiveListenSettings settings,
    WidgetRef ref,
  ) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<PauseMode>(
        segments: [
          ButtonSegment(
            value: PauseMode.smart,
            label: Text(l10n.intensiveListenPauseSmart),
          ),
          ButtonSegment(
            value: PauseMode.fixed,
            label: Text(l10n.intensiveListenPauseFixed),
          ),
          ButtonSegment(
            value: PauseMode.multiplier,
            label: Text(l10n.intensiveListenPauseMultiplierMode),
          ),
        ],
        selected: {settings.pauseMode},
        onSelectionChanged: (selected) {
          ref
              .read(listenAndRepeatPlayerProvider.notifier)
              .updateSettings(settings.copyWith(pauseMode: selected.first));
        },
      ),
    );
  }

  /// 停顿模式详情区域
  Widget _buildPauseModeDetail(
    AppLocalizations l10n,
    ThemeData theme,
    IntensiveListenSettings settings,
    WidgetRef ref,
  ) {
    switch (settings.pauseMode) {
      case PauseMode.smart:
        return Row(
          children: [
            Icon(
              Icons.info_outline,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                l10n.listenAndRepeatPauseSmartDesc,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        );

      case PauseMode.fixed:
        return Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: IntensiveListenSettings.fixedPauseOptions.map((seconds) {
            final isSelected = settings.fixedPauseSeconds == seconds;
            return ChoiceChip(
              label: Text(l10n.intensiveListenPauseFixedUnit(seconds)),
              selected: isSelected,
              onSelected: (_) {
                ref
                    .read(listenAndRepeatPlayerProvider.notifier)
                    .updateSettings(
                      settings.copyWith(fixedPauseSeconds: seconds),
                    );
              },
            );
          }).toList(),
        );

      case PauseMode.multiplier:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.intensiveListenPauseMultiplierLabel,
              style: theme.textTheme.bodyLarge,
            ),
            DropdownButton<double>(
              value: settings.pauseMultiplier,
              underline: const SizedBox.shrink(),
              items: IntensiveListenSettings.multiplierOptions.map((value) {
                return DropdownMenuItem(
                  value: value,
                  child: Text(
                    l10n.intensiveListenPauseMultiplierValue(
                      value.toStringAsFixed(
                        value == value.roundToDouble() ? 0 : 1,
                      ),
                    ),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  ref
                      .read(listenAndRepeatPlayerProvider.notifier)
                      .updateSettings(
                        settings.copyWith(pauseMultiplier: value),
                      );
                }
              },
            ),
          ],
        );
    }
  }
}
