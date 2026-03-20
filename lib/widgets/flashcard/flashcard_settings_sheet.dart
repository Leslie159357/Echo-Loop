/// Flashcard 设置底部弹窗
///
/// 支持设置控制模式、排序方式和倒计时模式。
/// 手动模式下隐藏自动相关选项（倒计时、自动播放）。
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/flashcard_settings.dart';
import '../../models/intensive_listen_settings.dart' show ShadowingControlMode;
import '../../theme/app_theme.dart';

/// 设置变更回调
typedef FlashcardSettingsCallback = void Function(FlashcardSettings settings);

/// Flashcard 设置弹窗
class FlashcardSettingsSheet extends StatefulWidget {
  /// 当前设置
  final FlashcardSettings settings;

  /// 设置变更回调
  final FlashcardSettingsCallback onSettingsChanged;

  const FlashcardSettingsSheet({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
  });

  @override
  State<FlashcardSettingsSheet> createState() => _FlashcardSettingsSheetState();
}

class _FlashcardSettingsSheetState extends State<FlashcardSettingsSheet> {
  late FlashcardSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
  }

  void _update(FlashcardSettings newSettings) {
    setState(() => _settings = newSettings);
    widget.onSettingsChanged(newSettings);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l,
          12,
          AppSpacing.l,
          AppSpacing.l,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 拖拽指示条
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 标题
            Text(
              l10n.flashcardSettingsTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),

            // 副标题
            Text(
              l10n.flashcardSettingsSubtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.l),

            // 控制模式
            Text(
              l10n.flashcardControlModeLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
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
                    label: Text(l10n.flashcardControlModeAuto),
                    icon: const Icon(Icons.autorenew, size: 16),
                  ),
                  ButtonSegment(
                    value: ShadowingControlMode.manual,
                    label: Text(l10n.flashcardControlModeManual),
                    icon: const Icon(Icons.pan_tool_outlined, size: 16),
                  ),
                ],
                selected: {_settings.controlMode},
                onSelectionChanged: (selected) {
                  _update(_settings.copyWith(controlMode: selected.first));
                },
                multiSelectionEnabled: false,
                showSelectedIcon: false,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            // 控制模式描述
            Text(
              _settings.isManualMode
                  ? l10n.flashcardControlModeManualDesc
                  : l10n.flashcardControlModeAutoDesc,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),

            // 以下仅自动模式可见
            if (!_settings.isManualMode) ...[
              const SizedBox(height: AppSpacing.l),

              // 单词切换时长
              Text(
                l10n.flashcardTimerMode,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.s),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<FlashcardTimerMode>(
                  segments: [
                    ButtonSegment(
                      value: FlashcardTimerMode.smart,
                      label: Text(l10n.flashcardTimerSmart),
                    ),
                    ButtonSegment(
                      value: FlashcardTimerMode.fixed,
                      label: Text(l10n.flashcardTimerFixed),
                    ),
                  ],
                  selected: {_settings.timerMode},
                  onSelectionChanged: (selected) {
                    _update(_settings.copyWith(timerMode: selected.first));
                  },
                  multiSelectionEnabled: false,
                  showSelectedIcon: false,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              // 切换时长描述
              Text(
                _settings.timerMode == FlashcardTimerMode.smart
                    ? l10n.flashcardTimerSmartDesc
                    : l10n.flashcardTimerFixedDesc,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),

              // 固定时间：正面 + 背面滑块
              if (_settings.timerMode == FlashcardTimerMode.fixed) ...[
                const SizedBox(height: AppSpacing.m),
                // 正面时长
                _TimerSlider(
                  label: l10n.flashcardTimerFrontDuration,
                  value: _settings.fixedTimerSeconds,
                  onChanged: (value) {
                    _update(
                      _settings.copyWith(fixedTimerSeconds: value),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.xs),
                // 背面时长
                _TimerSlider(
                  label: l10n.flashcardTimerBackDuration,
                  value: _settings.fixedTimerBackSeconds,
                  onChanged: (value) {
                    _update(
                      _settings.copyWith(fixedTimerBackSeconds: value),
                    );
                  },
                ),
              ],

            ],

            const SizedBox(height: AppSpacing.l),

            // 单词排序方式
            Text(
              l10n.flashcardSortMode,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<FlashcardSortMode>(
                segments: [
                  ButtonSegment(
                    value: FlashcardSortMode.random,
                    label: Text(l10n.flashcardSortRandom),
                  ),
                  ButtonSegment(
                    value: FlashcardSortMode.smart,
                    label: Text(l10n.flashcardSortSmart),
                  ),
                  ButtonSegment(
                    value: FlashcardSortMode.alphabeticalAsc,
                    label: Text(l10n.flashcardSortAlphaAsc),
                  ),
                ],
                selected: {_settings.sortMode},
                onSelectionChanged: (selected) {
                  _update(_settings.copyWith(sortMode: selected.first));
                },
                multiSelectionEnabled: false,
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  textStyle: theme.textTheme.bodySmall,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            // 第二行排序选项
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<FlashcardSortMode>(
                segments: [
                  ButtonSegment(
                    value: FlashcardSortMode.alphabeticalDesc,
                    label: Text(l10n.flashcardSortAlphaDesc),
                  ),
                  ButtonSegment(
                    value: FlashcardSortMode.timeAsc,
                    label: Text(l10n.flashcardSortTimeAsc),
                  ),
                  ButtonSegment(
                    value: FlashcardSortMode.timeDesc,
                    label: Text(l10n.flashcardSortTimeDesc),
                  ),
                ],
                selected: {_settings.sortMode},
                onSelectionChanged: (selected) {
                  _update(_settings.copyWith(sortMode: selected.first));
                },
                multiSelectionEnabled: false,
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  textStyle: theme.textTheme.bodySmall,
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.l),

            // 自动播放单词（不受控制模式影响）
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.flashcardAutoPlayWord,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Switch(
                  value: _settings.autoPlayWord,
                  onChanged: (value) {
                    _update(_settings.copyWith(autoPlayWord: value));
                  },
                ),
              ],
            ),

            // 自动播放例句（不受控制模式影响）
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.flashcardAutoPlaySentence,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Switch(
                  value: _settings.autoPlaySentence,
                  onChanged: (value) {
                    _update(_settings.copyWith(autoPlaySentence: value));
                  },
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.m),
          ],
        ),
      ),
    );
  }
}

/// 固定时长滑块（带标签和数值显示）
class _TimerSlider extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const _TimerSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            min: FlashcardSettings.fixedTimerOptions.first.toDouble(),
            max: FlashcardSettings.fixedTimerOptions.last.toDouble(),
            divisions: FlashcardSettings.fixedTimerOptions.last -
                FlashcardSettings.fixedTimerOptions.first,
            label: '${value}s',
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            '${value}s',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
