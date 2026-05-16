// 学习计划表页面测试
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:echo_loop/features/onboarding_survey/providers/onboarding_survey_provider.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/screens/learning_plan_screen.dart';
import 'package:echo_loop/models/audio_item.dart';
import 'package:echo_loop/models/learning_progress.dart';
import 'package:echo_loop/database/enums.dart';
import 'package:echo_loop/providers/audio_library_provider.dart';
import 'package:echo_loop/providers/listening_practice/listening_practice_provider.dart';
import 'package:echo_loop/providers/audio_engine/audio_engine_provider.dart';
import 'package:echo_loop/providers/learning_progress_provider.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/providers/learning_session/learning_session_provider.dart';
import 'package:echo_loop/providers/time_provider.dart';
import 'package:echo_loop/theme/app_theme.dart';

import '../helpers/mock_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      // 新手引导 flows 预设已看过（避免 GuideFlow 启动 500ms timer
      // 在 widget dispose 后还 pending，导致测试报 Timer 错误）
      'guide_v1_learning_plan_no_transcript_seen': true,
      'guide_v1_learning_plan_with_transcript_seen': true,
      'guide_v1_learning_plan_pause_learning_seen': true,
    });
    prefs = await SharedPreferences.getInstance();
  });

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

  /// 创建测试用句子列表（模拟字幕加载后的 LP 状态）
  List<Sentence> createTestSentences({int count = 5}) {
    return List.generate(count, (i) {
      return Sentence(
        index: i,
        text: 'Test sentence number ${i + 1}.',
        startTime: Duration(seconds: i * 5),
        endTime: Duration(seconds: (i + 1) * 5),
      );
    });
  }

  /// 构造「截至当前阶段所有过去阶段子步骤都完成」的 completedKeys。
  ///
  /// + 当前阶段中位于 currentSubStage 之前的子步骤也算完成。
  /// 用于把"按 stage.index 推导完成"的老测试预期映射到新签名。
  Set<String> seedCompletedKeys(
    LearningStage currentStage,
    SubStageType currentSub,
  ) {
    final set = <String>{};
    for (final s in LearningStage.values) {
      if (s.index < currentStage.index) {
        for (final sub in s.allSubStages) {
          set.add('${s.key}:${sub.key}');
        }
      } else if (s == currentStage) {
        for (final sub in s.allSubStages) {
          if (sub == currentSub) break;
          set.add('${s.key}:${sub.key}');
        }
      }
    }
    return set;
  }

  /// 若 progressState 未显式指定 completionsByAudio，按 progressMap 中
  /// 每条进度的 currentStage/currentSubStage 自动推导（旧测试预期保留）。
  LearningProgressState _withAutoCompletions(LearningProgressState? state) {
    final base = state ?? const LearningProgressState();
    if (base.completionsByAudio.isNotEmpty || base.progressMap.isEmpty) {
      return base;
    }
    final completions = <String, Set<String>>{};
    for (final entry in base.progressMap.entries) {
      completions[entry.key] = seedCompletedKeys(
        entry.value.currentStage,
        entry.value.currentSubStage,
      );
    }
    return base.copyWith(completionsByAudio: completions);
  }

  Widget createTestWidget({
    Locale locale = const Locale('en'),
    LearningProgressState? progressState,
    AudioItem? audioItem,
    DateTime? fixedNow,
    ListeningPracticeState? lpState,
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
        GoRoute(
          path: '/collections/:collectionId/:audioId/review-difficult-practice',
          builder: (context, state) =>
              const Scaffold(body: Text('Review Difficult Practice')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        analyticsOverride(),
        ...studyTimeOverrides(),
        sharedPreferencesProvider.overrideWithValue(prefs),
        // plan 静态全量；默认 autoSkipRetell=false（手动跳过路径）
        ...learningSettingsOverrides(),
        audioLibraryProvider.overrideWith(
          () => TestAudioLibrary(AudioLibraryState(audioItems: [item])),
        ),
        listeningPracticeProvider.overrideWith(
          () => TestListeningPractice(
            lpState ??
                (item.hasTranscript
                    ? ListeningPracticeState(
                        currentAudioItem: item,
                        sentences: createTestSentences(),
                      )
                    : ListeningPracticeState(currentAudioItem: item)),
          ),
        ),
        audioEngineProvider.overrideWith(() => TestAudioEngine()),
        learningProgressNotifierProvider.overrideWith(
          () => TestLearningProgressNotifier(
            _withAutoCompletions(progressState),
          ),
        ),
        learningSessionProvider.overrideWith(() => TestLearningSession()),
        if (fixedNow != null) nowProvider.overrideWithValue(() => fixedNow),
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
      expect(find.text('Not started'), findsOneWidget);
    });

    testWidgets('显示首次学习区域的 4 个步骤', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Initial Learning'), findsOneWidget);
      expect(find.text('0/4 completed'), findsOneWidget);

      expect(find.text('Blind Listening'), findsWidgets);
      expect(find.text('Intensive Listening'), findsOneWidget);
      expect(find.text('Listen & Repeat'), findsOneWidget);
      expect(find.text('Paragraph Retelling'), findsOneWidget);
    });

    testWidgets('复习区显示七个同级轮次', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // 滚动到复习区域
      await tester.scrollUntilVisible(find.text('Review 1').first, 200);
      await tester.pumpAndSettle();

      expect(find.text('Review 1'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Review 7'), 200);
      expect(find.text('Review 7'), findsOneWidget);
    });

    testWidgets('当前复习轮次显示子阶段和时间标签', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final progressState = LearningProgressState(
        progressMap: {
          'test-1': LearningProgress(
            audioItemId: 'test-1',
            currentStage: LearningStage.review0,
            currentSubStage: SubStageType.reviewDifficultPractice,
            lastStageCompletedAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
          ),
        },
      );
      final fixedNow = DateTime(2026, 1, 1, 5, 0);

      await tester.pumpWidget(
        createTestWidget(progressState: progressState, fixedNow: fixedNow),
      );
      await tester.pumpAndSettle();

      // 滚动到首轮复习区域
      await tester.scrollUntilVisible(find.text('Review 1').first, 200);
      await tester.pumpAndSettle();
      expect(find.text('Review 1'), findsWidgets);

      // 折叠当前轮次
      await tester.tap(find.text('Review 1').first);
      await tester.pumpAndSettle();

      // 重新展开
      await tester.tap(find.text('Review 1').first);
      await tester.pumpAndSettle();
    });

    testWidgets('当前复习轮次逾期时显示逾期文案且不显示固定间隔', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime(2026, 2, 26, 12, 0);
      final progressState = LearningProgressState(
        progressMap: {
          'test-1': LearningProgress(
            audioItemId: 'test-1',
            currentStage: LearningStage.review0,
            currentSubStage: SubStageType.reviewDifficultPractice,
            // review0 窗口结束 = completed + 12h，这里逾期 2h
            lastStageCompletedAt: now.subtract(const Duration(hours: 14)),
            updatedAt: now,
          ),
        },
      );

      await tester.pumpWidget(
        createTestWidget(progressState: progressState, fixedNow: now),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Review 1').first, 200);
      await tester.pumpAndSettle();

      expect(find.textContaining('Due 2h ago'), findsAtLeast(1));
      expect(find.text('After 6 hours'), findsNothing);
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

    testWidgets('复习未到时间时底部继续学习按钮禁用', (tester) async {
      final now = DateTime(2026, 2, 25, 12, 0);
      final progressState = LearningProgressState(
        progressMap: {
          'test-1': LearningProgress(
            audioItemId: 'test-1',
            currentStage: LearningStage.review1,
            currentSubStage: SubStageType.blindListen,
            lastStageCompletedAt: now,
            updatedAt: now,
          ),
        },
      );

      await tester.pumpWidget(
        createTestWidget(progressState: progressState, fixedNow: now),
      );
      await tester.pumpAndSettle();

      final continueButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Continue Learning'),
      );
      expect(continueButton.onPressed, isNull);
    });

    testWidgets('进行中（未暂停）时底部同时显示"暂停学习"和"继续学习"两个按钮', (tester) async {
      final progressState = LearningProgressState(
        progressMap: {
          'test-1': LearningProgress(
            audioItemId: 'test-1',
            currentStage: LearningStage.firstLearn,
            currentSubStage: SubStageType.listenAndRepeat,
            updatedAt: DateTime(2026, 5, 1),
          ),
        },
      );

      await tester.pumpWidget(createTestWidget(progressState: progressState));
      await tester.pumpAndSettle();

      expect(find.text('Continue Learning'), findsOneWidget);
      expect(find.text('Pause Learning'), findsOneWidget);
    });

    testWidgets('暂停态时底部只显示"恢复学习"，不显示"继续学习"或"暂停学习"', (tester) async {
      final progressState = LearningProgressState(
        progressMap: {
          'test-1': LearningProgress(
            audioItemId: 'test-1',
            currentStage: LearningStage.firstLearn,
            currentSubStage: SubStageType.listenAndRepeat,
            updatedAt: DateTime(2026, 5, 1),
            isPaused: true,
          ),
        },
      );

      await tester.pumpWidget(createTestWidget(progressState: progressState));
      await tester.pumpAndSettle();

      // 文案合并「Paused · Resume Learning」，仅一个按钮
      expect(find.textContaining('Resume Learning'), findsOneWidget);
      expect(find.textContaining('Paused'), findsOneWidget);
      expect(find.text('Continue Learning'), findsNothing);
      expect(find.text('Pause Learning'), findsNothing);
    });

    testWidgets('点击底部"暂停学习"弹出确认弹窗', (tester) async {
      final progressState = LearningProgressState(
        progressMap: {
          'test-1': LearningProgress(
            audioItemId: 'test-1',
            currentStage: LearningStage.firstLearn,
            currentSubStage: SubStageType.listenAndRepeat,
            updatedAt: DateTime(2026, 5, 1),
          ),
        },
      );

      await tester.pumpWidget(createTestWidget(progressState: progressState));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pause Learning'));
      await tester.pumpAndSettle();

      expect(find.text('Pause Learning?'), findsOneWidget);
    });

    testWidgets('复习边界时刻到底后底部继续学习按钮可用', (tester) async {
      final now = DateTime(2026, 2, 25, 12, 0);
      final progressState = LearningProgressState(
        progressMap: {
          'test-1': LearningProgress(
            audioItemId: 'test-1',
            currentStage: LearningStage.review1,
            currentSubStage: SubStageType.blindListen,
            lastStageCompletedAt: now.subtract(const Duration(hours: 24)),
            updatedAt: now,
          ),
        },
      );

      await tester.pumpWidget(
        createTestWidget(progressState: progressState, fixedNow: now),
      );
      await tester.pumpAndSettle();

      final continueButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Continue Learning'),
      );
      expect(continueButton.onPressed, isNotNull);
    });

    testWidgets('复习盲听直接弹段落选择弹窗，显示阶段名和预估时长', (tester) async {
      final now = DateTime(2026, 2, 25, 12, 0);
      final progressState = LearningProgressState(
        progressMap: {
          'test-1': LearningProgress(
            audioItemId: 'test-1',
            currentStage: LearningStage.review1,
            currentSubStage: SubStageType.blindListen,
            lastStageCompletedAt: now.subtract(const Duration(hours: 24)),
            updatedAt: now,
          ),
        },
      );

      await tester.pumpWidget(
        createTestWidget(progressState: progressState, fixedNow: now),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue Learning'));
      await tester.pumpAndSettle();
      // 跳过复习简报弹窗，直接弹出段落选择弹窗（步骤标签 + 弹窗标题都是 Blind Listening）
      expect(find.text('Blind Listening'), findsAtLeast(1));
      // 显示阶段名
      expect(find.text('Review 2'), findsAtLeast(1));
      // 显示开始练习按钮
      expect(find.text('Start Practice'), findsOneWidget);
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
        // 真实完成历史：blindListen + intensiveListen
        completionsByAudio: const {
          'test-1': {'firstLearn:blindListen', 'firstLearn:intensiveListen'},
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

      // 当前子步骤是 blindListen，应弹出简报弹窗（步骤标签 + 弹窗标题都是 Blind Listening）
      expect(find.text('Blind Listening'), findsAtLeast(1));
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

      // LP 有 currentAudioItem 但无句子（模拟字幕缺失）
      await tester.pumpWidget(createTestWidget(
        progressState: progressState,
        lpState: ListeningPracticeState(
          currentAudioItem: testAudioItem,
          sentences: const [],
        ),
      ));
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

      expect(find.text('未开始'), findsOneWidget);
      expect(find.text('首次学习'), findsOneWidget);
      expect(find.text('0/4 完成'), findsOneWidget);
      expect(find.text('全文盲听'), findsWidgets);
      expect(find.text('开始学习'), findsOneWidget);

      // 滚动到复习轮次区域
      await tester.scrollUntilVisible(find.text('首轮复习'), 200);
      expect(find.text('首轮复习'), findsOneWidget);
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
            sharedPreferencesProvider.overrideWithValue(prefs),
            ...learningSettingsOverrides(),
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

      // 盲听步骤已完成，点击弹出段落选择弹窗（自由练习模式）
      await tester.tap(find.text('Blind Listening').first);
      await tester.pumpAndSettle();

      // 应弹出段落选择弹窗（步骤标签 + 弹窗标题都是 Blind Listening）
      expect(find.text('Blind Listening'), findsAtLeast(2));
      expect(find.text('Start Practice'), findsOneWidget);
    });

    testWidgets('未完成盲听步骤不可点击', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // 盲听步骤是当前步骤（未完成），点击不应弹出简报弹窗
      await tester.tap(find.text('Blind Listening').first);
      await tester.pumpAndSettle();

      // 不应弹出简报弹窗（因为没有 onTap），步骤标签仍可见但不会多出弹窗标题
      expect(find.text('Blind Listening'), findsOneWidget);
    });

    testWidgets('过去阶段跳过的复述可点击进入自由练习（重开复述后补做）', (tester) async {
      // 模拟：曾关闭复述完成 firstLearn，跳过 retell，currentStage 进入 review0
      // 用户现在重开复述：retell 卡重新显示在 firstLearn 区，应支持自由练习点击
      final progressState = LearningProgressState(
        progressMap: {
          'test-1': LearningProgress(
            audioItemId: 'test-1',
            currentStage: LearningStage.review0,
            currentSubStage: SubStageType.reviewDifficultPractice,
            updatedAt: DateTime(2026, 1, 1),
          ),
        },
        // 真实完成历史：blind/intensive/shadow 三个非复述步骤（retell 被跳过）
        completionsByAudio: const {
          'test-1': {
            'firstLearn:blindListen',
            'firstLearn:intensiveListen',
            'firstLearn:listenAndRepeat',
          },
        },
      );

      await tester.pumpWidget(createTestWidget(progressState: progressState));
      await tester.pumpAndSettle();

      // firstLearn 已是过去阶段，section 默认折叠 → 先展开
      await tester.tap(find.text('Initial Learning'));
      await tester.pumpAndSettle();

      // 段落复述卡片在 firstLearn 区可见（plan 含 + isPast）。
      // 注意：review0 也有「Paragraph Retelling」，所以 findsAtLeast(1)。
      expect(find.text('Paragraph Retelling'), findsAtLeast(1));

      // 找到 firstLearn 区的 _StepCard，验证它的 onTap 非空（可点击进入自由练习）。
      final stepCardFinder = find.ancestor(
        of: find.text('Paragraph Retelling').first,
        matching: find.byType(InkWell),
      );
      expect(stepCardFinder, findsAtLeast(1));
      final inkWell = tester.widgetList<InkWell>(stepCardFinder).firstWhere(
            (w) => w.onTap != null,
            orElse: () => const InkWell(),
          );
      expect(
        inkWell.onTap,
        isNotNull,
        reason: '过去阶段跳过的复述卡应支持点击进入自由练习',
      );
    });

    testWidgets('无字幕时显示警告横幅且禁用开始按钮', (tester) async {
      await tester.pumpWidget(
        createTestWidget(audioItem: testAudioItemNoTranscript),
      );
      await tester.pumpAndSettle();

      // 显示无字幕警告
      expect(
        find.text('This audio has no transcript yet'),
        findsOneWidget,
      );

      // 开始学习按钮应被禁用（查找底部按钮区域）
      final startButton = find.widgetWithText(FilledButton, 'Start Learning');
      expect(startButton, findsOneWidget);
      final button = tester.widget<FilledButton>(startButton);
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

    testWidgets('未来复习轮次显示固定间隔文案而非动态解锁倒计时', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // 首次学习刚完成，review1 需要 24h 后解锁
      final firstLearnCompletedAt = DateTime(2026, 1, 1);
      final now = DateTime(2026, 1, 1, 12, 0); // 12小时后
      final progressState = LearningProgressState(
        progressMap: {
          'test-1': LearningProgress(
            audioItemId: 'test-1',
            currentStage: LearningStage.review0,
            currentSubStage: SubStageType.blindListen,
            firstLearnCompletedAt: firstLearnCompletedAt,
            lastStageCompletedAt: firstLearnCompletedAt,
            updatedAt: now,
          ),
        },
      );

      await tester.pumpWidget(
        createTestWidget(progressState: progressState, fixedNow: now),
      );
      await tester.pumpAndSettle();

      // 滚动到 Review 2（review1 阶段，未来阶段）
      await tester.scrollUntilVisible(find.text('Review 2'), 200);
      await tester.pumpAndSettle();

      // 未来阶段显示固定间隔文案（如"After 1 day"），不显示动态倒计时
      expect(find.textContaining('Unlocks in'), findsNothing);
      expect(find.text('After 1 day'), findsAtLeast(1));
    });

    testWidgets('已完成复习轮次不显示"已解锁"文案', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // 首次学习完成 2 天前，review1（24h）应已解锁
      final firstLearnCompletedAt = DateTime(2026, 1, 1);
      final now = DateTime(2026, 1, 3, 12, 0); // 2.5 天后
      final progressState = LearningProgressState(
        progressMap: {
          'test-1': LearningProgress(
            audioItemId: 'test-1',
            currentStage: LearningStage.review0,
            currentSubStage: SubStageType.blindListen,
            firstLearnCompletedAt: firstLearnCompletedAt,
            lastStageCompletedAt: firstLearnCompletedAt,
            updatedAt: now,
          ),
        },
      );

      await tester.pumpWidget(
        createTestWidget(progressState: progressState, fixedNow: now),
      );
      await tester.pumpAndSettle();

      // 滚动到 Review 2（review1 阶段，未来阶段）
      await tester.scrollUntilVisible(find.text('Review 2'), 200);
      await tester.pumpAndSettle();

      // 未来阶段不再显示"Unlocked"，显示固定间隔文案
      expect(find.text('Unlocked'), findsNothing);
      expect(find.text('After 1 day'), findsAtLeast(1));
    });

    testWidgets('已完成步骤圆形背景使用较深绿色（非 shade50）', (tester) async {
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

      // 盲听步骤已完成，其圆形背景应使用浅绿色
      final containers = tester.widgetList<Container>(find.byType(Container));
      final greenContainers = containers.where((c) {
        final decoration = c.decoration;
        if (decoration is BoxDecoration && decoration.shape == BoxShape.circle) {
          return decoration.color == Colors.green.shade50;
        }
        return false;
      });
      expect(greenContainers, isNotEmpty,
          reason: '已完成步骤应使用 Colors.green.shade50 作为背景');

      // 已完成步骤应显示边框
      final borderedContainers = containers.where((c) {
        final decoration = c.decoration;
        if (decoration is BoxDecoration && decoration.shape == BoxShape.circle) {
          return decoration.border != null;
        }
        return false;
      });
      expect(borderedContainers, isNotEmpty,
          reason: '已完成步骤应显示绿色边框');
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
