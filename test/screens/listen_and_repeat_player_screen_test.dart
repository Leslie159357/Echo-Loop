// 跟读播放器页面测试
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:fluency/l10n/app_localizations.dart';
import 'package:fluency/screens/listen_and_repeat_player_screen.dart';
import 'package:fluency/providers/listening_practice/listening_practice_provider.dart';
import 'package:fluency/providers/audio_engine/audio_engine_provider.dart';
import 'package:fluency/providers/learning_progress_provider.dart';
import 'package:fluency/providers/learning_session/learning_session_provider.dart';
import 'package:fluency/models/intensive_listen_settings.dart';
import 'package:fluency/providers/learning_session/listen_and_repeat_player_provider.dart';
import 'package:fluency/theme/app_theme.dart';

import '../helpers/mock_providers.dart';

void main() {
  /// 创建测试用的跟读播放器状态
  ListenAndRepeatPlayerState createPlayerState({
    int currentSentenceIndex = 0,
    int totalSentences = 5,
    int currentPlayCount = 1,
    int targetPlayCount = 3,
    bool isPlaying = true,
    bool isPauseBetweenPlays = false,
    bool isPauseBetweenSentences = false,
    Duration pauseRemaining = Duration.zero,
    Duration pauseDuration = Duration.zero,
    bool isCompleted = false,
  }) {
    return ListenAndRepeatPlayerState(
      currentSentenceIndex: currentSentenceIndex,
      totalSentences: totalSentences,
      currentPlayCount: currentPlayCount,
      targetPlayCount: targetPlayCount,
      settings: IntensiveListenSettings(repeatCount: targetPlayCount),
      isPlaying: isPlaying,
      isPauseBetweenPlays: isPauseBetweenPlays,
      isPauseBetweenSentences: isPauseBetweenSentences,
      pauseRemaining: pauseRemaining,
      pauseDuration: pauseDuration,
      isCompleted: isCompleted,
    );
  }

  Widget createTestWidget({
    Locale locale = const Locale('en'),
    ListenAndRepeatPlayerState? playerState,
    LearningSessionState? sessionState,
  }) {
    final sentences = createTestSentences(count: 5);

    final router = GoRouter(
      initialLocation: '/collections/c1/a1/listen-and-repeat',
      routes: [
        GoRoute(
          path: '/collections/:collectionId/:audioId/listen-and-repeat',
          builder: (context, state) {
            final collectionId = state.pathParameters['collectionId']!;
            final audioId = state.pathParameters['audioId']!;
            return ListenAndRepeatPlayerScreen(
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
          () => TestLearningSession(
            sessionState ?? const LearningSessionState(),
          ),
        ),
        listenAndRepeatPlayerProvider.overrideWith(
          () => TestListenAndRepeatPlayer(
            playerState ?? createPlayerState(),
            sentences,
          ),
        ),
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

  group('ListenAndRepeatPlayerScreen', () {
    testWidgets('显示跟读 AppBar 标题', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Listen & Repeat'), findsOneWidget);
    });

    testWidgets('显示当前句子文本', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            currentSentenceIndex: 0,
            totalSentences: 5,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // SentenceAnnotationCard 使用 RichText 渲染，需要在 TextSpan 中查找
      final richTextFinder = find.byWidgetPredicate((widget) {
        if (widget is RichText) {
          final text = widget.text.toPlainText();
          return text.contains('Test sentence number 1.');
        }
        return false;
      });
      expect(richTextFinder, findsOneWidget);
    });

    testWidgets('显示播放遍数信息', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            currentPlayCount: 1,
            targetPlayCount: 3,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Play 1/3'), findsOneWidget);
    });

    testWidgets('进度指示器显示当前/总句数', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(
            currentSentenceIndex: 2,
            totalSentences: 10,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // l10n: "Repeat 3/10" (1-based)
      expect(find.text('Repeat 3/10'), findsOneWidget);
    });

    testWidgets('底部控制栏包含上一句、播放/暂停、下一句按钮', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.skip_previous), findsOneWidget);
      expect(find.byIcon(Icons.skip_next), findsOneWidget);
      // 默认 isPlaying=true，显示暂停图标
      expect(find.byIcon(Icons.pause), findsOneWidget);
    });

    testWidgets('AppBar 包含设置按钮', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.tune), findsOneWidget);
    });

    testWidgets('播放中显示暂停图标', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(isPlaying: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.pause), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsNothing);
    });

    testWidgets('点击播放按钮切换为暂停图标', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: createPlayerState(isPlaying: true),
        ),
      );
      await tester.pumpAndSettle();

      // 初始播放中，显示暂停图标
      expect(find.byIcon(Icons.pause), findsOneWidget);

      // 点击播放/暂停按钮（GestureDetector 包裹的圆形容器）
      await tester.tap(find.byIcon(Icons.pause));
      await tester.pumpAndSettle();

      // 暂停后显示播放图标
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.byIcon(Icons.pause), findsNothing);
    });
  });
}
