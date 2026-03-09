/// Flashcard 设置底部弹窗
///
/// 支持设置排序方式和倒计时模式。
/// 复用 DifficultPracticeSettingsSheet 的 UI 模式。
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/flashcard_settings.dart';
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
            const SizedBox(height: AppSpacing.l),

            // 排序方式
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
                style: SegmentedButton.styleFrom(
                  textStyle: theme.textTheme.bodySmall,
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.l),

            // 倒计时模式
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
                    value: FlashcardTimerMode.fixed,
                    label: Text(l10n.flashcardTimerFixed),
                  ),
                  ButtonSegment(
                    value: FlashcardTimerMode.smart,
                    label: Text(l10n.flashcardTimerSmart),
                  ),
                  ButtonSegment(
                    value: FlashcardTimerMode.off,
                    label: Text(l10n.flashcardTimerOff),
                  ),
                ],
                selected: {_settings.timerMode},
                onSelectionChanged: (selected) {
                  _update(_settings.copyWith(timerMode: selected.first));
                },
                multiSelectionEnabled: false,
              ),
            ),

            // 固定时间滑块
            if (_settings.timerMode == FlashcardTimerMode.fixed) ...[
              const SizedBox(height: AppSpacing.m),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _settings.fixedTimerSeconds.toDouble(),
                      min: FlashcardSettings.fixedTimerOptions.first.toDouble(),
                      max: FlashcardSettings.fixedTimerOptions.last.toDouble(),
                      divisions:
                          FlashcardSettings.fixedTimerOptions.last -
                          FlashcardSettings.fixedTimerOptions.first,
                      label: '${_settings.fixedTimerSeconds}s',
                      onChanged: (value) {
                        _update(
                          _settings.copyWith(fixedTimerSeconds: value.round()),
                        );
                      },
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '${_settings.fixedTimerSeconds}s',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: AppSpacing.l),

            // 自动播放例句
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
