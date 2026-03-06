// 难句补练页面 Widget 测试
//
// 验证盲听模式和跟读模式的 UI 渲染、按钮交互、状态切换。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:fluency/l10n/app_localizations.dart';
import 'package:fluency/screens/review_difficult_practice_screen.dart';
import 'package:fluency/providers/listening_practice/listening_practice_provider.dart';
import 'package:fluency/providers/audio_engine/audio_engine_provider.dart';
import 'package:fluency/providers/learning_progress_provider.dart';
import 'package:fluency/providers/learning_session/learning_session_provider.dart';
import 'package:fluency/providers/learning_session/review_difficult_practice_provider.dart';
import 'package:fluency/database/daos/bookmark_dao.dart';
import 'package:fluency/database/app_database.dart' show Bookmark;
import 'package:fluency/database/providers.dart';
import 'package:fluency/theme/app_theme.dart';
import 'package:fluency/widgets/intensive_listen/sentence_annotation_card.dart';

import '../helpers/mock_providers.dart';

/// 测试用 BookmarkDao
class _TestBookmarkDao implements BookmarkDao {
  @override
  Future<List<Bookmark>> getByAudioId(String audioItemId) async => [];

  @override
  Stream<List<Bookmark>> watchByAudioId(String audioItemId) =>
      Stream<List<Bookmark>>.value([]);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return Future<void>.value();
  }
}

void main() {
  /// 创建测试用的难句补练状态
  ReviewDifficultPracticeState createPlayerState({
    int currentSentenceIndex = 0,
    int totalSentences = 5,
    int currentPlayCount = 1,
    int targetRepeatCount = 3,
    bool isPlaying = true,
    bool isAnnotationMode = false,
    bool isTextRevealed = false,
    bool isPauseBetweenPlays = false,
    bool isPauseBetweenSentences = false,
    Duration pauseRemaining = Duration.zero,
    Duration pauseDuration = Duration.zero,
    bool isCompleted = false,
    bool isCountdownPaused = false,
    bool isCountdownFastForward = false,
  }) {
    return ReviewDifficultPracticeState(
      currentSentenceIndex: currentSentenceIndex,
      totalSentences: totalSentences,
      currentPlayCount: currentPlayCount,
      targetRepeatCount: targetRepeatCount,
      isPlaying: isPlaying,
      isAnnotationMode: isAnnotationMode,
      isTextRevealed: isTextRevealed,
      isPauseBetweenPlays: isPauseBetweenPlays,
      isPauseBetweenSentences: isPauseBetweenSentences,
      pauseRemaining: pauseRemaining,
      pauseDuration: pauseDuration,
      isCompleted: isCompleted,
      isCountdownPaused: isCountdownPaused,
      isCountdownFastForward: isCountdownFastForward,
    );
  }

  Widget createTestWidget({
    Locale locale = const Locale('en'),
    ReviewDifficultPracticeState? playerState,
    LearningSessionState? sessionState,
  }) {
    final sentences = createTestSentences(count: 5);
    final initialPlayerState = playerState ?? createPlayerState();

    final router = GoRouter(
      initialLocation: '/collections/c1/a1/review-difficult',
      routes: [
        GoRoute(
          path: '/collections/:collectionId/:audioId/review-difficult',
          builder: (context, state) {
            final collectionId = state.pathParameters['collectionId']!;
            final audioId = state.pathParameters['audioId']!;
            return ReviewDifficultPracticeScreen(
              collectionId: collectionId,
              audioItemId: audioId,
            );
          },
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        listeningPracticeProvider.overrideWith(
          () => TestListeningPractice(
            ListeningPracticeState(sentences: sentences),
          ),
        ),
        audioEngineProvider.overrideWith(() => TestAudioEngine()),
        learningProgressNotifierProvider.overrideWith(
          () => TestLearningProgressNotifier(),
        ),
        learningSessionProvider.overrideWith(
          () =>
              TestLearningSession(sessionState ?? const LearningSessionState()),
        ),
        reviewDifficultPracticeProvider.overrideWith(
          () => TestReviewDifficultPractice(initialPlayerState, sentences),
        ),
        bookmarkDaoProvider.overrideWithValue(_TestBookmarkDao()),
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

  group('ReviewDifficultPracticeScreen — 盲听模式', () {
    testWidgets('显示 AppBar 标题', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Difficult Sentence Practice'), findsOneWidget);
    });

    testWidgets('显示进度文本', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            currentSentenceIndex: 2,
            totalSentences: 10,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('3/10 sentences'), findsOneWidget);
    });

    testWidgets('显示偷看和听不懂按钮', (tester) async {
      await tester.pumpWidget(
        createTestWidget(playerState: createPlayerState(isPlaying: true)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Peek'), findsOneWidget);
      expect(find.text("Can't understand"), findsOneWidget);
    });

    testWidgets('播放中显示盲听提示和耳机图标', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            isPlaying: true,
            isAnnotationMode: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.headphones), findsOneWidget);
      expect(find.text('Listening...'), findsOneWidget);
    });

    testWidgets('显示播放/暂停和上下句按钮', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.skip_previous_rounded), findsOneWidget);
      expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    });

    testWidgets('暂停后显示播放图标', (tester) async {
      await tester.pumpWidget(
        createTestWidget(playerState: createPlayerState(isPlaying: true)),
      );
      await tester.pumpAndSettle();

      // 点击暂停
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.byIcon(Icons.pause_rounded), findsNothing);
    });

    testWidgets('第一句时上一句按钮禁用', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(currentSentenceIndex: 0),
        ),
      );
      await tester.pumpAndSettle();

      final prevIcon = find.byIcon(Icons.skip_previous_rounded);
      final opacity = tester.widget<AnimatedOpacity>(
        find
            .ancestor(of: prevIcon, matching: find.byType(AnimatedOpacity))
            .first,
      );
      expect(opacity.opacity, 0.15);
    });

    testWidgets('最后一句时下一句按钮禁用', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            currentSentenceIndex: 4,
            totalSentences: 5,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final nextIcon = find.byIcon(Icons.skip_next_rounded);
      final opacity = tester.widget<AnimatedOpacity>(
        find
            .ancestor(of: nextIcon, matching: find.byType(AnimatedOpacity))
            .first,
      );
      expect(opacity.opacity, 0.15);
    });

    testWidgets('偷看时显示文本', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(isPlaying: true, isTextRevealed: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Test sentence number 1.'), findsOneWidget);
    });

    testWidgets('句间停顿显示倒计时控件', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            isPauseBetweenPlays: true,
            isPlaying: false,
            pauseRemaining: const Duration(seconds: 3),
            pauseDuration: const Duration(seconds: 3),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('3s'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('难句标记行显示星标', (tester) async {
      await tester.pumpWidget(
        createTestWidget(playerState: createPlayerState(isPlaying: true)),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(find.text('Marked difficult, tap to undo'), findsOneWidget);
    });
  });

  group('ReviewDifficultPracticeScreen — 跟读模式', () {
    testWidgets('跟读模式显示句子文本（RichText 可点击查词）', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            isAnnotationMode: true,
            isPlaying: true,
            currentPlayCount: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // SentenceAnnotationCard 使用 RichText 渲染可点击单词
      expect(find.byType(SentenceAnnotationCard), findsOneWidget);
      // RichText 中包含句子文本
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('Test'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('跟读模式显示遍数标签', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            isAnnotationMode: true,
            isPlaying: true,
            currentPlayCount: 2,
            targetRepeatCount: 3,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Play 2/3'), findsOneWidget);
    });

    testWidgets('跟读模式显示难句标记行', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            isAnnotationMode: true,
            isPlaying: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.star), findsOneWidget);
      // SentenceAnnotationCard 使用 intensiveListenAutoMarkedDifficult
      expect(find.text('Auto-marked difficult, tap to undo'), findsOneWidget);
    });

    testWidgets('跟读模式显示翻译和分析占位卡片', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            isAnnotationMode: true,
            isPlaying: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Translation will be available in a future version'),
        findsOneWidget,
      );
      expect(
        find.text('Analysis will be available in a future version'),
        findsOneWidget,
      );
    });

    testWidgets('跟读模式不显示偷看和听不懂按钮', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            isAnnotationMode: true,
            isPlaying: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Peek'), findsNothing);
      expect(find.text("Can't understand"), findsNothing);
    });

    testWidgets('跟读留白期显示倒计时和跟读提示', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            isAnnotationMode: true,
            isPlaying: false,
            isPauseBetweenPlays: true,
            pauseRemaining: const Duration(seconds: 5),
            pauseDuration: const Duration(seconds: 8),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('5s'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // 跟读提示
      expect(find.text('Your turn — repeat out loud!'), findsOneWidget);
    });

    testWidgets('跟读模式导航按钮可用', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            currentSentenceIndex: 2,
            totalSentences: 5,
            isAnnotationMode: true,
            isPlaying: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final prevIcon = find.byIcon(Icons.skip_previous_rounded);
      final nextIcon = find.byIcon(Icons.skip_next_rounded);

      final prevOpacity = tester.widget<AnimatedOpacity>(
        find
            .ancestor(of: prevIcon, matching: find.byType(AnimatedOpacity))
            .first,
      );
      final nextOpacity = tester.widget<AnimatedOpacity>(
        find
            .ancestor(of: nextIcon, matching: find.byType(AnimatedOpacity))
            .first,
      );
      expect(prevOpacity.opacity, 0.6);
      expect(nextOpacity.opacity, 0.6);
    });

    testWidgets('跟读模式播放按钮可用（非禁用）', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            isAnnotationMode: true,
            isPlaying: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 播放按钮显示暂停图标（非禁用态）
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    });
  });

  group('ReviewDifficultPracticeScreen — 播放按钮交互', () {
    testWidgets('播放中点击 → 暂停', (tester) async {
      await tester.pumpWidget(
        createTestWidget(playerState: createPlayerState(isPlaying: true)),
      );
      await tester.pumpAndSettle();

      // 点击暂停
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pumpAndSettle();

      // 应切换为播放图标
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('暂停中点击 → 恢复播放', (tester) async {
      await tester.pumpWidget(
        createTestWidget(playerState: createPlayerState(isPlaying: true)),
      );
      await tester.pumpAndSettle();

      // 先暂停
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

      // 再恢复
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    });

    testWidgets('点击听不懂 → 进入跟读模式', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            isPlaying: true,
            isAnnotationMode: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text("Can't understand"));
      await tester.pumpAndSettle();

      // 进入跟读模式后应显示 SentenceAnnotationCard
      expect(find.byType(SentenceAnnotationCard), findsOneWidget);
      // 偷看和听不懂按钮应消失
      expect(find.text('Peek'), findsNothing);
      expect(find.text("Can't understand"), findsNothing);
    });

    testWidgets('跟读模式暂停后恢复 → 从第 1 遍重新开始', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            isAnnotationMode: true,
            isPlaying: true,
            currentPlayCount: 2,
            targetRepeatCount: 3,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 暂停
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pumpAndSettle();

      // 恢复 → resume 调 _startShadowReading()，currentPlayCount 回 1
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Play 1/3'), findsOneWidget);
    });
  });

  group('ReviewDifficultPracticeScreen — 中文本地化', () {
    testWidgets('中文显示正确', (tester) async {
      await tester.pumpWidget(createTestWidget(locale: const Locale('zh')));
      await tester.pumpAndSettle();

      expect(find.text('难句补练'), findsOneWidget);
      expect(find.text('偷看字幕'), findsOneWidget);
      expect(find.text('听不懂'), findsOneWidget);
    });

    testWidgets('中文跟读模式遍数显示', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          locale: const Locale('zh'),
          playerState: createPlayerState(
            isAnnotationMode: true,
            isPlaying: true,
            currentPlayCount: 2,
            targetRepeatCount: 3,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('第 2/3 遍'), findsOneWidget);
    });
  });
}
