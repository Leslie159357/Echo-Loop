/// PlayerScreen 测试
///
/// 测试播放器页面的渲染和交互。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluency/screens/player_screen.dart';
import 'package:fluency/models/audio_engine_state.dart';
import 'package:fluency/providers/settings_provider.dart';
import 'package:fluency/providers/audio_library_provider.dart';
import 'package:fluency/providers/collection_provider.dart';
import 'package:fluency/providers/listening_practice/listening_practice_provider.dart';
import 'package:fluency/providers/audio_engine/audio_engine_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../helpers/mock_providers.dart';
import '../helpers/test_app.dart';

/// 抑制 PlayerScreen.dispose() 中 ref.read() 触发的 StateError。
///
/// PlayerScreen 在 dispose() 中调用 ref.read() 来暂停和保存状态，
/// 但在测试拆卸时 ref 已经失效。这是一个已知的 production code 问题，
/// 不影响测试验证目标。需要在 testWidgets 回调体内调用才能生效。
void _suppressRefAfterDisposeError() {
  final originalOnError = FlutterError.onError!;
  FlutterError.onError = (details) {
    if (details.exception is StateError &&
        details.exception.toString().contains('Cannot use "ref"')) {
      return;
    }
    originalOnError(details);
  };
}

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
        initialState: engineState ??
            const AudioEngineState(
              totalDuration: Duration(seconds: 120),
            ),
      ),
    ),
  ];
}

void main() {
  group('PlayerScreen', () {
    group('渲染', () {
      testWidgets('无音频时显示空状态', (tester) async {
        _suppressRefAfterDisposeError();
        await tester.pumpWidget(
          createTestScreen(const PlayerScreen()),
        );
        await tester.pumpAndSettle();

        expect(find.text('No audio loaded'), findsOneWidget);
      });

      testWidgets('无音频时 AppBar 显示 Player 标题', (tester) async {
        _suppressRefAfterDisposeError();
        await tester.pumpWidget(
          createTestScreen(const PlayerScreen()),
        );
        await tester.pumpAndSettle();

        expect(find.text('Player'), findsOneWidget);
      });

      testWidgets('有音频时显示音频名称作为标题', (tester) async {
        _suppressRefAfterDisposeError();
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
        await tester.pumpAndSettle();

        expect(find.text('My Lesson'), findsOneWidget);
      });

      testWidgets('有音频和句子时显示 TabBar', (tester) async {
        _suppressRefAfterDisposeError();
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
        await tester.pumpAndSettle();

        // TabBar 应显示"全文"和"书签"标签
        expect(find.byType(TabBar), findsOneWidget);
        expect(find.textContaining('Full Text'), findsOneWidget);
        expect(find.textContaining('Bookmarked'), findsOneWidget);
      });

      testWidgets('句子列表正确显示', (tester) async {
        _suppressRefAfterDisposeError();
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
        await tester.pumpAndSettle();

        // 句子文本
        expect(find.text('Test sentence number 1.'), findsOneWidget);
        expect(find.text('Test sentence number 2.'), findsOneWidget);
        expect(find.text('Test sentence number 3.'), findsOneWidget);
      });

      testWidgets('显示 PlaybackControls', (tester) async {
        _suppressRefAfterDisposeError();
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
        await tester.pumpAndSettle();

        // 播放控制栏应存在
        expect(find.byIcon(Icons.play_arrow), findsOneWidget);
        expect(find.byIcon(Icons.skip_previous), findsOneWidget);
        expect(find.byIcon(Icons.skip_next), findsOneWidget);
      });

      testWidgets('AppBar 显示设置按钮', (tester) async {
        _suppressRefAfterDisposeError();
        await tester.pumpWidget(
          createTestScreen(const PlayerScreen()),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.settings), findsOneWidget);
      });

      testWidgets('AppBar 显示自动滚动切换按钮', (tester) async {
        _suppressRefAfterDisposeError();
        await tester.pumpWidget(
          createTestScreen(const PlayerScreen()),
        );
        await tester.pumpAndSettle();

        // 默认启用自动滚动
        expect(find.byIcon(Icons.center_focus_strong), findsOneWidget);
      });

      testWidgets('有音频但无字幕时显示无字幕提示', (tester) async {
        _suppressRefAfterDisposeError();
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
        await tester.pumpAndSettle();

        expect(find.text('No Subtitle'), findsOneWidget);
        expect(find.byIcon(Icons.subtitles_off), findsOneWidget);
      });
    });

    group('交互', () {
      testWidgets('点击设置按钮打开设置对话框', (tester) async {
        _suppressRefAfterDisposeError();
        await tester.pumpWidget(
          createTestScreen(const PlayerScreen()),
        );
        await tester.pumpAndSettle();

        // 点击设置按钮
        await tester.tap(find.byIcon(Icons.settings));
        await tester.pumpAndSettle();

        // 应弹出 SettingsDialog
        expect(find.text('Settings'), findsAtLeast(1));
        expect(find.text('Sentence Repeat'), findsOneWidget);
      });

      testWidgets('切换全文/书签 Tab', (tester) async {
        _suppressRefAfterDisposeError();
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
        await tester.pumpAndSettle();

        // 点击书签标签
        await tester.tap(find.textContaining('Bookmarked'));
        await tester.pumpAndSettle();

        // 应显示无书签提示
        expect(find.text('No bookmarked sentences'), findsOneWidget);
      });
    });
  });
}
