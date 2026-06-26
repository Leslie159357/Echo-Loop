/// 句间停顿分组下拉
///
/// 入口弹窗用,与播放器内 🔧 面板的「句间停顿」选项完全一致:单个下拉,但分三组
/// 显示——自动 / 固定间隔(各秒数) / 句长倍数(各倍数)。避免「一处能选、另一处
/// 选不到」的不一致。组标题用不可选项(`enabled: false`)呈现。
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/stage_settings_overrides.dart' show BriefingPauseChoice;

/// 分组停顿下拉。
///
/// [fixedOptions] / [multiplierOptions] 应与对应子阶段 🔧 面板一致。
class PauseChoiceDropdown extends StatelessWidget {
  const PauseChoiceDropdown({
    super.key,
    required this.value,
    required this.fixedOptions,
    required this.multiplierOptions,
    required this.onChanged,
  });

  /// 当前选中的停顿配置(须落在可选档位内)。
  final BriefingPauseChoice value;

  /// 固定间隔可选秒数。
  final List<int> fixedOptions;

  /// 句长倍数可选档位。
  final List<double> multiplierOptions;

  /// 选择回调。
  final ValueChanged<BriefingPauseChoice> onChanged;

  /// 倍数标签:整数去尾零,与 🔧 面板一致(如 1倍 / 1.5倍）。
  String _multiplierLabel(AppLocalizations l10n, double m) {
    final text = m.toStringAsFixed(m == m.roundToDouble() ? 0 : 1);
    return l10n.intensiveListenPauseMultiplierValue(text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final headerStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.4,
    );

    // 组标题用通栏背景色带呈现,与下方可选项形成视觉分隔。
    // DropdownMenuItem 自带 16px 水平内边距,用 OverflowBox 撑出 ±16 让色带通栏。
    DropdownMenuItem<BriefingPauseChoice> header(String text) =>
        DropdownMenuItem<BriefingPauseChoice>(
          enabled: false,
          value: null,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bleed = constraints.maxWidth.isFinite
                  ? constraints.maxWidth + 32
                  : double.infinity;
              return OverflowBox(
                minWidth: bleed,
                maxWidth: bleed,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Text(text, style: headerStyle),
                ),
              );
            },
          ),
        );

    final items = <DropdownMenuItem<BriefingPauseChoice>>[
      DropdownMenuItem(
        value: const BriefingPauseChoice.smart(),
        child: Text(l10n.intensiveListenPauseSmart),
      ),
      if (fixedOptions.isNotEmpty) ...[
        header(l10n.intensiveListenPauseFixed),
        ...fixedOptions.map(
          (s) => DropdownMenuItem(
            value: BriefingPauseChoice.fixed(s),
            child: Text('${s}s'),
          ),
        ),
      ],
      if (multiplierOptions.isNotEmpty) ...[
        header(l10n.intensiveListenPauseMultiplierMode),
        ...multiplierOptions.map(
          (m) => DropdownMenuItem(
            value: BriefingPauseChoice.multiplier(m),
            child: Text(_multiplierLabel(l10n, m)),
          ),
        ),
      ],
    ];

    return DropdownButton<BriefingPauseChoice>(
      value: value,
      items: items,
      isExpanded: true,
      isDense: true,
      underline: const SizedBox.shrink(),
      borderRadius: BorderRadius.circular(12),
      dropdownColor: theme.colorScheme.surface,
      elevation: 8,
      style: theme.textTheme.bodyMedium,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      icon: const Icon(Icons.arrow_drop_down),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}
