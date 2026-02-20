/// CollectionScreen 测试
///
/// 测试合集页面的渲染和交互。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluency/screens/collection_screen.dart';
import 'package:fluency/providers/settings_provider.dart';
import 'package:fluency/providers/audio_library_provider.dart';
import 'package:fluency/providers/collection_provider.dart';
import 'package:fluency/providers/listening_practice/listening_practice_provider.dart';
import 'package:fluency/providers/audio_engine/audio_engine_provider.dart';

import '../helpers/mock_providers.dart';
import '../helpers/test_app.dart';

void main() {
  group('CollectionScreen', () {
    group('渲染', () {
      testWidgets('空状态显示提示文案', (tester) async {
        await tester.pumpWidget(
          createTestScreen(const CollectionScreen()),
        );
        await tester.pumpAndSettle();

        expect(
          find.byIcon(Icons.collections_bookmark_outlined),
          findsOneWidget,
        );
        expect(find.text('No collections yet'), findsOneWidget);
      });

      testWidgets('显示 AppBar 标题', (tester) async {
        await tester.pumpWidget(
          createTestScreen(const CollectionScreen()),
        );
        await tester.pumpAndSettle();

        expect(find.text('Collections'), findsOneWidget);
      });

      testWidgets('显示创建按钮', (tester) async {
        await tester.pumpWidget(
          createTestScreen(const CollectionScreen()),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.add), findsOneWidget);
      });

      testWidgets('显示排序按钮', (tester) async {
        await tester.pumpWidget(
          createTestScreen(const CollectionScreen()),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.sort), findsOneWidget);
      });

      testWidgets('列表视图模式下合集列表正确显示', (tester) async {
        final c1 = createTestCollection(
          id: '1',
          name: 'English Lessons',
          isStarred: true,
          audioItemIds: ['a1', 'a2'],
        );
        final c2 = createTestCollection(
          id: '2',
          name: 'Podcasts',
          isStarred: false,
          audioItemIds: ['a3'],
        );

        await tester.pumpWidget(
          createTestScreen(
            const CollectionScreen(),
            overrides: [
              appSettingsProvider.overrideWith(() => TestAppSettings()),
              audioLibraryProvider.overrideWith(() => TestAudioLibrary()),
              collectionListProvider.overrideWith(
                () => TestCollectionList(
                  CollectionState(
                    rawCollections: [c1, c2],
                    viewMode: CollectionViewMode.list,
                  ),
                ),
              ),
              listeningPracticeProvider.overrideWith(
                () => TestListeningPractice(),
              ),
              audioEngineProvider.overrideWith(() => TestAudioEngine()),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // 合集名称
        expect(find.text('English Lessons'), findsOneWidget);
        expect(find.text('Podcasts'), findsOneWidget);
        // 音频数量
        expect(find.text('2 audios'), findsOneWidget);
        expect(find.text('1 audios'), findsOneWidget);
      });

      testWidgets('星标合集显示星标图标', (tester) async {
        final c = createTestCollection(
          id: '1',
          name: 'Starred',
          isStarred: true,
        );

        await tester.pumpWidget(
          createTestScreen(
            const CollectionScreen(),
            overrides: [
              appSettingsProvider.overrideWith(() => TestAppSettings()),
              audioLibraryProvider.overrideWith(() => TestAudioLibrary()),
              collectionListProvider.overrideWith(
                () => TestCollectionList(
                  CollectionState(
                    rawCollections: [c],
                    viewMode: CollectionViewMode.list,
                  ),
                ),
              ),
              listeningPracticeProvider.overrideWith(
                () => TestListeningPractice(),
              ),
              audioEngineProvider.overrideWith(() => TestAudioEngine()),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // 星标合集显示实心星标
        expect(find.byIcon(Icons.star), findsOneWidget);
      });

      testWidgets('加载中显示进度指示器', (tester) async {
        await tester.pumpWidget(
          createTestScreen(
            const CollectionScreen(),
            overrides: [
              appSettingsProvider.overrideWith(() => TestAppSettings()),
              audioLibraryProvider.overrideWith(() => TestAudioLibrary()),
              collectionListProvider.overrideWith(
                () => TestCollectionList(
                  const CollectionState(isLoading: true),
                ),
              ),
              listeningPracticeProvider.overrideWith(
                () => TestListeningPractice(),
              ),
              audioEngineProvider.overrideWith(() => TestAudioEngine()),
            ],
          ),
        );
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    });

    group('交互', () {
      testWidgets('点击 + 创建新合集', (tester) async {
        await tester.pumpWidget(
          createTestScreen(const CollectionScreen()),
        );
        await tester.pumpAndSettle();

        // 点击创建按钮
        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();

        // 应弹出创建对话框
        expect(find.text('Create Collection'), findsOneWidget);
        expect(find.text('Collection Name'), findsOneWidget);
      });

      testWidgets('创建合集时空名称显示错误', (tester) async {
        await tester.pumpWidget(
          createTestScreen(const CollectionScreen()),
        );
        await tester.pumpAndSettle();

        // 打开创建对话框
        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();

        // 直接点击添加（不输入名称）
        await tester.tap(find.text('Add'));
        await tester.pumpAndSettle();

        // 应显示错误提示
        expect(find.text('Collection name cannot be empty'), findsOneWidget);
      });

      testWidgets('切换 grid/list 视图模式', (tester) async {
        await tester.pumpWidget(
          createTestScreen(const CollectionScreen()),
        );
        await tester.pumpAndSettle();

        // 默认列表模式，显示 grid_view 切换图标
        expect(find.byIcon(Icons.grid_view), findsOneWidget);

        // 点击切换为网格视图
        await tester.tap(find.byIcon(Icons.grid_view));
        await tester.pumpAndSettle();

        // 切换后显示 view_list 图标
        expect(find.byIcon(Icons.view_list), findsOneWidget);
      });

      testWidgets('点击排序按钮显示排序选项', (tester) async {
        await tester.pumpWidget(
          createTestScreen(const CollectionScreen()),
        );
        await tester.pumpAndSettle();

        // 点击排序按钮
        await tester.tap(find.byIcon(Icons.sort));
        await tester.pumpAndSettle();

        // 应显示排序选项
        expect(find.text('Name (A-Z)'), findsOneWidget);
        expect(find.text('Name (Z-A)'), findsOneWidget);
        expect(find.text('Oldest First'), findsOneWidget);
        expect(find.text('Newest First'), findsOneWidget);
        expect(find.text('Custom Order'), findsOneWidget);
      });

      testWidgets('点击星标切换', (tester) async {
        final c = createTestCollection(
          id: '1',
          name: 'Test Collection',
          isStarred: false,
        );

        await tester.pumpWidget(
          createTestScreen(
            const CollectionScreen(),
            overrides: [
              appSettingsProvider.overrideWith(() => TestAppSettings()),
              audioLibraryProvider.overrideWith(() => TestAudioLibrary()),
              collectionListProvider.overrideWith(
                () => TestCollectionList(
                  CollectionState(
                    rawCollections: [c],
                    viewMode: CollectionViewMode.list,
                  ),
                ),
              ),
              listeningPracticeProvider.overrideWith(
                () => TestListeningPractice(),
              ),
              audioEngineProvider.overrideWith(() => TestAudioEngine()),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // 初始状态应为空心星标
        expect(find.byIcon(Icons.star_border), findsOneWidget);

        // 点击星标
        await tester.tap(find.byIcon(Icons.star_border));
        await tester.pumpAndSettle();

        // 切换后应为实心星标
        expect(find.byIcon(Icons.star), findsOneWidget);
      });
    });
  });
}
