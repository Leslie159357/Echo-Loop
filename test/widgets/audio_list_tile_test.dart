import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/database/enums.dart';
import 'package:echo_loop/models/learning_progress.dart';
import 'package:echo_loop/providers/audio_library_provider.dart';
import 'package:echo_loop/providers/audio_engine/audio_engine_provider.dart';
import 'package:echo_loop/providers/collection_provider.dart';
import 'package:echo_loop/providers/learning_progress_provider.dart';
import 'package:echo_loop/providers/learning_session/blind_listen_player_provider.dart';
import 'package:echo_loop/providers/learning_session/learning_session_provider.dart';
import 'package:echo_loop/providers/listening_practice/listening_practice_provider.dart';
import 'package:echo_loop/providers/settings_provider.dart';
import 'package:echo_loop/providers/tag_provider.dart';
import 'package:echo_loop/theme/app_theme.dart';
import 'package:echo_loop/widgets/audio_list_tile.dart';

import '../helpers/mock_providers.dart';
import '../helpers/test_app.dart';

/// 包装器：从 Provider 读取第一个音频项，传给 AudioListTile
/// 模拟真实场景中父组件 watch provider → 传 item 给子组件的模式
class _AudioListTileWrapper extends ConsumerWidget {
  const _AudioListTileWrapper();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(audioLibraryProvider.select((s) => s.audioItems));
    if (items.isEmpty) return const SizedBox.shrink();
    return AudioListTile(audioItem: items.first);
  }
}

void main() {
  group('AudioListTile 置顶菜单', () {
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

    Widget buildCompactTile(AudioLibraryState libraryState) {
      return createTestApp(
        Center(
          child: SizedBox(width: 360, child: const _AudioListTileWrapper()),
        ),
        overrides: [
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(libraryState),
          ),
        ],
      );
    }

    testWidgets('右侧仅显示一个菜单按钮', (tester) async {
      await tester.pumpWidget(
        buildTile(AudioLibraryState(audioItems: [baseItem])),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('audio_list_tile_menu_hit_area')),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.push_pin_outlined), findsNothing);
      expect(find.byIcon(Icons.push_pin), findsNothing);
    });

    testWidgets('已置顶时使用淡背景色标记', (tester) async {
      final pinnedItem = baseItem.copyWith(isPinned: true);
      await tester.pumpWidget(
        buildTile(AudioLibraryState(audioItems: [pinnedItem])),
      );
      await tester.pumpAndSettle();

      final card = tester.widget<Card>(find.byType(Card).first);
      expect(card.color, isNotNull);
    });

    testWidgets('未置顶时卡片保持默认背景', (tester) async {
      await tester.pumpWidget(
        buildTile(AudioLibraryState(audioItems: [baseItem])),
      );
      await tester.pumpAndSettle();

      final card = tester.widget<Card>(find.byType(Card).first);
      expect(card.color, isNull);
    });

    testWidgets('已置顶时 leading 音频图标颜色不受置顶影响（显示进度状态）', (tester) async {
      final pinnedItem = baseItem.copyWith(isPinned: true);
      await tester.pumpWidget(
        buildTile(AudioLibraryState(audioItems: [pinnedItem])),
      );
      await tester.pumpAndSettle();

      // leading 图标现在显示进度状态，不再根据置顶变色
      final audioIcon = tester.widget<Icon>(find.byIcon(Icons.graphic_eq));
      expect(audioIcon.color, isNotNull);
      expect(audioIcon.color, isNot(AppTheme.bookmarkColor));
    });

    testWidgets('菜单内点击置顶触发 togglePin 并更新背景', (tester) async {
      await tester.pumpWidget(
        buildCompactTile(AudioLibraryState(audioItems: [baseItem])),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('audio_list_tile_menu_hit_area')));
      await tester.pumpAndSettle();
      expect(find.text('Pin to Top'), findsOneWidget);

      await tester.tap(find.text('Pin to Top'));
      await tester.pumpAndSettle();

      final card = tester.widget<Card>(find.byType(Card).first);
      expect(card.color, isNotNull);
    });

    testWidgets('菜单首项根据状态显示 pin 或 unpin', (tester) async {
      await tester.pumpWidget(
        buildTile(
          AudioLibraryState(audioItems: [baseItem.copyWith(isPinned: true)]),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('audio_list_tile_menu_hit_area')));
      await tester.pumpAndSettle();

      expect(find.text('Unpin'), findsOneWidget);
    });

    testWidgets('官方音频菜单显示更新字幕，不显示管理字幕', (tester) async {
      final officialItem = baseItem.copyWith(
        remoteAudioId: 'remote-audio-1',
        transcriptPath: null,
      );
      await tester.pumpWidget(
        buildCompactTile(AudioLibraryState(audioItems: [officialItem])),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('audio_list_tile_menu_hit_area')));
      await tester.pumpAndSettle();

      expect(find.text('Update Subtitle'), findsOneWidget);
      expect(find.text('Manage Subtitles'), findsNothing);
    });

    testWidgets('点击官方更新字幕先弹出清空进度确认框', (tester) async {
      final officialItem = baseItem.copyWith(
        remoteAudioId: 'remote-audio-1',
        transcriptPath: 'transcripts/official_x.srt',
      );
      await tester.pumpWidget(
        buildCompactTile(AudioLibraryState(audioItems: [officialItem])),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('audio_list_tile_menu_hit_area')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Update Subtitle'));
      await tester.pumpAndSettle();

      expect(find.text('Update subtitle?'), findsOneWidget);
      expect(
        find.textContaining('clear all bookmarked sentences'),
        findsOneWidget,
      );
    });
  });

  group('AudioListTile 当前播放展示', () {
    final baseItem = createTestAudioItem(
      id: 'playing-1',
      name: 'Playing Audio',
    );

    Widget buildCollectionTile() {
      return createTestApp(
        AudioListTile(audioItem: baseItem, collectionId: 'collection-1'),
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

      final card = tester.widget<Card>(find.byType(Card).first);
      expect(card.color, isNull, reason: '当前播放态不应持久保留卡片背景色');
      expect(find.text('Last'), findsNothing);
      expect(find.text('上次'), findsNothing);
      expect(find.byIcon(Icons.push_pin_outlined), findsNothing);
      expect(find.byType(PopupMenuButton<String>), findsOneWidget);
    });
  });

  group('AudioListTile 暂停学习菜单', () {
    final baseItem = createTestAudioItem(id: 'pause-1', name: 'Pause Audio');

    LearningProgress makeProgress({required bool isPaused}) {
      return LearningProgress(
        audioItemId: baseItem.id,
        currentStage: LearningStage.review2,
        currentSubStage: SubStageType.blindListen,
        lastStageCompletedAt: DateTime(2026, 5, 1),
        updatedAt: DateTime(2026, 5, 1),
        isPaused: isPaused,
      );
    }

    Widget buildWithProgress(LearningProgress progress) {
      return createTestApp(
        Center(
          child: SizedBox(width: 360, child: const _AudioListTileWrapper()),
        ),
        overrides: [
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: [baseItem])),
          ),
          learningProgressNotifierProvider.overrideWith(
            () => TestLearningProgressNotifier(
              LearningProgressState(
                progressMap: {progress.audioItemId: progress},
              ),
            ),
          ),
        ],
      );
    }

    testWidgets('未暂停时菜单显示 Pause Learning，点击弹出确认弹窗', (tester) async {
      await tester.pumpWidget(buildWithProgress(makeProgress(isPaused: false)));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('audio_list_tile_menu_hit_area')));
      await tester.pumpAndSettle();

      expect(find.text('Pause Learning'), findsOneWidget);
      expect(find.text('Resume Learning'), findsNothing);

      await tester.tap(find.text('Pause Learning'));
      await tester.pumpAndSettle();

      expect(find.text('Pause Learning?'), findsOneWidget);
      expect(
        find.textContaining('Review scheduling for this audio will stop'),
        findsOneWidget,
      );
    });

    testWidgets('暂停态下菜单显示 Resume Learning，且卡片显示 Paused chip', (tester) async {
      await tester.pumpWidget(buildWithProgress(makeProgress(isPaused: true)));
      await tester.pumpAndSettle();

      // 卡片上的轮次 chip 被替换为「Paused」
      expect(find.text('Paused'), findsOneWidget);

      await tester.tap(find.byKey(const Key('audio_list_tile_menu_hit_area')));
      await tester.pumpAndSettle();

      expect(find.text('Resume Learning'), findsOneWidget);
      expect(find.text('Pause Learning'), findsNothing);
    });

    testWidgets('未开始学习的音频不显示暂停菜单项', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          Center(
            child: SizedBox(width: 360, child: const _AudioListTileWrapper()),
          ),
          overrides: [
            audioLibraryProvider.overrideWith(
              () => TestAudioLibrary(AudioLibraryState(audioItems: [baseItem])),
            ),
            learningProgressNotifierProvider.overrideWith(
              () => TestLearningProgressNotifier(),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('audio_list_tile_menu_hit_area')));
      await tester.pumpAndSettle();

      expect(find.text('Pause Learning'), findsNothing);
      expect(find.text('Resume Learning'), findsNothing);
    });
  });
}
