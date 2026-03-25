/// 复述设置面板
///
/// 底部弹窗，即时生效，仅本次会话。
/// 设置项：控制模式 + 重复次数 + 段间停顿 + 可见词生成方式 + 可见词比例
/// UI 风格与跟读设置面板保持一致。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../models/intensive_listen_settings.dart'
    show PauseMode, ShadowingControlMode;
import '../../models/retell_settings.dart';
import '../../providers/learning_session/retell_player_provider.dart';
import '../../theme/app_theme.dart';

/// 显示复述设置面板
Future<void> showRetellSettingsSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => const _RetellSettingsSheet(),
  );
}

class _RetellSettingsSheet extends ConsumerWidget {
  const _RetellSettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final state = ref.watch(retellPlayerProvider);
    final settings = state.settings;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l, AppSpacing.s, AppSpacing.l, AppSpacing.l,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 拖拽指示条
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
              l10n.retellSettingsTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),

            // 本次生效提示
            Text(
              l10n.settingsSessionOnly,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.l),

            // ── 控制模式 ──
            _buildControlModeSection(l10n, theme, settings, ref),

            // 重复次数和段间停顿仅在自动模式下显示
            if (!settings.isManualMode) ...[
              const SizedBox(height: AppSpacing.l),

              // ── 重复次数 ──
              _buildRepeatCountRow(l10n, theme, settings, ref),
              const SizedBox(height: AppSpacing.l),

              // ── 段间停顿 ──
              Text(
                l10n.retellPauseMode,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.s),
              _buildPauseModeSelector(l10n, settings, ref),
              const SizedBox(height: AppSpacing.m),
              _buildPauseModeDetail(l10n, theme, settings, ref),
            ],
            const SizedBox(height: AppSpacing.l),

            // ── 可见词生成方式 ──
            Text(
              l10n.retellKeywordMethod,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<KeywordMethod>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: KeywordMethod.off,
                  label: Text(l10n.retellKeywordMethodOff),
                ),
                ButtonSegment(
                  value: KeywordMethod.random,
                  label: Text(l10n.retellKeywordMethodRandom),
                ),
                // TODO: AI 关键词提取功能尚未实现，暂时隐藏
                // ButtonSegment(
                //   value: KeywordMethod.ai,
                //   label: Tooltip(
                //     message: l10n.retellKeywordMethodAiComingSoon,
                //     child: Text(l10n.retellKeywordMethodAi),
                //   ),
                //   enabled: false,
                // ),
              ],
              selected: {settings.keywordMethod},
              onSelectionChanged: (selected) {
                ref.read(retellPlayerProvider.notifier).updateSettings(
                      settings.copyWith(keywordMethod: selected.first),
                    );
              },
            ),
            ),

            // 可见词比例（关闭时隐藏）
            if (settings.keywordMethod != KeywordMethod.off) ...[
              const SizedBox(height: AppSpacing.l),
              Text(
                l10n.retellKeywordRatio,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.s),
              _buildChipGrid(
                items: KeywordRatio.values,
                labelBuilder: (r) => '${r.numerator}/${r.denominator}',
                selected: (r) => settings.keywordRatio == r,
                onSelected: (r) => ref
                    .read(retellPlayerProvider.notifier)
                    .updateSettings(settings.copyWith(keywordRatio: r)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 控制模式选择区域（与跟读设置对齐：全宽 + 图标 + info 描述）
  Widget _buildControlModeSection(
    AppLocalizations l10n,
    ThemeData theme,
    RetellSettings settings,
    WidgetRef ref,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.listenAndRepeatControlModeLabel,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<ShadowingControlMode>(
            segments: [
              ButtonSegment(
                value: ShadowingControlMode.auto,
                label: Text(l10n.listenAndRepeatControlModeAuto),
                icon: const Icon(Icons.autorenew, size: 18),
              ),
              ButtonSegment(
                value: ShadowingControlMode.manual,
                label: Text(l10n.listenAndRepeatControlModeManual),
                icon: const Icon(Icons.touch_app, size: 18),
              ),
            ],
            selected: {settings.controlMode},
            onSelectionChanged: (selected) {
              ref.read(retellPlayerProvider.notifier).updateSettings(
                    settings.copyWith(controlMode: selected.first),
                  );
            },
            showSelectedIcon: false,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Icon(
              Icons.info_outline,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                settings.isManualMode
                    ? l10n.listenAndRepeatControlModeManualDesc
                    : l10n.listenAndRepeatControlModeAutoDesc,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 每段重复次数选择行
  Widget _buildRepeatCountRow(
    AppLocalizations l10n,
    ThemeData theme,
    RetellSettings settings,
    WidgetRef ref,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          l10n.retellRepeatCount,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        DropdownButton<int>(
          value: settings.repeatCount,
          underline: const SizedBox.shrink(),
          items: List.generate(5, (i) {
            final count = i + 1;
            return DropdownMenuItem(
              value: count,
              child: Text('$count'),
            );
          }),
          onChanged: (value) {
            if (value != null) {
              ref.read(retellPlayerProvider.notifier).updateSettings(
                    settings.copyWith(repeatCount: value),
                  );
            }
          },
        ),
      ],
    );
  }

  /// 停顿模式切换（全宽 SegmentedButton）
  Widget _buildPauseModeSelector(
    AppLocalizations l10n,
    RetellSettings settings,
    WidgetRef ref,
  ) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<PauseMode>(
        showSelectedIcon: false,
        segments: [
          ButtonSegment(
            value: PauseMode.smart,
            label: Text(l10n.pauseModeSmart),
          ),
          ButtonSegment(
            value: PauseMode.fixed,
            label: Text(l10n.pauseModeFixed),
          ),
          ButtonSegment(
            value: PauseMode.multiplier,
            label: Text(l10n.pauseModeMultiplier),
          ),
        ],
        selected: {settings.pauseMode},
        onSelectionChanged: (selected) {
          ref.read(retellPlayerProvider.notifier).updateSettings(
                settings.copyWith(pauseMode: selected.first),
              );
        },
      ),
    );
  }

  /// 停顿模式详情区域
  Widget _buildPauseModeDetail(
    AppLocalizations l10n,
    ThemeData theme,
    RetellSettings settings,
    WidgetRef ref,
  ) {
    return switch (settings.pauseMode) {
      PauseMode.smart => Row(
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
        ),
      PauseMode.fixed => _buildFixedPauseSlider(theme, settings, ref),
      PauseMode.multiplier => _buildChipGrid(
          items: RetellSettings.multiplierOptions,
          labelBuilder: (v) =>
              v == v.roundToDouble() ? '${v.toInt()}x' : '${v}x',
          selected: (v) => settings.pauseMultiplier == v,
          onSelected: (v) => ref
              .read(retellPlayerProvider.notifier)
              .updateSettings(settings.copyWith(pauseMultiplier: v)),
        ),
    };
  }

  /// 固定间隔滑块（索引映射，刻度清晰可见）
  Widget _buildFixedPauseSlider(
    ThemeData theme,
    RetellSettings settings,
    WidgetRef ref,
  ) {
    final options = RetellSettings.fixedPauseOptions;
    var idx = options.indexOf(settings.fixedPauseSeconds);
    if (idx < 0) idx = 2; // 回退到 30s
    return Row(
      children: [
        Expanded(
          child: Slider(
            value: idx.toDouble(),
            min: 0,
            max: (options.length - 1).toDouble(),
            divisions: options.length - 1,
            label: '${options[idx]}s',
            onChanged: (v) {
              ref.read(retellPlayerProvider.notifier).updateSettings(
                    settings.copyWith(
                      fixedPauseSeconds: options[v.round()],
                    ),
                  );
            },
          ),
        ),
        SizedBox(
          width: 42,
          child: Text(
            '${settings.fixedPauseSeconds}s',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  /// 等宽网格排列 ChoiceChip，每行 4 个
  Widget _buildChipGrid<T>({
    required List<T> items,
    required String Function(T) labelBuilder,
    required bool Function(T) selected,
    required void Function(T) onSelected,
  }) {
    const columns = 4;
    final rows = (items.length / columns).ceil();

    return Column(
      children: List.generate(rows, (row) {
        final start = row * columns;
        final end = (start + columns).clamp(0, items.length);
        final rowItems = items.sublist(start, end);

        return Padding(
          padding: EdgeInsets.only(top: row > 0 ? AppSpacing.xs : 0),
          child: Row(
            children: [
              for (var i = 0; i < columns; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: i < rowItems.length
                      ? ChoiceChip(
                          showCheckmark: false,
                          label: SizedBox(
                            width: double.infinity,
                            child: Text(
                              labelBuilder(rowItems[i]),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          selected: selected(rowItems[i]),
                          onSelected: (s) {
                            if (s) onSelected(rowItems[i]);
                          },
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        );
      }),
    );
  }
}
