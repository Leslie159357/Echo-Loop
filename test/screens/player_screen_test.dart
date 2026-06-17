/// PlayerScreen 测试
///
/// 测试播放器页面的渲染和交互。
/// 注意：PlayerScreen 在 macOS 上包含 _HotkeyTipsCarousel（Timer.periodic），
/// 每个测试结束前需替换 widget tree 触发 dispose 取消 timer。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/screens/player_screen.dart';
import 'package:echo_loop/widgets/common/paragraph_sentence_list_card.dart';
import 'package:echo_loop/widgets/common/masked_sentence_tile.dart';
import 'package:echo_loop/widgets/playback_controls.dart';
import 'package:echo_loop/models/audio_engine_state.dart';
import 'package:echo_loop/providers/settings_provider.dart';
import 'package:echo_loop/providers/audio_library_provider.dart';
import 'package:echo_loop/providers/collection_provider.dart';
import 'package:echo_loop/providers/listening_practice/listening_practice_provider.dart';
import 'package:echo_loop/providers/audio_engine/audio_engine_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../helpers/mock_providers.dart';
import '../helpers/test_app.dart';

/// 有音频状态的通用 provider overrides
List<Override> _audioOverrides({
  ListeningPracticeState? practiceState,
  AudioEngineState? engineState,
}) {
  return [
    appSettingsProvider.overrideWith(() => TestAppSettings()),
    audioLibraryProvider.overrideWith(() => TestAudioLibrary()),
    collectionListProvider.overrideWith(() => TestCollectionList()),
    listeningPracticeProvider.overrideWith(
      () => TestListeningPractice(
        practiceState ?? const ListeningPracticeState(),
      ),
    ),
    audioEngineProvider.overrideWith(
      () => TestAudioEngine(
        initialState:
            engineState ??
            const AudioEngineState(totalDuration: Duration(seconds: 120)),
      ),
    ),
  ];
}

/// 替换 widget tree 触发 dispose，再 pump 一帧让 deactivate 中的
/// Future(...) 和 _HotkeyTipsCarousel 的 periodic Timer 全部完成/取消
Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  // 额外 pump 让 deactivate 中 Future 微任务执行完毕
  await tester.pump();
  await tester.pump();
}

void main() {
  group('PlayerScreen', () {
    group('渲染', () {
      testWidgets('无音频时显示空状态', (tester) async {
        await tester.pumpWidget(createTestScreen(const PlayerScreen()));
        await tester.pump();

        expect(find.text('No audio loaded'), findsOneWidget);
        await _disposeTree(tester);
      });

      testWidgets('无音频时 AppBar 显示 Player 标题', (tester) async {
        await tester.pumpWidget(createTestScreen(const PlayerScreen()));
        await tester.pump();

        expect(find.text('Player'), findsOneWidget);
        await _disposeTree(tester);
      });

      testWidgets('有音频时显示音频名称作为标题', (tester) async {
        final item = createTestAudioItem(name: 'My Lesson');
        final sentences = createTestSentences(count: 3);

        await tester.pumpWidget(
          createTestScreen(
            const PlayerScreen(),
            overrides: _audioOverrides(
              practiceState: ListeningPracticeState(
                currentAudioItem: item,
                sentences: sentences,
                currentFullIndex: 0,
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('My Lesson'), findsOneWidget);
        await _disposeTree(tester);
      });

      testWidgets('有音频和句子时显示 TabBar', (tester) async {
        final item = createTestAudioItem();
        final sentences = createTestSentences(count: 3);

        await tester.pumpWidget(
          createTestScreen(
            const PlayerScreen(),
            overrides: _audioOverrides(
              practiceState: ListeningPracticeState(
                currentAudioItem: item,
                sentences: sentences,
                currentFullIndex: 0,
              ),
            ),
          ),
        );
        await tester.pump();

        // TabBar 应显示"全文"和"书签"标签
        expect(find.byType(TabBar), findsOneWidget);
        expect(find.textContaining('Full Text'), findsOneWidget);
        expect(find.textContaining('Bookmarked'), findsOneWidget);
        await _disposeTree(tester);
      });

      testWidgets('句子列表复用盲听共享组件渲染', (tester) async {
        final item = createTestAudioItem();
        final sentences = createTestSentences(count: 3);

        await tester.pumpWidget(
          createTestScreen(
            const PlayerScreen(),
            overrides: _audioOverrides(
              practiceState: ListeningPracticeState(
                currentAudioItem: item,
                sentences: sentences,
                currentFullIndex: 0,
              ),
            ),
          ),
        );
        await tester.pump();

        // 列表改用共享组件 ParagraphSentenceListCard + MaskedSentenceTile
        expect(find.byType(ParagraphSentenceListCard), findsOneWidget);
        expect(find.byType(MaskedSentenceTile), findsNWidgets(3));
        await _disposeTree(tester);
      });

      testWidgets('显示 PlaybackControls', (tester) async {
        final item = createTestAudioItem();
        final sentences = createTestSentences(count: 3);

        await tester.pumpWidget(
          createTestScreen(
            const PlayerScreen(),
            overrides: _audioOverrides(
              practiceState: ListeningPracticeState(
                currentAudioItem: item,
                sentences: sentences,
                currentFullIndex: 0,
              ),
            ),
          ),
        );
        await tester.pump();

        // 播放控制栏应存在（play_arrow 限定在 PlaybackControls 内，
        // 因为当前播放句的编号区也会渲染 play_arrow）
        expect(
          find.descendant(
            of: find.byType(PlaybackControls),
            matching: find.byIcon(Icons.play_arrow),
          ),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.skip_previous), findsOneWidget);
        expect(find.byIcon(Icons.skip_next), findsOneWidget);
        await _disposeTree(tester);
      });

      testWidgets('AppBar 显示设置按钮', (tester) async {
        await tester.pumpWidget(createTestScreen(const PlayerScreen()));
        await tester.pump();

        expect(find.byIcon(Icons.tune), findsOneWidget);
        await _disposeTree(tester);
      });

      testWidgets('有音频但无字幕时显示无字幕提示', (tester) async {
        final item = createTestAudioItem();

        await tester.pumpWidget(
          createTestScreen(
            const PlayerScreen(),
            overrides: _audioOverrides(
              practiceState: ListeningPracticeState(
                currentAudioItem: item,
                sentences: const [], // 无句子
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('No Subtitle'), findsOneWidget);
        expect(find.byIcon(Icons.subtitles_off_outlined), findsOneWidget);
        await _disposeTree(tester);
      });
    });

    group('交互', () {
      testWidgets('点击设置按钮打开设置底部弹窗', (tester) async {
        await tester.pumpWidget(createTestScreen(const PlayerScreen()));
        await tester.pump();

        // 点击设置按钮
        await tester.tap(find.byIcon(Icons.tune));
        await tester.pumpAndSettle();

        // 应弹出设置底部弹窗
        expect(find.text('Settings'), findsAtLeast(1));
        expect(find.text('Sentence Repeat'), findsOneWidget);
        await _disposeTree(tester);
      });

      testWidgets('切换全文/书签 Tab', (tester) async {
        final item = createTestAudioItem();
        final sentences = createTestSentences(count: 3);

        await tester.pumpWidget(
          createTestScreen(
            const PlayerScreen(),
            overrides: _audioOverrides(
              practiceState: ListeningPracticeState(
                currentAudioItem: item,
                sentences: sentences,
                currentFullIndex: 0,
              ),
            ),
          ),
        );
        await tester.pump();

        // 点击书签标签
        await tester.tap(find.textContaining('Bookmarked'));
        // Tab 切换动画 300ms + 内容构建，分多次 pump 确保完成
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();

        // 应显示无书签提示
        expect(find.text('No bookmarked sentences'), findsOneWidget);
        await _disposeTree(tester);
      });

      testWidgets('点击句子编号区从该句开始播放', (tester) async {
        final item = createTestAudioItem();
        final sentences = createTestSentences(count: 3);

        await tester.pumpWidget(
          createTestScreen(
            const PlayerScreen(),
            overrides: _audioOverrides(
              practiceState: ListeningPracticeState(
                currentAudioItem: item,
                sentences: sentences,
                currentFullIndex: 0,
              ),
            ),
          ),
        );
        await tester.pump();

        // 初始：第 1 句播放（编号区显示 ▶），第 2 句编号区显示 '2'
        expect(find.text('2'), findsOneWidget);
        expect(find.text('1'), findsNothing);

        // 点击第 2 句编号区 → selectFullSentence(1) → currentFullIndex=1
        await tester.tap(find.text('2'));
        await tester.pump();

        // 第 2 句变为播放（▶），第 1 句编号区恢复显示 '1'
        expect(find.text('1'), findsOneWidget);
        expect(find.text('2'), findsNothing);
        await _disposeTree(tester);
      });

      testWidgets('点击句子主体进入讲解页', (tester) async {
        final item = createTestAudioItem();
        final sentences = createTestSentences(count: 3);

        await tester.pumpWidget(
          createTestScreen(
            const PlayerScreen(),
            overrides: _audioOverrides(
              practiceState: ListeningPracticeState(
                currentAudioItem: item,
                sentences: sentences,
                currentFullIndex: 0,
              ),
            ),
          ),
        );
        await tester.pump();

        // 点击第 1 句主体区（tile 中心落在文本区，非左侧编号区）
        await tester.tap(find.byType(MaskedSentenceTile).first);
        await tester.pumpAndSettle();

        // 导航到讲解页 stub
        expect(find.text('Sentence Detail'), findsOneWidget);
        await _disposeTree(tester);
      });
    });
  });
}
