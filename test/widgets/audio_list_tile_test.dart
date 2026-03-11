import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluency/providers/audio_library_provider.dart';
import 'package:fluency/providers/audio_engine/audio_engine_provider.dart';
import 'package:fluency/providers/collection_provider.dart';
import 'package:fluency/providers/learning_progress_provider.dart';
import 'package:fluency/providers/learning_session/blind_listen_player_provider.dart';
import 'package:fluency/providers/learning_session/learning_session_provider.dart';
import 'package:fluency/providers/listening_practice/listening_practice_provider.dart';
import 'package:fluency/providers/settings_provider.dart';
import 'package:fluency/providers/tag_provider.dart';
import 'package:fluency/theme/app_theme.dart';
import 'package:fluency/widgets/audio_list_tile.dart';

import '../helpers/mock_providers.dart';
import '../helpers/test_app.dart';

/// 包装器：从 Provider 读取第一个音频项，传给 AudioListTile
/// 模拟真实场景中父组件 watch provider → 传 item 给子组件的模式
class _AudioListTileWrapper extends ConsumerWidget {
  const _AudioListTileWrapper();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(
      audioLibraryProvider.select((s) => s.audioItems),
    );
    if (items.isEmpty) return const SizedBox.shrink();
    return AudioListTile(audioItem: items.first);
  }
}

void main() {
  group('AudioListTile 星标功能', () {
    final baseItem = createTestAudioItem(id: 'star-1', name: 'Star Audio');

    Widget buildTile(AudioLibraryState libraryState) {
      return createTestApp(
        const _AudioListTileWrapper(),
        overrides: [
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(libraryState),
          ),
        ],
      );
    }

    testWidgets('未星标时显示 star_border 图标', (tester) async {
      await tester.pumpWidget(
        buildTile(AudioLibraryState(audioItems: [baseItem])),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.star_border), findsOneWidget);
      expect(find.byIcon(Icons.star), findsNothing);
    });

    testWidgets('已星标时显示 star 图标', (tester) async {
      final starredItem = baseItem.copyWith(isStarred: true);
      await tester.pumpWidget(
        buildTile(AudioLibraryState(audioItems: [starredItem])),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(find.byIcon(Icons.star_border), findsNothing);
    });

    testWidgets('未星标时星标图标为灰色', (tester) async {
      await tester.pumpWidget(
        buildTile(AudioLibraryState(audioItems: [baseItem])),
      );
      await tester.pumpAndSettle();

      final icon = tester.widget<Icon>(find.byIcon(Icons.star_border));
      // 未星标使用 onSurfaceVariant 灰色，不是 bookmarkColor
      expect(icon.color, isNot(AppTheme.bookmarkColor));
    });

    testWidgets('已星标时星标图标使用 bookmarkColor', (tester) async {
      final starredItem = baseItem.copyWith(isStarred: true);
      await tester.pumpWidget(
        buildTile(AudioLibraryState(audioItems: [starredItem])),
      );
      await tester.pumpAndSettle();

      final icon = tester.widget<Icon>(find.byIcon(Icons.star));
      expect(icon.color, AppTheme.bookmarkColor);
    });

    testWidgets('已星标时 leading 音频图标颜色不受星标影响（显示进度状态）',
        (tester) async {
      final starredItem = baseItem.copyWith(isStarred: true);
      await tester.pumpWidget(
        buildTile(AudioLibraryState(audioItems: [starredItem])),
      );
      await tester.pumpAndSettle();

      // leading 图标现在显示进度状态，不再根据星标变色
      // 未学习状态下使用 onSurfaceVariant 色
      final audioIcon = tester.widget<Icon>(find.byIcon(Icons.audiotrack));
      expect(audioIcon.color, isNotNull);
      expect(audioIcon.color, isNot(AppTheme.bookmarkColor));
    });

    testWidgets('点击星标按钮触发 toggleStar 并更新图标', (tester) async {
      await tester.pumpWidget(
        buildTile(AudioLibraryState(audioItems: [baseItem])),
      );
      await tester.pumpAndSettle();

      // 点击星标按钮
      await tester.tap(find.byIcon(Icons.star_border));
      await tester.pumpAndSettle();

      // 验证切换成功 — 图标变为实心星
      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(find.byIcon(Icons.star_border), findsNothing);
    });
  });

  group('AudioListTile 当前播放展示', () {
    final baseItem = createTestAudioItem(id: 'playing-1', name: 'Playing Audio');

    Widget buildCollectionTile() {
      return createTestApp(
        AudioListTile(
          audioItem: baseItem,
          collectionId: 'collection-1',
        ),
        overrides: [
          appSettingsProvider.overrideWith(
            () => TestAppSettings(const AppSettingsState()),
          ),
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: [baseItem])),
          ),
          collectionListProvider.overrideWith(() => TestCollectionList()),
          tagListProvider.overrideWith(() => TestTagList()),
          listeningPracticeProvider.overrideWith(
            () => TestListeningPractice(
              ListeningPracticeState(currentAudioItem: baseItem),
            ),
          ),
          audioEngineProvider.overrideWith(() => TestAudioEngine()),
          learningProgressNotifierProvider.overrideWith(
            () => TestLearningProgressNotifier(),
          ),
          learningSessionProvider.overrideWith(() => TestLearningSession()),
          blindListenPlayerProvider.overrideWith(() => TestBlindListenPlayer()),
        ],
      );
    }

    testWidgets('合集上下文当前播放时不显示 Last 标签', (tester) async {
      await tester.pumpWidget(buildCollectionTile());
      await tester.pumpAndSettle();

      expect(find.text('Last'), findsNothing);
      expect(find.text('上次'), findsNothing);
      expect(find.byIcon(Icons.star_border), findsOneWidget);
      expect(find.byType(PopupMenuButton<String>), findsOneWidget);
    });
  });
}
