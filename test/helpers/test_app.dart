/// 通用测试包装器
///
/// 提供 `createTestApp` 辅助函数，将被测 Widget 包装在
/// ProviderScope + MaterialApp（含 localization delegates）中。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:fluency/l10n/app_localizations.dart';
import 'package:fluency/providers/settings_provider.dart';
import 'package:fluency/providers/audio_library_provider.dart';
import 'package:fluency/providers/collection_provider.dart';
import 'package:fluency/providers/listening_practice/listening_practice_provider.dart';
import 'package:fluency/providers/audio_engine/audio_engine_provider.dart';

import 'mock_providers.dart';

/// 创建测试用 App 包装器
///
/// 自动注入所有 Provider 的测试替身，可通过 [overrides] 覆盖。
/// [locale] 默认为英文，可切换为中文测试国际化。
/// [size] 用于设置窗口大小模拟不同设备。
Widget createTestApp(
  Widget child, {
  List<Override>? overrides,
  Locale locale = const Locale('en'),
  ThemeMode themeMode = ThemeMode.light,
}) {
  // 默认 overrides：所有 Provider 使用测试替身
  final defaultOverrides = <Override>[
    appSettingsProvider.overrideWith(
      () => TestAppSettings(
        AppSettingsState(themeMode: themeMode, locale: locale),
      ),
    ),
    audioLibraryProvider.overrideWith(() => TestAudioLibrary()),
    collectionListProvider.overrideWith(() => TestCollectionList()),
    listeningPracticeProvider.overrideWith(() => TestListeningPractice()),
    audioEngineProvider.overrideWith(() => TestAudioEngine()),
  ];

  return ProviderScope(
    overrides: overrides ?? defaultOverrides,
    child: MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('zh')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: Scaffold(body: child),
    ),
  );
}

/// 创建包含 Scaffold 的测试 App（用于测试需要 Scaffold 上下文的 Screen）
Widget createTestScreen(
  Widget screen, {
  List<Override>? overrides,
  Locale locale = const Locale('en'),
}) {
  final defaultOverrides = <Override>[
    appSettingsProvider.overrideWith(
      () => TestAppSettings(AppSettingsState(locale: locale)),
    ),
    audioLibraryProvider.overrideWith(() => TestAudioLibrary()),
    collectionListProvider.overrideWith(() => TestCollectionList()),
    listeningPracticeProvider.overrideWith(() => TestListeningPractice()),
    audioEngineProvider.overrideWith(() => TestAudioEngine()),
  ];

  return ProviderScope(
    overrides: overrides ?? defaultOverrides,
    child: MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('zh')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: screen,
      routes: {
        '/player': (context) => const Scaffold(body: Text('Player')),
        '/settings': (context) => const Scaffold(body: Text('Settings')),
      },
    ),
  );
}
