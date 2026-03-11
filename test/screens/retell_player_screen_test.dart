// 复述播放器页面 Widget 测试
//
// 验证 SegmentedButton 位置和显示模式切换功能。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fluency/l10n/app_localizations.dart';
import 'package:fluency/models/sentence.dart';
import 'package:fluency/models/retell_settings.dart';
import 'package:fluency/screens/retell_player_screen.dart';
import 'package:fluency/providers/listening_practice/listening_practice_provider.dart';
import 'package:fluency/providers/audio_engine/audio_engine_provider.dart';
import 'package:fluency/providers/learning_progress_provider.dart';
import 'package:fluency/providers/learning_session/learning_session_provider.dart';
import 'package:fluency/providers/learning_session/retell_player_provider.dart';
import 'package:fluency/database/daos/bookmark_dao.dart';
import 'package:fluency/database/daos/sentence_ai_cache_dao.dart';
import 'package:fluency/database/app_database.dart' show Bookmark;
import 'package:fluency/database/providers.dart';
import 'package:fluency/providers/sentence_ai_provider.dart';
import 'package:fluency/services/sentence_ai_api_client.dart';
import 'package:fluency/theme/app_theme.dart';

import '../helpers/mock_providers.dart';

class _MockCacheDao extends Mock implements SentenceAiCacheDao {}

class _MockApiClient extends Mock implements SentenceAiApiClient {}

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
  /// 创建测试段落
  List<List<Sentence>> createTestParagraphs() {
    return [
      createTestSentences(count: 3),
    ];
  }

  Widget createTestWidget({
    Locale locale = const Locale('en'),
    RetellPlayerState? playerState,
    List<List<Sentence>>? paragraphs,
    Map<int, Set<int>>? keywords,
  }) {
    final testParagraphs = paragraphs ?? createTestParagraphs();
    final testKeywords = keywords ?? {};
    final initialState = playerState ??
        RetellPlayerState(
          currentParagraphIndex: 0,
          totalParagraphs: testParagraphs.length,
          phase: RetellPhase.listening,
          isPlaying: true,
          playingSentenceIndex: 0,
          settings: const RetellSettings(
            keywordMethod: KeywordMethod.random,
          ),
        );

    final router = GoRouter(
      initialLocation: '/collections/c1/a1/retell',
      routes: [
        GoRoute(
          path: '/collections/:collectionId/:audioId/retell',
          builder: (context, state) {
            final collectionId = state.pathParameters['collectionId']!;
            final audioId = state.pathParameters['audioId']!;
            return RetellPlayerScreen(
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
            ListeningPracticeState(
              sentences: testParagraphs.expand((p) => p).toList(),
            ),
          ),
        ),
        audioEngineProvider.overrideWith(() => TestAudioEngine()),
        learningProgressNotifierProvider.overrideWith(
          () => TestLearningProgressNotifier(),
        ),
        learningSessionProvider.overrideWith(
          () => TestLearningSession(),
        ),
        retellPlayerProvider.overrideWith(
          () => TestRetellPlayer(initialState, testParagraphs, testKeywords),
        ),
        bookmarkDaoProvider.overrideWithValue(_TestBookmarkDao()),
        sentenceAiNotifierProvider.overrideWithValue(
          SentenceAiNotifier(
            cacheDao: _MockCacheDao(),
            apiClient: _MockApiClient(),
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

  group('RetellPlayerScreen — SegmentedButton 位置', () {
    testWidgets('SegmentedButton 存在且位于句子列表之后', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // SegmentedButton 应该存在
      final segmentedButton = find.byType(SegmentedButton<RetellDisplayMode>);
      expect(segmentedButton, findsOneWidget);

      // 句子列表在 Expanded > Card 中，SegmentedButton 应在其后
      // 验证 SegmentedButton 在 Expanded widget 之后（通过 Y 坐标）
      final expandedFinder = find.byType(Expanded).first;
      final expandedBox = tester.getRect(expandedFinder);
      final segmentedBox = tester.getRect(segmentedButton);

      expect(segmentedBox.top, greaterThanOrEqualTo(expandedBox.bottom - 1),
          reason: 'SegmentedButton 应位于句子列表（Expanded）下方');
    });

    testWidgets('切换显示模式功能正常', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // 默认应选中 Visible Only
      expect(find.text('Visible Only'), findsOneWidget);
      expect(find.text('Show All'), findsOneWidget);
      expect(find.text('Hide All'), findsOneWidget);

      // 点击 Show All
      await tester.tap(find.text('Show All'));
      await tester.pumpAndSettle();

      // 验证选中状态变化（通过 SegmentedButton 的 selected 属性）
      final segmented = tester.widget<SegmentedButton<RetellDisplayMode>>(
        find.byType(SegmentedButton<RetellDisplayMode>),
      );
      expect(segmented.selected, contains(RetellDisplayMode.showAll));
    });
  });
}
