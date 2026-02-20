/// 核心流程 E2E 集成测试
///
/// 在真实 Flutter 引擎上运行完整用户流程。
/// Mock StorageService 避免文件系统依赖。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
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

// ========== 测试 Notifier（集成测试专用） ==========

class _TestAppSettings extends AppSettings {
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

class _TestAudioLibrary extends AudioLibrary {
  @override
  AudioLibraryState build() => const AudioLibraryState();

  @override
  Future<void> loadLibrary() async {}
}

class _TestCollectionList extends CollectionList {
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

class _TestListeningPractice extends ListeningPractice {
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

class _TestAudioEngine extends AudioEngine {
  @override
  AudioEngineState build() => const AudioEngineState();

  @override
  bool get isPlaying => false;

  @override
  Duration get currentPosition => Duration.zero;

  @override
  Stream<Duration> get absolutePositionStream => Stream.value(Duration.zero);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final testPackageInfo = PackageInfo(
    appName: 'Fluency',
    packageName: 'top.valuespot.fluency',
    version: '1.0.0',
    buildNumber: '1',
  );

  /// 创建集成测试用的 App
  Widget createTestApp() {
    return ProviderScope(
      overrides: [
        appSettingsProvider.overrideWith(() => _TestAppSettings()),
        audioLibraryProvider.overrideWith(() => _TestAudioLibrary()),
        collectionListProvider.overrideWith(() => _TestCollectionList()),
        listeningPracticeProvider.overrideWith(
          () => _TestListeningPractice(),
        ),
        audioEngineProvider.overrideWith(() => _TestAudioEngine()),
      ],
      child: FluencyApp(packageInfo: testPackageInfo),
    );
  }

  group('流程 1：App 启动与导航', () {
    testWidgets('App 正常启动，显示 Audio Library', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // 默认显示 Audio Library 页面
      expect(find.text('Audio Library'), findsOneWidget);
    });

    testWidgets('点击各导航切换页面', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // 切换到合集页
      await tester.tap(find.text('Collections'));
      await tester.pumpAndSettle();
      expect(find.text('No collections yet'), findsOneWidget);

      // 切换到播放器页
      await tester.tap(find.text('Player'));
      await tester.pumpAndSettle();
      expect(find.text('No audio loaded'), findsOneWidget);

      // 切换到设置页
      await tester.tap(find.text('Account'));
      await tester.pumpAndSettle();
      expect(find.text('Appearance'), findsOneWidget);

      // 切换回音频库页
      await tester.tap(find.text('Library'));
      await tester.pumpAndSettle();
      expect(find.text('No audio files yet'), findsOneWidget);
    });
  });

  group('流程 2：设置修改', () {
    testWidgets('切换主题', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // 进入设置页
      await tester.tap(find.text('Account'));
      await tester.pumpAndSettle();

      // 点击主题设置
      await tester.tap(find.text('Theme Mode'));
      await tester.pumpAndSettle();

      // 选择 Dark 主题
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();

      // 验证设置已更新为 Dark
      expect(find.text('Dark'), findsOneWidget);
    });

    testWidgets('切换语言', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // 进入设置页
      await tester.tap(find.text('Account'));
      await tester.pumpAndSettle();

      // 点击语言设置
      await tester.tap(find.text('Language'));
      await tester.pumpAndSettle();

      // 选择中文
      await tester.tap(find.text('Chinese'));
      await tester.pumpAndSettle();

      // 语言切换后 UI 文案应变为中文
      expect(find.text('中文'), findsOneWidget);
    });
  });

  group('流程 3：合集管理', () {
    testWidgets('创建合集并验证出现在列表中', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // 进入合集页
      await tester.tap(find.text('Collections'));
      await tester.pumpAndSettle();

      // 初始为空状态
      expect(find.text('No collections yet'), findsOneWidget);

      // 点击创建按钮
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // 输入合集名称
      await tester.enterText(find.byType(TextField), 'My Collection');
      await tester.pumpAndSettle();

      // 点击添加
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      // 合集应出现在列表中
      expect(find.text('My Collection'), findsOneWidget);
      // 空状态应消失
      expect(find.text('No collections yet'), findsNothing);
    });
  });
}
