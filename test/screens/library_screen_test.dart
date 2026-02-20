/// LibraryScreen 测试
///
/// 测试音频库页面的渲染和交互。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluency/screens/library_screen.dart';
import 'package:fluency/providers/settings_provider.dart';
import 'package:fluency/providers/audio_library_provider.dart';
import 'package:fluency/providers/collection_provider.dart';
import 'package:fluency/providers/listening_practice/listening_practice_provider.dart';
import 'package:fluency/providers/audio_engine/audio_engine_provider.dart';

import '../helpers/mock_providers.dart';
import '../helpers/test_app.dart';

void main() {
  group('LibraryScreen', () {
    group('渲染', () {
      testWidgets('空状态显示提示文案', (tester) async {
        await tester.pumpWidget(
          createTestScreen(const LibraryScreen()),
        );
        await tester.pumpAndSettle();

        // 空状态图标和文案
        expect(find.byIcon(Icons.library_music_outlined), findsOneWidget);
        expect(find.text('No audio files yet'), findsOneWidget);
        expect(find.text('Tap + to add your first audio'), findsOneWidget);
      });

      testWidgets('显示 AppBar 标题', (tester) async {
        await tester.pumpWidget(
          createTestScreen(const LibraryScreen()),
        );
        await tester.pumpAndSettle();

        expect(find.text('Audio Library'), findsOneWidget);
      });

      testWidgets('显示添加按钮', (tester) async {
        await tester.pumpWidget(
          createTestScreen(const LibraryScreen()),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.add), findsOneWidget);
      });

      testWidgets('有音频时显示音频列表', (tester) async {
        final item1 = createTestAudioItem(
          id: '1',
          name: 'Audio One',
          transcriptPath: 'transcripts/one.srt',
        );
        final item2 = createTestAudioItem(
          id: '2',
          name: 'Audio Two',
          transcriptPath: null,
        );

        await tester.pumpWidget(
          createTestScreen(
            const LibraryScreen(),
            overrides: [
              appSettingsProvider.overrideWith(() => TestAppSettings()),
              audioLibraryProvider.overrideWith(
                () => TestAudioLibrary(
                  AudioLibraryState(audioItems: [item1, item2]),
                ),
              ),
              collectionListProvider.overrideWith(
                () => TestCollectionList(),
              ),
              listeningPracticeProvider.overrideWith(
                () => TestListeningPractice(),
              ),
              audioEngineProvider.overrideWith(() => TestAudioEngine()),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // 音频名称
        expect(find.text('Audio One'), findsOneWidget);
        expect(find.text('Audio Two'), findsOneWidget);
      });

      testWidgets('有字幕的音频显示字幕图标', (tester) async {
        final itemWithTranscript = createTestAudioItem(
          id: '1',
          name: 'With Transcript',
          transcriptPath: 'transcripts/test.srt',
        );
        final itemWithout = createTestAudioItem(
          id: '2',
          name: 'Without Transcript',
          transcriptPath: null,
        );

        await tester.pumpWidget(
          createTestScreen(
            const LibraryScreen(),
            overrides: [
              appSettingsProvider.overrideWith(() => TestAppSettings()),
              audioLibraryProvider.overrideWith(
                () => TestAudioLibrary(
                  AudioLibraryState(
                    audioItems: [itemWithTranscript, itemWithout],
                  ),
                ),
              ),
              collectionListProvider.overrideWith(
                () => TestCollectionList(),
              ),
              listeningPracticeProvider.overrideWith(
                () => TestListeningPractice(),
              ),
              audioEngineProvider.overrideWith(() => TestAudioEngine()),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // 有字幕的显示字幕图标
        expect(find.byIcon(Icons.subtitles), findsOneWidget);
        // 字幕文案出现一次
        expect(find.text('Transcript'), findsOneWidget);
      });

      testWidgets('加载中显示进度指示器', (tester) async {
        await tester.pumpWidget(
          createTestScreen(
            const LibraryScreen(),
            overrides: [
              appSettingsProvider.overrideWith(() => TestAppSettings()),
              audioLibraryProvider.overrideWith(
                () => TestAudioLibrary(
                  const AudioLibraryState(isLoading: true),
                ),
              ),
              collectionListProvider.overrideWith(
                () => TestCollectionList(),
              ),
              listeningPracticeProvider.overrideWith(
                () => TestListeningPractice(),
              ),
              audioEngineProvider.overrideWith(() => TestAudioEngine()),
            ],
          ),
        );
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('当前播放的音频显示 Playing 标识', (tester) async {
        final item = createTestAudioItem(id: '1', name: 'Current Audio');

        await tester.pumpWidget(
          createTestScreen(
            const LibraryScreen(),
            overrides: [
              appSettingsProvider.overrideWith(() => TestAppSettings()),
              audioLibraryProvider.overrideWith(
                () => TestAudioLibrary(
                  AudioLibraryState(audioItems: [item]),
                ),
              ),
              collectionListProvider.overrideWith(
                () => TestCollectionList(),
              ),
              listeningPracticeProvider.overrideWith(
                () => TestListeningPractice(
                  ListeningPracticeState(currentAudioItem: item),
                ),
              ),
              audioEngineProvider.overrideWith(() => TestAudioEngine()),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // 应显示 "Playing" 标识
        expect(find.text('Playing'), findsOneWidget);
      });
    });

    group('交互', () {
      testWidgets('点击 + 按钮弹出添加对话框', (tester) async {
        await tester.pumpWidget(
          createTestScreen(const LibraryScreen()),
        );
        await tester.pumpAndSettle();

        // 点击添加按钮
        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();

        // 应弹出添加音频对话框
        expect(find.text('Add Audio'), findsOneWidget);
        expect(find.text('Select Audio File'), findsOneWidget);
      });

      testWidgets('删除菜单弹出确认对话框', (tester) async {
        final item = createTestAudioItem(id: '1', name: 'Delete Me');

        await tester.pumpWidget(
          createTestScreen(
            const LibraryScreen(),
            overrides: [
              appSettingsProvider.overrideWith(() => TestAppSettings()),
              audioLibraryProvider.overrideWith(
                () => TestAudioLibrary(
                  AudioLibraryState(audioItems: [item]),
                ),
              ),
              collectionListProvider.overrideWith(
                () => TestCollectionList(),
              ),
              listeningPracticeProvider.overrideWith(
                () => TestListeningPractice(),
              ),
              audioEngineProvider.overrideWith(() => TestAudioEngine()),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // 点击更多菜单（PopupMenuButton 默认渲染 more_vert 图标）
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();

        // 点击删除选项
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        // 应弹出确认对话框
        expect(find.text('Delete Audio'), findsOneWidget);
      });
    });
  });
}
