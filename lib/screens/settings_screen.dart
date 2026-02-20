import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../l10n/app_localizations.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  final PackageInfo? packageInfo;

  const SettingsScreen({super.key, this.packageInfo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(appSettingsProvider);
    final settingsController = ref.read(appSettingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        children: [
          _buildSection(
            context,
            title: l10n.appearance,
            children: [
              _buildThemeModeTile(context, l10n, settings, settingsController),
              _buildLanguageTile(context, l10n, settings, settingsController),
            ],
          ),
          const Divider(height: 32),
          _buildSection(
            context,
            title: l10n.about,
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(l10n.version),
                subtitle: Text(packageInfo?.version ?? ''),
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(l10n.appDescription),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...children,
      ],
    );
  }

  Widget _buildThemeModeTile(
    BuildContext context,
    AppLocalizations l10n,
    AppSettingsState settings,
    AppSettings controller,
  ) {
    return ListTile(
      leading: Icon(_getThemeIcon(settings.themeMode)),
      title: Text(l10n.themeMode),
      subtitle: Text(_getThemeModeName(l10n, settings.themeMode)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showThemeModeDialog(context, l10n, settings, controller),
    );
  }

  Widget _buildLanguageTile(
    BuildContext context,
    AppLocalizations l10n,
    AppSettingsState settings,
    AppSettings controller,
  ) {
    return ListTile(
      leading: const Icon(Icons.language),
      title: Text(l10n.language),
      subtitle: Text(_getLanguageName(l10n, settings.locale)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showLanguageDialog(context, l10n, settings, controller),
    );
  }

  IconData _getThemeIcon(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => Icons.light_mode,
      ThemeMode.dark => Icons.dark_mode,
      ThemeMode.system => Icons.brightness_auto,
    };
  }

  String _getThemeModeName(AppLocalizations l10n, ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => l10n.themeModeLight,
      ThemeMode.dark => l10n.themeModeDark,
      ThemeMode.system => l10n.themeModeSystem,
    };
  }

  String _getLanguageName(AppLocalizations l10n, Locale locale) {
    return switch (locale.languageCode) {
      'zh' => l10n.languageChinese,
      _ => l10n.languageEnglish,
    };
  }

  void _showThemeModeDialog(
    BuildContext context,
    AppLocalizations l10n,
    AppSettingsState settings,
    AppSettings controller,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.themeMode),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildThemeOption(
              context, l10n, settings, controller,
              ThemeMode.system, Icons.brightness_auto, l10n.themeModeSystem,
            ),
            _buildThemeOption(
              context, l10n, settings, controller,
              ThemeMode.light, Icons.light_mode, l10n.themeModeLight,
            ),
            _buildThemeOption(
              context, l10n, settings, controller,
              ThemeMode.dark, Icons.dark_mode, l10n.themeModeDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    AppLocalizations l10n,
    AppSettingsState settings,
    AppSettings controller,
    ThemeMode mode,
    IconData icon,
    String label,
  ) {
    final isSelected = settings.themeMode == mode;
    return ListTile(
      leading: Radio<ThemeMode>(
        value: mode,
        groupValue: settings.themeMode,
        onChanged: (value) {
          if (value != null) {
            controller.setThemeMode(value);
            Navigator.pop(context);
          }
        },
      ),
      title: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
      selected: isSelected,
      onTap: () {
        controller.setThemeMode(mode);
        Navigator.pop(context);
      },
    );
  }

  void _showLanguageDialog(
    BuildContext context,
    AppLocalizations l10n,
    AppSettingsState settings,
    AppSettings controller,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.language),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLanguageOption(
              context, l10n, settings, controller,
              const Locale('en'), l10n.languageEnglish,
            ),
            _buildLanguageOption(
              context, l10n, settings, controller,
              const Locale('zh'), l10n.languageChinese,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(
    BuildContext context,
    AppLocalizations l10n,
    AppSettingsState settings,
    AppSettings controller,
    Locale locale,
    String label,
  ) {
    final isSelected = settings.locale == locale;
    return ListTile(
      leading: Radio<Locale>(
        value: locale,
        groupValue: settings.locale,
        onChanged: (value) {
          if (value != null) {
            controller.setLocale(value);
            Navigator.pop(context);
          }
        },
      ),
      title: Text(label),
      selected: isSelected,
      onTap: () {
        controller.setLocale(locale);
        Navigator.pop(context);
      },
    );
  }
}
