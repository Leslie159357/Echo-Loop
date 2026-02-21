// 学习计划表页面测试
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:fluency/l10n/app_localizations.dart';
import 'package:fluency/screens/learning_plan_screen.dart';
import 'package:fluency/models/audio_item.dart';
import 'package:fluency/providers/audio_library_provider.dart';
import 'package:fluency/providers/listening_practice/listening_practice_provider.dart';
import 'package:fluency/providers/audio_engine/audio_engine_provider.dart';
import 'package:fluency/theme/app_theme.dart';

import '../helpers/mock_providers.dart';

void main() {
  final testAudioItem = AudioItem(
    id: 'test-1',
    name: 'Test Audio',
    audioPath: 'audios/test.mp3',
    addedDate: DateTime(2026, 1, 1),
  );

  Widget createTestWidget({Locale locale = const Locale('en')}) {
    final router = GoRouter(
      initialLocation: '/collections/col-1/test-1/plan',
      routes: [
        GoRoute(
          path: '/collections/:collectionId/:audioId/plan',
          builder: (context, state) {
            final collectionId = state.pathParameters['collectionId']!;
            final audioId = state.pathParameters['audioId']!;
            return LearningPlanScreen(
              collectionId: collectionId,
              audioItemId: audioId,
            );
          },
        ),
        GoRoute(
          path: '/collections/:collectionId/:audioId/player',
          builder: (context, state) =>
              const Scaffold(body: Text('Player')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        audioLibraryProvider.overrideWith(
          () => TestAudioLibrary(
            AudioLibraryState(audioItems: [testAudioItem]),
          ),
        ),
        listeningPracticeProvider.overrideWith(
          () => TestListeningPractice(),
        ),
        audioEngineProvider.overrideWith(() => TestAudioEngine()),
      ],
      child: MaterialApp.router(
        locale: locale,
        supportedLocales: const [Locale('en'), Locale('zh')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.light(),
        routerConfig: router,
      ),
    );
  }

  group('LearningPlanScreen', () {
    testWidgets('显示 AppBar 中的音频名称', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Test Audio'), findsOneWidget);
    });

    testWidgets('显示进度卡片（0%，未开始）', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('0%'), findsOneWidget);
      expect(find.text('Learning Progress'), findsOneWidget);
      expect(find.text('Not started'), findsOneWidget);
    });

    testWidgets('显示首学区域的 4 个步骤', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('First Study'), findsOneWidget);
      expect(find.text('0/4 completed'), findsOneWidget);

      expect(find.text('Blind Listening'), findsOneWidget);
      expect(find.text('Intensive Listening'), findsOneWidget);
      expect(find.text('Shadowing'), findsOneWidget);
      expect(find.text('Retelling'), findsOneWidget);
    });

    testWidgets('复习区域默认折叠', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // 滚动到复习区域
      await tester.scrollUntilVisible(find.text('Review'), 200);
      await tester.pumpAndSettle();

      expect(find.text('Review'), findsOneWidget);
      expect(find.text('0/9 completed'), findsOneWidget);
      final expandIcon = tester.widget<AnimatedRotation>(
        find.byType(AnimatedRotation),
      );
      expect(expandIcon.turns, 0.0);
    });

    testWidgets('点击复习标题展开复习区域', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // 滚动到复习区域并点击
      await tester.scrollUntilVisible(find.text('Review'), 200);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review'));
      await tester.pumpAndSettle();

      // 复习步骤可见（可能需要继续滚动）
      await tester.scrollUntilVisible(find.text('Review 1'), 200);
      expect(find.text('Review 1'), findsOneWidget);
      expect(find.text('After 6h'), findsOneWidget);
    });

    testWidgets('显示底部"开始学习"按钮', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Start Learning'), findsOneWidget);
    });

    testWidgets('点击"开始学习"导航到播放器', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Start Learning'));
      await tester.pumpAndSettle();

      expect(find.text('Player'), findsOneWidget);
    });

    testWidgets('中文本地化正确显示', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget(locale: const Locale('zh')));
      await tester.pumpAndSettle();

      expect(find.text('学习进度'), findsOneWidget);
      expect(find.text('未开始'), findsOneWidget);
      expect(find.text('首学'), findsOneWidget);
      expect(find.text('0/4 完成'), findsOneWidget);
      expect(find.text('全文盲听'), findsOneWidget);
      expect(find.text('开始学习'), findsOneWidget);

      // 滚动到复习区域
      await tester.scrollUntilVisible(find.text('复习'), 200);
      expect(find.text('复习'), findsOneWidget);
    });

    testWidgets('audioItem 找不到时显示错误页面', (tester) async {
      final router = GoRouter(
        initialLocation: '/collections/col-1/nonexistent/plan',
        routes: [
          GoRoute(
            path: '/collections/:collectionId/:audioId/plan',
            builder: (context, state) {
              final collectionId = state.pathParameters['collectionId']!;
              final audioId = state.pathParameters['audioId']!;
              return LearningPlanScreen(
                collectionId: collectionId,
                audioItemId: audioId,
              );
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioLibraryProvider.overrideWith(
              () => TestAudioLibrary(), // 空音频库
            ),
            listeningPracticeProvider.overrideWith(
              () => TestListeningPractice(),
            ),
            audioEngineProvider.overrideWith(() => TestAudioEngine()),
          ],
          child: MaterialApp.router(
            supportedLocales: const [Locale('en'), Locale('zh')],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Audio file not found. The file may have been deleted.'),
        findsOneWidget,
      );
    });
  });
}
