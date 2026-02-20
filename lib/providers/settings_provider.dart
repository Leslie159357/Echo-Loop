import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'settings_provider.g.dart';

class AppSettingsState {
  final ThemeMode themeMode;
  final Locale locale;

  const AppSettingsState({
    this.themeMode = ThemeMode.system,
    this.locale = const Locale('en'),
  });

  AppSettingsState copyWith({
    ThemeMode? themeMode,
    Locale? locale,
  }) {
    return AppSettingsState(
      themeMode: themeMode ?? this.themeMode,
      locale: locale ?? this.locale,
    );
  }
}

@Riverpod(keepAlive: true)
class AppSettings extends _$AppSettings {
  @override
  AppSettingsState build() {
    _loadSettings();
    return const AppSettingsState();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final themeModeString = prefs.getString('theme_mode') ?? 'system';
    final themeMode = switch (themeModeString) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    final localeString = prefs.getString('locale') ?? 'en';
    final locale = Locale(localeString);

    state = state.copyWith(themeMode: themeMode, locale: locale);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);

    final prefs = await SharedPreferences.getInstance();
    final modeString = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await prefs.setString('theme_mode', modeString);
  }

  Future<void> setLocale(Locale locale) async {
    state = state.copyWith(locale: locale);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('locale', locale.languageCode);
  }
}
