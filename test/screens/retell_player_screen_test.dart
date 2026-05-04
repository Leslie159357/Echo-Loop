// 复述播放器页面 Widget 测试
//
// 验证 SegmentedButton 位置和显示模式切换功能。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/models/intensive_listen_settings.dart'
    show ShadowingControlMode;
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/models/retell_settings.dart';
import 'package:echo_loop/screens/retell_player_screen.dart';
import 'package:echo_loop/providers/listening_practice/listening_practice_provider.dart';
import 'package:echo_loop/providers/audio_engine/audio_engine_provider.dart';
import 'package:echo_loop/providers/learning_progress_provider.dart';
import 'package:echo_loop/providers/learning_session/learning_session_provider.dart';
import 'package:echo_loop/providers/learning_session/retell_player_provider.dart';
import 'package:echo_loop/database/daos/bookmark_dao.dart';
import 'package:echo_loop/database/daos/sentence_ai_cache_dao.dart';
import 'package:echo_loop/database/app_database.dart' show Bookmark;
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/providers/retell_recording_controller_provider.dart';
import 'package:echo_loop/providers/sentence_ai_provider.dart';
import 'package:echo_loop/services/sentence_ai_api_client.dart';
import 'package:echo_loop/theme/app_theme.dart';
import 'package:echo_loop/widgets/common/playback_controls.dart';
import 'package:echo_loop/widgets/common/recording_button.dart';
import 'package:echo_loop/widgets/common/masked_sentence_tile.dart';

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

class _StaticRetellPlayer extends TestRetellPlayer {
  _StaticRetellPlayer(super.initialState, super.paragraphs, super.keywords);

  @override
  Future<void> startPlaying() async {}
}

class _TrackingRetellPlayer extends _StaticRetellPlayer {
  _TrackingRetellPlayer(super.initialState, super.paragraphs, super.keywords);

  int waitingCalls = 0;
  bool? lastAfterCurrentParagraph;
  bool? lastStopImmediately;

  @override
  void enterWaitingForUser({
    bool afterCurrentParagraph = false,
    bool stopImmediately = false,
  }) {
    waitingCalls += 1;
    lastAfterCurrentParagraph = afterCurrentParagraph;
    lastStopImmediately = stopImmediately;
  }
}

void main() {
  /// 创建测试段落
  List<List<Sentence>> createTestParagraphs() {
    return [createTestSentences(count: 3)];
  }

  Widget createTestWidget({
    Locale locale = const Locale('en'),
    RetellPlayerState? playerState,
    RetellRecordingState? recordingState,
    List<List<Sentence>>? paragraphs,
    Map<int, Set<int>>? keywords,
    TestRetellPlayer Function(
      RetellPlayerState initialState,
      List<List<Sentence>> paragraphs,
      Map<int, Set<int>> keywords,
    )?
    playerFactory,
  }) {
    final testParagraphs = paragraphs ?? createTestParagraphs();
    final testKeywords = keywords ?? {};
    final initialState =
        playerState ??
        RetellPlayerState(
          currentParagraphIndex: 0,
          totalParagraphs: testParagraphs.length,
          phase: RetellPhase.listening,
          isPlaying: true,
          playingSentenceIndex: 0,
          settings: const RetellSettings(keywordMethod: KeywordMethod.random),
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
        learningSessionProvider.overrideWith(() => TestLearningSession()),
        retellPlayerProvider.overrideWith(
          () => (playerFactory ?? TestRetellPlayer.new)(
            initialState,
            testParagraphs,
            testKeywords,
          ),
        ),
        ...studyTimeOverrides(),
        retellRecordingControllerProvider.overrideWith(
          () => TestRetellRecordingController(
            recordingState ?? const RetellRecordingState(),
          ),
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

      final segmentedButton = find.byType(SegmentedButton<RetellDisplayMode>);
      expect(segmentedButton, findsOneWidget);
      expect(find.byType(PlaybackControls), findsOneWidget);

      final sentenceCard = find.byType(Card).first;
      final sentenceCardBox = tester.getRect(sentenceCard);
      final segmentedBox = tester.getRect(segmentedButton);

      expect(
        segmentedBox.top,
        greaterThanOrEqualTo(sentenceCardBox.bottom - 1),
        reason: 'SegmentedButton 应位于句子列表卡片下方',
      );
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

    testWidgets('不同选中态下 SegmentedButton 总宽度保持不变', (tester) async {
      Future<double> pumpAndMeasure(RetellDisplayMode displayMode) async {
        await tester.pumpWidget(
          createTestWidget(
            playerState: RetellPlayerState(
              currentParagraphIndex: 0,
              totalParagraphs: 1,
              phase: RetellPhase.listening,
              isPlaying: true,
              playingSentenceIndex: 0,
              displayMode: displayMode,
              settings: const RetellSettings(
                keywordMethod: KeywordMethod.random,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        return tester
            .getRect(find.byType(SegmentedButton<RetellDisplayMode>))
            .width;
      }

      final keywordsOnlyWidth = await pumpAndMeasure(
        RetellDisplayMode.keywordsOnly,
      );
      final showAllWidth = await pumpAndMeasure(RetellDisplayMode.showAll);
      final hideAllWidth = await pumpAndMeasure(RetellDisplayMode.hideAll);

      expect(showAllWidth, equals(keywordsOnlyWidth));
      expect(hideAllWidth, equals(keywordsOnlyWidth));
    });

    testWidgets('录音和评估控制区位于可见性菜单下方', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: RetellPlayerState(
            currentParagraphIndex: 0,
            totalParagraphs: 1,
            phase: RetellPhase.retelling,
            isPlaying: false,
            settings: const RetellSettings(
              keywordMethod: KeywordMethod.random,
            ),
          ),
          playerFactory: _StaticRetellPlayer.new,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final segmentedButton = find.byType(SegmentedButton<RetellDisplayMode>);
      final recordingButton = find.byType(RecordingButton);

      expect(segmentedButton, findsOneWidget);
      expect(recordingButton, findsOneWidget);
      expect(
        tester.getRect(recordingButton).top,
        greaterThan(tester.getRect(segmentedButton).bottom),
      );
    });

    testWidgets('播放前显示先听再复述提示', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: RetellPlayerState(
            currentParagraphIndex: 0,
            totalParagraphs: 1,
            phase: RetellPhase.listening,
            isPlaying: false,
            settings: const RetellSettings(
              keywordMethod: KeywordMethod.random,
            ),
          ),
          playerFactory: _StaticRetellPlayer.new,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Listen first, then retell'), findsOneWidget);
      expect(find.text('Listening...'), findsNothing);
    });

    testWidgets('WaitingForUser 态即使 isPlaying 为 true 也显示播放图标', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: RetellPlayerState(
            currentParagraphIndex: 0,
            totalParagraphs: 1,
            phase: RetellPhase.listening,
            isPlaying: true,
            isWaitingForUser: true,
            settings: const RetellSettings(
              keywordMethod: KeywordMethod.random,
            ),
          ),
          playerFactory: _StaticRetellPlayer.new,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.byIcon(Icons.pause_rounded), findsNothing);
    });

    testWidgets('播放完成后空闲态不显示复述提示', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: RetellPlayerState(
            currentParagraphIndex: 0,
            totalParagraphs: 1,
            phase: RetellPhase.retelling,
            isPlaying: false,
            settings: const RetellSettings(
              controlMode: ShadowingControlMode.manual,
              keywordMethod: KeywordMethod.random,
            ),
          ),
          playerFactory: _StaticRetellPlayer.new,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Retell it in your own words'), findsNothing);
      expect(find.text('Listening...'), findsNothing);
    });

    testWidgets('录音中显示录音状态而不显示复述提示', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          playerState: RetellPlayerState(
            currentParagraphIndex: 0,
            totalParagraphs: 1,
            phase: RetellPhase.retelling,
            isPlaying: false,
            settings: const RetellSettings(
              controlMode: ShadowingControlMode.manual,
              keywordMethod: KeywordMethod.random,
            ),
          ),
          recordingState: const RetellRecordingState(
            phase: RetellRecordingPhase.recording,
          ),
          playerFactory: _StaticRetellPlayer.new,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Retell it in your own words'), findsNothing);
      expect(find.text('Recording...'), findsOneWidget);
    });

    testWidgets('点击句子进入详情前会进入 waiting for user', (tester) async {
      final testParagraphs = createTestParagraphs();
      final initialState = RetellPlayerState(
        currentParagraphIndex: 0,
        totalParagraphs: testParagraphs.length,
        phase: RetellPhase.listening,
        isPlaying: true,
        playingSentenceIndex: 0,
        displayMode: RetellDisplayMode.showAll,
        settings: const RetellSettings(
          keywordMethod: KeywordMethod.random,
        ),
      );
      final trackingPlayer = _TrackingRetellPlayer(
        initialState,
        testParagraphs,
        const {},
      );

      await tester.pumpWidget(
        createTestWidget(
          playerState: initialState,
          paragraphs: testParagraphs,
          playerFactory: (_, __, ___) => trackingPlayer,
        ),
      );
      await tester.pumpAndSettle();

      // 点击第一个 MaskedSentenceTile 的 InkWell
      final firstTile = find.byType(MaskedSentenceTile).first;
      await tester.tap(firstTile);
      await tester.pump();

      expect(trackingPlayer.waitingCalls, 1);
      expect(trackingPlayer.lastStopImmediately, true);
    });
  });
}
