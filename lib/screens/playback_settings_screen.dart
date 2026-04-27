/// 播放设置页面
///
/// 当前仅含：
/// - 自动跳过静音开关（默认开启）
/// - 静音阈值选择（开关开启时才显示，默认 2 秒）
///
/// 后续若有更多播放相关参数（速率、间隔等），都加在这里。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';

class PlaybackSettingsScreen extends ConsumerWidget {
  const PlaybackSettingsScreen({super.key});

  /// 阈值可选值（秒）
  static const _thresholdOptions = <int>[1, 2, 3, 5, 8, 10];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(appSettingsProvider);
    final controller = ref.read(appSettingsProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.playbackSettings)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.m),
        children: [
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: _emojiIcon('🤫'),
                  title: Text(l10n.skipSilenceTitle),
                  subtitle: Text(l10n.skipSilenceDescription),
                  value: settings.skipSilenceEnabled,
                  onChanged: controller.setSkipSilenceEnabled,
                ),
                if (settings.skipSilenceEnabled) ...[
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: _emojiIcon('⏱️'),
                    title: Text(l10n.silenceThreshold),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.silenceThresholdValue(
                            settings.silenceThresholdSeconds,
                          ),
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: () =>
                        _showThresholdDialog(context, settings, controller),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 阈值选择对话框
  Future<void> _showThresholdDialog(
    BuildContext context,
    AppSettingsState settings,
    AppSettings controller,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.silenceThreshold),
        contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final value in _thresholdOptions)
                _buildThresholdOption(
                  dialogContext,
                  l10n,
                  settings,
                  controller,
                  value,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThresholdOption(
    BuildContext context,
    AppLocalizations l10n,
    AppSettingsState settings,
    AppSettings controller,
    int seconds,
  ) {
    final isSelected = settings.silenceThresholdSeconds == seconds;
    return ListTile(
      leading: Icon(
        isSelected ? Icons.check_circle : Icons.circle_outlined,
        color: isSelected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.outline,
      ),
      title: Text(l10n.silenceThresholdValue(seconds)),
      selected: isSelected,
      onTap: () {
        if (!isSelected) {
          controller.setSilenceThresholdSeconds(seconds);
        }
        Navigator.pop(context);
      },
    );
  }

  Widget _emojiIcon(String emoji) {
    return SizedBox(
      width: 32,
      height: 32,
      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22))),
    );
  }
}
