/// 学习计划页面集成测试
///
/// 验证学习计划表的展示、交互和进度回显。
/// 包含 5 个测试场景：页面展示、开始学习、无字幕禁用、进度回显、继续学习进入精听。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluency/database/enums.dart';
import 'package:fluency/main.dart';
import 'package:fluency/providers/audio_library_provider.dart';
import 'package:fluency/router/app_router.dart';
import 'package:fluency/widgets/blind_listen_briefing_sheet.dart';
import 'package:fluency/widgets/intensive_listen/intensive_listen_briefing_sheet.dart';

import '../helpers/test_notifiers.dart';

/// 学习计划页面集成测试
void learningPlanTests() {
  group('流程 4：学习计划页', () {
    /// 导航到学习计划页的辅助方法
    Future<void> navigateToLearningPlan(WidgetTester tester) async {
      await tester.pumpAndSettle();
      // 通过 appRouterProvider 直接导航到学习计划页
      final context = tester.element(find.byType(FluencyApp));
      final container = ProviderScope.containerOf(context);
      container
          .read(appRouterProvider)
          .push('/collections/test-collection-1/test-audio-1/plan');
      await tester.pumpAndSettle();
    }

    testWidgets('学习计划页展示 4 个首次学习步骤', (tester) async {
      await tester.pumpWidget(createTestAppWithAudio());
      await navigateToLearningPlan(tester);

      // 验证 4 个首次学习步骤卡片
      expect(find.text('Blind Listening'), findsWidgets);
      expect(find.text('Intensive Listening'), findsOneWidget);
      expect(find.text('Listen & Repeat'), findsOneWidget);
      expect(find.text('Retelling'), findsOneWidget);

      // 验证首次学习标题
      expect(find.text('First Study'), findsOneWidget);

      // 验证底部按钮显示"Start Learning"
      expect(find.text('Start Learning'), findsOneWidget);
    });

    testWidgets('点击"开始学习"弹出盲听简报', (tester) async {
      await tester.pumpWidget(createTestAppWithAudio());
      await navigateToLearningPlan(tester);

      // 点击"Start Learning"
      await tester.tap(find.text('Start Learning'));
      await tester.pumpAndSettle();

      // 验证盲听简报弹窗出现
      expect(find.byType(BlindListenBriefingSheet), findsOneWidget);
      // 验证"开始练习"按钮
      expect(find.text('Start Practice'), findsOneWidget);
    });

    testWidgets('无字幕时按钮禁用且显示警告横幅', (tester) async {
      // 使用无 transcriptPath 的 AudioItem
      final audioItemNoTranscript = createTestAudioItem(transcriptPath: null);
      final progress = createTestLearningProgress(
        currentStageStartedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        createTestAppWithAudio(progressOverride: progress),
      );
      await tester.pumpAndSettle();

      // 替换音频为无字幕版本
      final context = tester.element(find.byType(FluencyApp));
      final container = ProviderScope.containerOf(context);
      final audioLib =
          container.read(audioLibraryProvider.notifier) as TestAudioLibrary;
      // 先移除有字幕的，再加入无字幕的
      await audioLib.removeAudioItem('test-audio-1');
      await audioLib.addAudioItem(audioItemNoTranscript);

      // 导航到学习计划页
      container
          .read(appRouterProvider)
          .push('/collections/test-collection-1/test-audio-1/plan');
      await tester.pumpAndSettle();

      // 验证警告横幅出现（warning 图标）
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);

      // 验证底部按钮存在但被禁用
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Start Learning'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('盲听已完成时显示完成标记和"继续学习"', (tester) async {
      // 预设进度：盲听已完成，当前为精听阶段
      final progress = createTestLearningProgress(
        currentStage: LearningStage.firstLearn,
        currentSubStage: SubStageType.intensiveListen,
        blindListenPassCount: 2,
        currentStageStartedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        createTestAppWithAudio(progressOverride: progress),
      );
      await navigateToLearningPlan(tester);

      // 验证盲听步骤显示完成标记（绿色勾图标）
      expect(find.byIcon(Icons.check), findsWidgets);

      // 验证底部按钮文案为"Continue Learning"
      expect(find.text('Continue Learning'), findsOneWidget);
      expect(find.text('Start Learning'), findsNothing);
    });

    testWidgets('精听阶段点击"继续学习"弹出精听简报', (tester) async {
      // 预设进度：当前为精听阶段
      final progress = createTestLearningProgress(
        currentStage: LearningStage.firstLearn,
        currentSubStage: SubStageType.intensiveListen,
        blindListenPassCount: 2,
        currentStageStartedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        createTestAppWithAudio(progressOverride: progress),
      );
      await navigateToLearningPlan(tester);

      // 点击"Continue Learning"（用 last 避免匹配学习页 Hero Card 的同名文本）
      await tester.tap(find.text('Continue Learning').last);
      await tester.pumpAndSettle();

      // 验证弹出的是精听简报（而非盲听简报）
      expect(find.byType(IntensiveListenBriefingSheet), findsOneWidget);
      expect(find.byType(BlindListenBriefingSheet), findsNothing);
      // 验证"开始练习"按钮
      expect(find.text('Start Practice'), findsOneWidget);
    });
  });
}
