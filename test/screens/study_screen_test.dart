import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/database/daos/stage_completion_dao.dart';
import 'package:echo_loop/database/enums.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/models/audio_item.dart';
import 'package:echo_loop/models/learning_progress.dart';
import 'package:echo_loop/providers/audio_library_provider.dart';
import 'package:echo_loop/providers/learning_progress_provider.dart';
import 'package:echo_loop/providers/study_task_provider.dart';
import 'package:echo_loop/screens/study_screen.dart';
import 'package:echo_loop/widgets/learning_progress_icon.dart';
import 'package:echo_loop/providers/time_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/mock_providers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget createTestWidget({
    required List<AudioItem> audioItems,
    required LearningProgressState progressState,
    DateTime? fixedNow,
    List<RecentCompletion>? recentCompletions,
  }) {
    final router = GoRouter(
      initialLocation: '/study',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              Scaffold(body: navigationShell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/collections',
                  builder: (context, state) =>
                      const Scaffold(body: Text('Library')),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/study',
                  builder: (context, state) => const StudyScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/favorites',
                  builder: (context, state) =>
                      const Scaffold(body: Text('Favorites')),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/settings',
                  builder: (context, state) =>
                      const Scaffold(body: Text('Settings')),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/audio/:audioId/plan',
          builder: (context, state) =>
              const Scaffold(body: Text('Learning Plan')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        audioLibraryProvider.overrideWith(
          () => TestAudioLibrary(AudioLibraryState(audioItems: audioItems)),
        ),
        learningProgressNotifierProvider.overrideWith(
          () => TestLearningProgressNotifier(progressState),
        ),
        if (fixedNow != null) nowProvider.overrideWithValue(() => fixedNow),
        if (recentCompletions != null)
          recentCompletionsProvider.overrideWith(
            (ref) => Future.value(recentCompletions),
          ),
      ],
      child: MaterialApp.router(
        supportedLocales: const [Locale('en'), Locale('zh')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: router,
      ),
    );
  }

  testWidgets('无任务时显示空状态', (tester) async {
    await tester.pumpWidget(
      createTestWidget(
        audioItems: const [],
        progressState: const LearningProgressState(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No study tasks yet'), findsOneWidget);
    expect(find.text('Go to Library'), findsOneWidget);
  });

  testWidgets('未到时间复习任务的开始按钮禁用', (tester) async {
    final now = DateTime(2026, 2, 25, 12, 0);
    final audioItems = [
      AudioItem(
        id: 'audio-1',
        name: 'Upcoming Review Audio',
        audioPath: 'audios/review.mp3',
        addedDate: now,
      ),
    ];
    final progressState = LearningProgressState(
      progressMap: {
        'audio-1': LearningProgress(
          audioItemId: 'audio-1',
          currentStage: LearningStage.review1,
          currentSubStage: SubStageType.blindListen,
          lastStageCompletedAt: now,
          updatedAt: now,
        ),
      },
    );

    await tester.pumpWidget(
      createTestWidget(
        audioItems: audioItems,
        progressState: progressState,
        fixedNow: now,
      ),
    );
    await tester.pumpAndSettle();

    // upcoming reviews 默认折叠，先展开
    final expansionTile = find.byType(ExpansionTile);
    expect(expansionTile, findsWidgets);
    await tester.tap(expansionTile.first);
    await tester.pumpAndSettle();

    // 找到 FilledButton（任务卡片中的按钮），应该是禁用的
    final disabledButtons = find.byWidgetPredicate(
      (w) => w is FilledButton && w.onPressed == null,
    );
    expect(disabledButtons, findsAtLeast(1));
  });

  testWidgets('复习任务点击开始后导航到学习计划页', (tester) async {
    final now = DateTime(2026, 2, 25, 12, 0);
    final audioItems = [
      AudioItem(
        id: 'audio-1',
        name: 'Review Audio',
        audioPath: 'audios/review.mp3',
        addedDate: now,
      ),
    ];
    final progressState = LearningProgressState(
      progressMap: {
        'audio-1': LearningProgress(
          audioItemId: 'audio-1',
          currentStage: LearningStage.review1,
          currentSubStage: SubStageType.blindListen,
          lastStageCompletedAt: now.subtract(const Duration(hours: 24)),
          updatedAt: now,
        ),
      },
    );

    await tester.pumpWidget(
      createTestWidget(
        audioItems: audioItems,
        progressState: progressState,
        fixedNow: now,
      ),
    );
    await tester.pumpAndSettle();

    // 音频名称出现在任务卡片中
    expect(find.text('Review Audio'), findsAtLeast(1));

    // 点击任务卡片中的 Review 按钮
    await tester.tap(find.text('Review').first);
    await tester.pumpAndSettle();

    expect(find.text('Learning Plan'), findsOneWidget);
  });

  testWidgets('逾期复习任务显示逾期文案', (tester) async {
    final now = DateTime(2026, 2, 25, 12, 0);
    final audioItems = [
      AudioItem(
        id: 'audio-1',
        name: 'Overdue Review Audio',
        audioPath: 'audios/review.mp3',
        addedDate: now,
      ),
    ];
    final progressState = LearningProgressState(
      progressMap: {
        'audio-1': LearningProgress(
          audioItemId: 'audio-1',
          currentStage: LearningStage.review1,
          currentSubStage: SubStageType.blindListen,
          // review1 窗口结束 = completed + 48h，这里逾期 3h
          lastStageCompletedAt: now.subtract(const Duration(hours: 51)),
          updatedAt: now,
        ),
      },
    );

    await tester.pumpWidget(
      createTestWidget(
        audioItems: audioItems,
        progressState: progressState,
        fixedNow: now,
      ),
    );
    await tester.pumpAndSettle();

    // 新格式："Review due · due 3h ago"
    expect(find.textContaining('due 3h ago'), findsOneWidget);
    // 任务卡片有 Review 按钮
    final reviewButtons = find.widgetWithText(FilledButton, 'Review');
    expect(reviewButtons, findsAtLeast(1));
  });

  testWidgets('首次学习任务显示子阶段标签', (tester) async {
    final now = DateTime(2026, 2, 25, 12, 0);
    final audioItems = [
      AudioItem(
        id: 'audio-1',
        name: 'First Study Audio',
        audioPath: 'audios/test.mp3',
        addedDate: now,
      ),
    ];
    final progressState = LearningProgressState(
      progressMap: {
        'audio-1': LearningProgress(
          audioItemId: 'audio-1',
          currentStage: LearningStage.firstLearn,
          currentSubStage: SubStageType.intensiveListen,
          updatedAt: now,
        ),
      },
    );

    await tester.pumpWidget(
      createTestWidget(
        audioItems: audioItems,
        progressState: progressState,
        fixedNow: now,
      ),
    );
    await tester.pumpAndSettle();

    // 子阶段标签
    expect(find.textContaining('Intensive Listening'), findsAtLeast(1));
    // 按钮文案为 Continue（已开始首次学习）
    expect(find.text('Continue'), findsAtLeast(1));
  });

  testWidgets('已完成音频显示在折叠区', (tester) async {
    final now = DateTime(2026, 2, 25, 12, 0);
    final audioItems = [
      AudioItem(
        id: 'audio-1',
        name: 'Completed Audio',
        audioPath: 'audios/test.mp3',
        addedDate: now,
      ),
    ];
    final progressState = LearningProgressState(
      progressMap: {
        'audio-1': LearningProgress(
          audioItemId: 'audio-1',
          currentStage: LearningStage.completed,
          currentSubStage: SubStageType.blindListen,
          updatedAt: now,
        ),
      },
    );

    await tester.pumpWidget(
      createTestWidget(
        audioItems: audioItems,
        progressState: progressState,
        fixedNow: now,
      ),
    );
    await tester.pumpAndSettle();

    // "All done" 状态
    expect(find.text('All done for now!'), findsOneWidget);

    // 展开已完成区
    expect(find.textContaining('Completed (1)'), findsOneWidget);
    await tester.tap(find.textContaining('Completed (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Completed Audio'), findsOneWidget);
  });

  testWidgets('有任务时不应出现 Hero Card（渐变大卡片）', (tester) async {
    final now = DateTime(2026, 2, 25, 12, 0);
    final audioItems = [
      AudioItem(
        id: 'audio-1',
        name: 'Review Audio',
        audioPath: 'audios/review.mp3',
        addedDate: now,
      ),
      AudioItem(
        id: 'audio-2',
        name: 'First Study Audio',
        audioPath: 'audios/first.mp3',
        addedDate: now,
      ),
    ];
    final progressState = LearningProgressState(
      progressMap: {
        'audio-1': LearningProgress(
          audioItemId: 'audio-1',
          currentStage: LearningStage.review1,
          currentSubStage: SubStageType.blindListen,
          lastStageCompletedAt: now.subtract(const Duration(hours: 24)),
          updatedAt: now,
        ),
      },
    );

    await tester.pumpWidget(
      createTestWidget(
        audioItems: audioItems,
        progressState: progressState,
        fixedNow: now,
      ),
    );
    await tester.pumpAndSettle();

    // 不应出现 Hero Card 的 "Continue Learning" 标签
    expect(find.text('Continue Learning'), findsNothing);
    // 任务应直接在对应 section 中显示
    expect(find.text('Review Audio'), findsAtLeast(1));
    expect(find.text('First Study Audio'), findsAtLeast(1));
  });

  testWidgets('任务卡片中显示 LearningProgressIcon', (tester) async {
    final now = DateTime(2026, 2, 25, 12, 0);
    final audioItems = [
      AudioItem(
        id: 'audio-1',
        name: 'Test Audio',
        audioPath: 'audios/test.mp3',
        addedDate: now,
      ),
    ];

    await tester.pumpWidget(
      createTestWidget(
        audioItems: audioItems,
        progressState: const LearningProgressState(),
        fixedNow: now,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LearningProgressIcon), findsAtLeast(1));
  });

  testWidgets('多个未学习音频时页面只展示规则选中的 1 个首次学习任务', (tester) async {
    final now = DateTime(2026, 2, 25, 12, 0);
    final audioItems = [
      AudioItem(
        id: 'review-audio',
        name: 'Review Audio',
        audioPath: 'audios/review.mp3',
        addedDate: now,
        totalDuration: 180,
      ),
      AudioItem(
        id: 'short-audio',
        name: 'Short Audio',
        audioPath: 'audios/short.mp3',
        addedDate: now.subtract(const Duration(days: 1)),
        totalDuration: 90,
      ),
      AudioItem(
        id: 'long-audio',
        name: 'Long Audio',
        audioPath: 'audios/long.mp3',
        addedDate: now.subtract(const Duration(days: 2)),
        totalDuration: 240,
      ),
    ];
    final progressState = LearningProgressState(
      progressMap: {
        'review-audio': LearningProgress(
          audioItemId: 'review-audio',
          currentStage: LearningStage.review1,
          currentSubStage: SubStageType.blindListen,
          lastStageCompletedAt: now.subtract(const Duration(days: 1)),
          updatedAt: now,
        ),
      },
    );

    await tester.pumpWidget(
      createTestWidget(
        audioItems: audioItems,
        progressState: progressState,
        fixedNow: now,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Review Audio'), findsAtLeast(1));
    expect(find.text('Short Audio'), findsAtLeast(1));
    expect(find.text('Long Audio'), findsNothing);
  });

  testWidgets('无任务时点击"去导入音频"导航到 Library', (tester) async {
    await tester.pumpWidget(
      createTestWidget(
        audioItems: const [],
        progressState: const LearningProgressState(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Go to Library'));
    await tester.pumpAndSettle();

    expect(find.text('Library'), findsOneWidget);
  });

  testWidgets('最近完成区段显示记录并默认折叠', (tester) async {
    final now = DateTime(2026, 3, 25, 12, 0);
    final audioItems = [
      AudioItem(
        id: 'audio-1',
        name: 'Test Audio',
        audioPath: 'audios/test.mp3',
        addedDate: now,
      ),
    ];

    final completions = [
      RecentCompletion(
        audioId: 'audio-1',
        audioName: 'Test Audio',
        stage: 'firstLearn',
        subStage: 'blindListen',
        completedAt: now.subtract(const Duration(hours: 2)),
        durationMs: 5000,
      ),
      RecentCompletion(
        audioId: 'audio-1',
        audioName: 'Test Audio',
        stage: 'firstLearn',
        subStage: 'intensiveListen',
        completedAt: now.subtract(const Duration(minutes: 30)),
        durationMs: 8000,
      ),
    ];

    await tester.pumpWidget(
      createTestWidget(
        audioItems: audioItems,
        progressState: const LearningProgressState(),
        fixedNow: now,
        recentCompletions: completions,
      ),
    );
    await tester.pumpAndSettle();

    // 折叠区标题可见
    expect(find.textContaining('Recently Completed (2)'), findsOneWidget);
    // 摘要文案可见
    expect(find.text('Past 24 hours'), findsOneWidget);

    // 默认折叠 —— 子项不可见
    expect(find.text('Blind Listening'), findsNothing);

    // 展开后子项可见
    await tester.tap(find.textContaining('Recently Completed (2)'));
    await tester.pumpAndSettle();
    // 相对时间出现在最近完成区段中
    expect(find.text('2h ago'), findsOneWidget);
    expect(find.text('30m ago'), findsOneWidget);
    // 完成图标出现在卡片中
    expect(find.byIcon(Icons.check_circle), findsAtLeast(2));
  });

  testWidgets('无最近完成记录时不显示折叠区', (tester) async {
    final now = DateTime(2026, 3, 25, 12, 0);
    final audioItems = [
      AudioItem(
        id: 'audio-1',
        name: 'Test Audio',
        audioPath: 'audios/test.mp3',
        addedDate: now,
      ),
    ];

    await tester.pumpWidget(
      createTestWidget(
        audioItems: audioItems,
        progressState: const LearningProgressState(),
        fixedNow: now,
        recentCompletions: const [],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Recently Completed'), findsNothing);
  });
}
