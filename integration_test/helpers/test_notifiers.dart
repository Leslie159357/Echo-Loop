/// 集成测试专用 Notifier 替身和 App 工厂
///
/// 提供所有 Provider 的测试实现，以及 [createTestApp] 工厂函数。
/// 各测试 group 文件共享此模块，避免重复定义。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:fluency/main.dart';
import 'package:fluency/models/collection.dart';
import 'package:fluency/models/audio_engine_state.dart';
import 'package:fluency/providers/settings_provider.dart';
import 'package:fluency/providers/audio_library_provider.dart';
import 'package:fluency/providers/collection_provider.dart';
import 'package:fluency/providers/listening_practice/listening_practice_provider.dart';
import 'package:fluency/providers/audio_engine/audio_engine_provider.dart';
import 'package:fluency/providers/package_info_provider.dart';

// ========== 测试 Notifier ==========

class TestAppSettings extends AppSettings {
  @override
  AppSettingsState build() => const AppSettingsState();

  @override
  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
  }

  @override
  Future<void> setLocale(Locale locale) async {
    state = state.copyWith(locale: locale);
  }
}

class TestAudioLibrary extends AudioLibrary {
  @override
  AudioLibraryState build() => const AudioLibraryState();

  @override
  Future<void> loadLibrary() async {}
}

class TestCollectionList extends CollectionList {
  @override
  CollectionState build() => const CollectionState();

  @override
  Future<void> loadCollections() async {}

  @override
  Future<void> createCollection(String name) async {
    final collection = Collection(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      createdDate: DateTime.now(),
      sortOrder: state.rawCollections.length,
    );
    state = state.copyWith(
      rawCollections: [...state.rawCollections, collection],
    );
  }

  @override
  Future<void> deleteCollection(String id) async {
    state = state.copyWith(
      rawCollections: state.rawCollections.where((c) => c.id != id).toList(),
    );
  }

  @override
  Future<void> toggleStar(String id) async {
    final collections = [...state.rawCollections];
    final index = collections.indexWhere((c) => c.id == id);
    if (index != -1) {
      collections[index] = collections[index].copyWith(
        isStarred: !collections[index].isStarred,
      );
      state = state.copyWith(rawCollections: collections);
    }
  }
}

class TestListeningPractice extends ListeningPractice {
  @override
  ListeningPracticeState build() => const ListeningPracticeState();

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> setPlaylistMode(PlaylistMode mode) async {
    state = state.copyWith(playlistMode: mode);
  }

  @override
  Future<void> saveCurrentPlaybackState() async {}

  @override
  Future<void> updateSettings(dynamic newSettings) async {}
}

class TestAudioEngine extends AudioEngine {
  @override
  AudioEngineState build() => const AudioEngineState();

  @override
  bool get isPlaying => false;

  @override
  Duration get currentPosition => Duration.zero;

  @override
  Stream<Duration> get absolutePositionStream => Stream.value(Duration.zero);
}

// ========== App 工厂 ==========

final _testPackageInfo = PackageInfo(
  appName: 'Fluency',
  packageName: 'top.valuespot.fluency',
  version: '1.0.0',
  buildNumber: '1',
);

/// 创建集成测试用的 App，注入所有 Provider 测试替身
Widget createTestApp() {
  return ProviderScope(
    overrides: [
      appSettingsProvider.overrideWith(() => TestAppSettings()),
      audioLibraryProvider.overrideWith(() => TestAudioLibrary()),
      collectionListProvider.overrideWith(() => TestCollectionList()),
      listeningPracticeProvider.overrideWith(() => TestListeningPractice()),
      audioEngineProvider.overrideWith(() => TestAudioEngine()),
      packageInfoProvider.overrideWithValue(_testPackageInfo),
    ],
    child: const FluencyApp(),
  );
}
