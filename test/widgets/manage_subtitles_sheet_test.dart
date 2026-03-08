import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluency/models/audio_item.dart';
import 'package:fluency/providers/audio_library_provider.dart';
import 'package:fluency/providers/collection_provider.dart';
import 'package:fluency/providers/tag_provider.dart';
import 'package:fluency/providers/listening_practice/listening_practice_provider.dart';
import 'package:fluency/providers/audio_engine/audio_engine_provider.dart';
import 'package:fluency/providers/learning_progress_provider.dart';
import 'package:fluency/providers/learning_session/learning_session_provider.dart';
import 'package:fluency/providers/learning_session/blind_listen_player_provider.dart';
import 'package:fluency/providers/settings_provider.dart';
import 'package:fluency/providers/transcription_task_provider.dart';
import 'package:fluency/services/transcription_api_client.dart';
import 'package:fluency/widgets/manage_subtitles_sheet.dart';

import '../helpers/mock_providers.dart';
import '../helpers/test_app.dart';

void main() {
  group('ManageSubtitlesSheet', () {
    /// 构建弹窗测试 App（包含所有必要的 provider override）
    Widget buildSheet(
      AudioItem audioItem, {
      LearningProgressState? progressState,
    }) {
      final libraryState = AudioLibraryState(audioItems: [audioItem]);
      return createTestApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => ManageSubtitlesSheet(audioItem: audioItem),
              );
            },
            child: const Text('Open'),
          ),
        ),
        overrides: [
          appSettingsProvider.overrideWith(
            () => TestAppSettings(const AppSettingsState(locale: Locale('en'))),
          ),
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(libraryState),
          ),
          collectionListProvider.overrideWith(() => TestCollectionList()),
          tagListProvider.overrideWith(() => TestTagList()),
          listeningPracticeProvider.overrideWith(() => TestListeningPractice()),
          audioEngineProvider.overrideWith(() => TestAudioEngine()),
          learningProgressNotifierProvider.overrideWith(
            () => TestLearningProgressNotifier(
              progressState ?? const LearningProgressState(),
            ),
          ),
          learningSessionProvider.overrideWith(() => TestLearningSession()),
          blindListenPlayerProvider.overrideWith(() => TestBlindListenPlayer()),
          transcriptionTaskManagerProvider.overrideWith(
            () => TestTranscriptionTaskManager(),
          ),
          transcriptionApiClientProvider.overrideWith(
            (ref) => createTestTranscriptionApiClient(),
          ),
        ],
      );
    }

    group('初始状态', () {
      testWidgets('无字幕音频：显示两个 Radio 选项，无删除按钮', (tester) async {
        final item = createTestAudioItem(transcriptPath: null);
        await tester.pumpWidget(buildSheet(item));
        await tester.pumpAndSettle();

        // 打开弹窗
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        // 两个 Radio 选项
        expect(find.text('Local Upload'), findsOneWidget);
        expect(find.text('AI Transcription'), findsOneWidget);

        // 无删除按钮
        expect(find.byTooltip('Delete Subtitle'), findsNothing);
      });

      testWidgets('有本地字幕音频：显示状态文字和删除按钮', (tester) async {
        final item = createTestAudioItem().copyWith(
          transcriptSource: TranscriptSource.local,
        );
        await tester.pumpWidget(buildSheet(item));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        // 有删除按钮（标题栏右侧图标按钮）
        expect(find.byTooltip('Delete Subtitle'), findsOneWidget);
      });

      testWidgets('有 AI(en) 字幕音频：AI 同语言禁用', (tester) async {
        final item = createTestAudioItem().copyWith(
          transcriptSource: TranscriptSource.ai,
          transcriptLanguage: 'en',
        );
        await tester.pumpWidget(buildSheet(item));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        // 切换到 AI 选项
        await tester.tap(find.text('AI Transcription'));
        await tester.pumpAndSettle();

        // AI 选中 + en 默认选中 → 按钮显示"已使用该选项转录"
        expect(
          find.text('Already transcribed with this option'),
          findsAtLeast(1),
        );
      });
    });

    group('交互', () {
      testWidgets('切换 Radio 选项：按钮文字正确切换', (tester) async {
        final item = createTestAudioItem(transcriptPath: null);
        await tester.pumpWidget(buildSheet(item));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        // 默认本地上传 → FilledButton 显示"上传字幕"
        expect(
          find.widgetWithText(FilledButton, 'Upload Transcript'),
          findsOneWidget,
        );

        // 切换到 AI 转录
        await tester.tap(find.text('AI Transcription'));
        await tester.pumpAndSettle();

        // FilledButton 显示"开始转录"
        expect(
          find.widgetWithText(FilledButton, 'Start Transcription'),
          findsOneWidget,
        );
      });

      testWidgets('删除按钮弹出确认对话框', (tester) async {
        final item = createTestAudioItem().copyWith(
          transcriptSource: TranscriptSource.local,
        );
        await tester.pumpWidget(buildSheet(item));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        // 点击删除图标按钮
        await tester.tap(find.byTooltip('Delete Subtitle'));
        await tester.pumpAndSettle();

        // 确认对话框出现
        expect(
          find.text('Are you sure you want to delete the subtitle?'),
          findsOneWidget,
        );
        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('Delete'), findsOneWidget);
      });

      testWidgets('取消删除不影响状态', (tester) async {
        final item = createTestAudioItem().copyWith(
          transcriptSource: TranscriptSource.local,
        );
        await tester.pumpWidget(buildSheet(item));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Delete Subtitle'));
        await tester.pumpAndSettle();

        // 点击取消
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        // 删除按钮仍在（状态不变）
        expect(find.byTooltip('Delete Subtitle'), findsOneWidget);
      });

      testWidgets('AI(en) 已转录 + 选中 multi → 按钮可点击', (tester) async {
        final item = createTestAudioItem().copyWith(
          transcriptSource: TranscriptSource.ai,
          transcriptLanguage: 'en',
        );
        await tester.pumpWidget(buildSheet(item));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        // 切换到 AI 选项
        await tester.tap(find.text('AI Transcription'));
        await tester.pumpAndSettle();

        // 切换语言到 multi
        await tester.tap(find.text('Mixed Languages'));
        await tester.pumpAndSettle();

        // 按钮显示"开始转录"且可点击
        final filledButton = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Start Transcription'),
        );
        expect(filledButton.onPressed, isNotNull);
      });
    });

    group('删除字幕警告', () {
      testWidgets('删除确认显示收藏句子警告', (tester) async {
        final item = createTestAudioItem().copyWith(
          transcriptSource: TranscriptSource.local,
        );
        await tester.pumpWidget(buildSheet(item));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Delete Subtitle'));
        await tester.pumpAndSettle();

        // 显示收藏句子删除警告
        expect(
          find.text(
            'Deleting the subtitle will also remove all bookmarked sentences for this audio.',
          ),
          findsOneWidget,
        );
      });
    });

    group('语言选择 UI', () {
      testWidgets('AI 选中时显示语言选择', (tester) async {
        final item = createTestAudioItem(transcriptPath: null);
        await tester.pumpWidget(buildSheet(item));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        // 默认本地上传 → 语言选择隐藏
        expect(find.text('Select Language'), findsNothing);

        // 切换到 AI → 语言选择显示
        await tester.tap(find.text('AI Transcription'));
        await tester.pumpAndSettle();

        expect(find.text('Select Language'), findsOneWidget);
        expect(find.text('English'), findsOneWidget);
        expect(find.text('Mixed Languages'), findsOneWidget);
      });

      testWidgets('本地上传选中时隐藏语言选择', (tester) async {
        final item = createTestAudioItem(transcriptPath: null);
        await tester.pumpWidget(buildSheet(item));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        // 切换到 AI
        await tester.tap(find.text('AI Transcription'));
        await tester.pumpAndSettle();
        expect(find.text('Select Language'), findsOneWidget);

        // 切换回本地上传
        await tester.tap(find.text('Local Upload'));
        await tester.pumpAndSettle();

        // 语言选择隐藏
        expect(find.text('Select Language'), findsNothing);
      });
    });
  });
}
