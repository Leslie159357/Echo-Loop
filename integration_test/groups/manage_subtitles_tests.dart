/// 管理字幕集成测试
///
/// 验证管理字幕底部弹窗的完整流程：
/// - 打开弹窗、选项卡片切换
/// - 删除字幕确认流程
/// - AI 转录禁用逻辑（同语言已转录时）
/// - 覆盖确认对话框
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluency/models/audio_item.dart';

import '../helpers/test_notifiers.dart';

/// 管理字幕相关集成测试
void manageSubtitlesTests() {
  group('流程：管理字幕', () {
    testWidgets('无字幕音频 — 打开弹窗，显示选项卡片，本地上传默认选中', (tester) async {
      // 创建无字幕音频
      await tester.pumpWidget(
        createTestAppWithAudio(
          audioItemOverride: createTestAudioItem(transcriptPath: null),
        ),
      );
      await tester.pumpAndSettle();

      // 导航到资源库页 → 音频 Tab
      await tester.tap(find.byIcon(Icons.library_music_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Audio'));
      await tester.pumpAndSettle();

      // 打开弹出菜单
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      // 点击"管理字幕"
      await tester.tap(find.text('Manage Subtitles'));
      await tester.pumpAndSettle();

      // 弹窗出现 — 标题可见
      expect(find.text('Manage Subtitles'), findsWidgets);

      // 两个选项卡片都可见
      expect(find.text('Local Upload'), findsOneWidget);
      expect(find.text('AI Transcription'), findsOneWidget);

      // 本地上传默认选中 → 语言选择器不可见
      expect(find.text('Select Language'), findsNothing);

      // 无字幕时不显示删除图标按钮
      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });

    testWidgets('有本地字幕音频 — 显示删除图标按钮', (tester) async {
      await tester.pumpWidget(
        createTestAppWithAudio(
          audioItemOverride: AudioItem(
            id: 'test-audio-1',
            name: 'Test Audio',
            audioPath: 'audios/test.mp3',
            transcriptPath: 'transcripts/test.srt',
            addedDate: DateTime(2026, 1, 1),
            totalDuration: 120,
            transcriptSource: TranscriptSource.local,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 导航到资源库页 → 音频 Tab
      await tester.tap(find.byIcon(Icons.library_music_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Audio'));
      await tester.pumpAndSettle();

      // 打开管理字幕弹窗
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Manage Subtitles'));
      await tester.pumpAndSettle();

      // 删除图标按钮可见
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('删除字幕 — 确认后清除字幕', (tester) async {
      await tester.pumpWidget(
        createTestAppWithAudio(
          audioItemOverride: AudioItem(
            id: 'test-audio-1',
            name: 'Test Audio',
            audioPath: 'audios/test.mp3',
            transcriptPath: 'transcripts/test.srt',
            addedDate: DateTime(2026, 1, 1),
            totalDuration: 120,
            transcriptSource: TranscriptSource.local,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 导航到资源库页 → 音频 Tab
      await tester.tap(find.byIcon(Icons.library_music_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Audio'));
      await tester.pumpAndSettle();

      // 打开管理字幕弹窗
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Manage Subtitles'));
      await tester.pumpAndSettle();

      // 点击删除图标按钮
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      // 确认对话框出现
      expect(
        find.text('Are you sure you want to delete the subtitle?'),
        findsOneWidget,
      );

      // 点击"Delete"确认
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // 删除后删除图标按钮消失
      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });

    testWidgets('删除字幕 — 取消后无变化', (tester) async {
      await tester.pumpWidget(
        createTestAppWithAudio(
          audioItemOverride: AudioItem(
            id: 'test-audio-1',
            name: 'Test Audio',
            audioPath: 'audios/test.mp3',
            transcriptPath: 'transcripts/test.srt',
            addedDate: DateTime(2026, 1, 1),
            totalDuration: 120,
            transcriptSource: TranscriptSource.local,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 导航到资源库页 → 音频 Tab → 管理字幕
      await tester.tap(find.byIcon(Icons.library_music_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Audio'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Manage Subtitles'));
      await tester.pumpAndSettle();

      // 点击删除图标按钮
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      // 点击"Cancel"取消
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // 删除图标按钮仍在
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('AI 已转录(en) — 同语言按钮禁用，切换语言后可用', (tester) async {
      await tester.pumpWidget(
        createTestAppWithAudio(
          audioItemOverride: AudioItem(
            id: 'test-audio-1',
            name: 'Test Audio',
            audioPath: 'audios/test.mp3',
            transcriptPath: 'transcripts/test.srt',
            addedDate: DateTime(2026, 1, 1),
            totalDuration: 120,
            transcriptSource: TranscriptSource.ai,
            transcriptLanguage: 'en',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 导航到资源库页 → 音频 Tab → 管理字幕
      await tester.tap(find.byIcon(Icons.library_music_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Audio'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Manage Subtitles'));
      await tester.pumpAndSettle();

      // 状态显示 AI
      expect(find.textContaining('AI'), findsWidgets);

      // 切换到 AI 选项
      await tester.tap(find.text('AI Transcription'));
      await tester.pumpAndSettle();

      // AI 选中 + en 默认语言 → 禁用提示可见（提示文字 + 按钮文字各出现一次）
      expect(find.text('Already transcribed with this option'), findsWidgets);

      // 操作按钮不可点击
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);

      // 切换到 Mixed Languages
      await tester.tap(find.text('Mixed Languages'));
      await tester.pumpAndSettle();

      // 禁用提示消失（提示文字不再显示，按钮文字变为"Start Transcription"）
      expect(find.text('Already transcribed with this option'), findsNothing);

      // 按钮变为可点击
      final updatedButton = tester.widget<FilledButton>(
        find.byType(FilledButton),
      );
      expect(updatedButton.onPressed, isNotNull);
    });

    testWidgets('切换选项 — 按钮文字正确变化', (tester) async {
      await tester.pumpWidget(
        createTestAppWithAudio(
          audioItemOverride: createTestAudioItem(transcriptPath: null),
        ),
      );
      await tester.pumpAndSettle();

      // 导航到资源库页 → 音频 Tab → 管理字幕
      await tester.tap(find.byIcon(Icons.library_music_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Audio'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Manage Subtitles'));
      await tester.pumpAndSettle();

      // 本地上传默认选中 → 按钮文字为"上传字幕"
      expect(
        find.widgetWithText(FilledButton, 'Upload Transcript'),
        findsOneWidget,
      );

      // 语言选择器不可见
      expect(find.text('Select Language'), findsNothing);

      // 切换到 AI
      await tester.tap(find.text('AI Transcription'));
      await tester.pumpAndSettle();

      // 语言选择器重新出现
      expect(find.text('Select Language'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Start Transcription'),
        findsOneWidget,
      );
    });

    testWidgets('有字幕时选本地上传 — 弹覆盖确认', (tester) async {
      await tester.pumpWidget(
        createTestAppWithAudio(
          audioItemOverride: AudioItem(
            id: 'test-audio-1',
            name: 'Test Audio',
            audioPath: 'audios/test.mp3',
            transcriptPath: 'transcripts/test.srt',
            addedDate: DateTime(2026, 1, 1),
            totalDuration: 120,
            transcriptSource: TranscriptSource.local,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 导航到资源库页 → 音频 Tab → 管理字幕
      await tester.tap(find.byIcon(Icons.library_music_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Audio'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Manage Subtitles'));
      await tester.pumpAndSettle();

      // 切换到本地上传
      await tester.tap(find.text('Local Upload'));
      await tester.pumpAndSettle();

      // 点击上传按钮
      await tester.tap(find.widgetWithText(FilledButton, 'Upload Transcript'));
      await tester.pumpAndSettle();

      // 覆盖确认对话框出现
      expect(find.text('Overwrite existing subtitle?'), findsOneWidget);

      // 取消 → 无变化
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // 弹窗仍在（删除图标按钮仍可见）
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });
  });
}
