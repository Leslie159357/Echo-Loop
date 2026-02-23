// 学习计划表页面测试
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:fluency/l10n/app_localizations.dart';
import 'package:fluency/screens/learning_plan_screen.dart';
import 'package:fluency/models/audio_item.dart';
import 'package:fluency/models/learning_progress.dart';
import 'package:fluency/database/enums.dart';
import 'package:fluency/providers/audio_library_provider.dart';
import 'package:fluency/providers/listening_practice/listening_practice_provider.dart';
import 'package:fluency/providers/audio_engine/audio_engine_provider.dart';
import 'package:fluency/providers/learning_progress_provider.dart';
import 'package:fluency/providers/learning_session/learning_session_provider.dart';
import 'package:fluency/theme/app_theme.dart';

import '../helpers/mock_providers.dart';

void main() {
  final testAudioItem = AudioItem(
    id: 'test-1',
    name: 'Test Audio',
    audioPath: 'audios/test.mp3',
    transcriptPath: 'transcripts/test.srt',
    addedDate: DateTime(2026, 1, 1),
    sentenceCount: 10,
    wordCount: 50,
  );

  final testAudioItemNoTranscript = AudioItem(
    id: 'test-1',
    name: 'Test Audio',
    audioPath: 'audios/test.mp3',
    addedDate: DateTime(2026, 1, 1),
  );

  Widget createTestWidget({
    Locale locale = const Locale('en'),
    LearningProgressState? progressState,
    AudioItem? audioItem,
  }) {
    final item = audioItem ?? testAudioItem;
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
          builder: (context, state) => const Scaffold(body: Text('Player')),
        ),
        GoRoute(
          path: '/collections/:collectionId/:audioId/blind-listen',
          builder: (context, state) =>
              const Scaffold(body: Text('Blind Listen')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        audioLibraryProvider.overrideWith(
          () => TestAudioLibrary(AudioLibraryState(audioItems: [item])),
        ),
        listeningPracticeProvider.overrideWith(() => TestListeningPractice()),
        audioEngineProvider.overrideWith(() => TestAudioEngine()),
        learningProgressNotifierProvider.overrideWith(
          () => TestLearningProgressNotifier(
            progressState ?? const LearningProgressState(),
          ),
        ),
        learningSessionProvider.overrideWith(() => TestLearningSession()),
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
      expect(find.text('Listen & Repeat'), findsOneWidget);
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
      expect(find.text('0/7 completed'), findsOneWidget);
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
      expect(find.text('Now'), findsOneWidget);
    });

    testWidgets('显示底部"开始学习"按钮', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Start Learning'), findsOneWidget);
    });

    testWidgets('进行中时底部显示"继续学习"', (tester) async {
      final progressState = LearningProgressState(
        progressMap: {
          'test-1': LearningProgress(
            audioItemId: 'test-1',
            currentStage: LearningStage.firstLearn,
            currentSubStage: SubStageType.listenAndRepeat,
            updatedAt: DateTime(2026, 1, 1),
          ),
        },
      );

      await tester.pumpWidget(createTestWidget(progressState: progressState));
      await tester.pumpAndSettle();

      expect(find.text('Continue Learning'), findsOneWidget);
    });

    testWidgets('有进度时显示正确的完成步骤数', (tester) async {
      final progressState = LearningProgressState(
        progressMap: {
          'test-1': LearningProgress(
            audioItemId: 'test-1',
            currentStage: LearningStage.firstLearn,
            currentSubStage: SubStageType.listenAndRepeat,
            updatedAt: DateTime(2026, 1, 1),
          ),
        },
      );

      await tester.pumpWidget(createTestWidget(progressState: progressState));
      await tester.pumpAndSettle();

      expect(find.text('2/4 completed'), findsOneWidget);
    });

    testWidgets('点击"开始学习"显示简报弹窗', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Start Learning'));
      await tester.pumpAndSettle();

      // 当前子步骤是 blindListen，应弹出简报弹窗
      expect(find.text('Full Listening'), findsOneWidget);
      expect(find.text('Start Practice'), findsOneWidget);
    });

    testWidgets('简报弹窗点击开始练习后导航到盲听播放器', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Start Learning'));
      await tester.pumpAndSettle();

      // 点击开始练习
      await tester.tap(find.text('Start Practice'));
      await tester.pumpAndSettle();

      expect(find.text('Blind Listen'), findsOneWidget);
    });

    testWidgets('精听子步骤无字幕时显示提示对话框', (tester) async {
      final progressState = LearningProgressState(
        progressMap: {
          'test-1': LearningProgress(
            audioItemId: 'test-1',
            currentStage: LearningStage.firstLearn,
            currentSubStage: SubStageType.intensiveListen,
            updatedAt: DateTime(2026, 1, 1),
          ),
        },
      );

      await tester.pumpWidget(createTestWidget(progressState: progressState));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue Learning'));
      await tester.pumpAndSettle();

      // LP 无句子时应弹出"无字幕"提示对话框
      expect(find.text('No Subtitle Available'), findsOneWidget);
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
            learningProgressNotifierProvider.overrideWith(
              () => TestLearningProgressNotifier(),
            ),
            learningSessionProvider.overrideWith(() => TestLearningSession()),
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

    testWidgets('已完成盲听步骤可点击直接进入自由练习', (tester) async {
      final progressState = LearningProgressState(
        progressMap: {
          'test-1': LearningProgress(
            audioItemId: 'test-1',
            currentStage: LearningStage.firstLearn,
            currentSubStage: SubStageType.intensiveListen,
            updatedAt: DateTime(2026, 1, 1),
          ),
        },
      );

      await tester.pumpWidget(createTestWidget(progressState: progressState));
      await tester.pumpAndSettle();

      // 盲听步骤已完成，点击直接导航到盲听播放器（不弹 briefing sheet）
      await tester.tap(find.text('Blind Listening'));
      await tester.pumpAndSettle();

      // 不应弹出简报弹窗，而是直接导航到盲听播放器
      expect(find.text('Full Listening'), findsNothing);
      expect(find.text('Blind Listen'), findsOneWidget);
    });

    testWidgets('未完成盲听步骤不可点击', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // 盲听步骤是当前步骤（未完成），点击不应弹出简报弹窗
      await tester.tap(find.text('Blind Listening'));
      await tester.pumpAndSettle();

      // 不应弹出简报弹窗（因为没有 onTap）
      expect(find.text('Full Listening'), findsNothing);
    });

    testWidgets('无字幕时显示警告横幅且禁用开始按钮', (tester) async {
      await tester.pumpWidget(
        createTestWidget(audioItem: testAudioItemNoTranscript),
      );
      await tester.pumpAndSettle();

      // 显示无字幕警告
      expect(
        find.text(
          'No transcript uploaded. A transcript is required to start the learning flow.',
        ),
        findsOneWidget,
      );

      // 开始学习按钮应被禁用
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('有字幕时显示句子数和单词数', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('10 sentences'), findsOneWidget);
      expect(find.text('50 words'), findsOneWidget);
    });

    testWidgets('有字幕时不显示警告横幅', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(
        find.text(
          'No transcript uploaded. A transcript is required to start the learning flow.',
        ),
        findsNothing,
      );
    });

    testWidgets('盲听已完成时显示难度信息', (tester) async {
      final progressState = LearningProgressState(
        progressMap: {
          'test-1': LearningProgress(
            audioItemId: 'test-1',
            currentStage: LearningStage.firstLearn,
            currentSubStage: SubStageType.intensiveListen,
            difficulty: DifficultyLevel.hard,
            blindListenPassCount: 2,
            updatedAt: DateTime(2026, 1, 1),
          ),
        },
      );

      await tester.pumpWidget(createTestWidget(progressState: progressState));
      await tester.pumpAndSettle();

      // 盲听步骤已完成，应显示遍数 + 难度
      expect(find.textContaining('Listened 2 time(s)'), findsOneWidget);
      expect(find.textContaining('Difficulty:'), findsOneWidget);
    });

    testWidgets('已完成状态显示正确', (tester) async {
      final progressState = LearningProgressState(
        progressMap: {
          'test-1': LearningProgress(
            audioItemId: 'test-1',
            currentStage: LearningStage.completed,
            currentSubStage: SubStageType.blindListen,
            firstLearnCompletedAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 2, 1),
          ),
        },
      );

      await tester.pumpWidget(createTestWidget(progressState: progressState));
      await tester.pumpAndSettle();

      expect(find.text('100%'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('4/4 completed'), findsOneWidget);
    });
  });
}
