/// 精听播放器集成测试
///
/// 验证精听播放器的 UI 展示、偷看字幕、导航、标注模式、完成对话框和退出保存断点。
/// 包含 7 个测试场景。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluency/main.dart';
import 'package:fluency/database/enums.dart';
import 'package:fluency/providers/learning_progress_provider.dart';
import 'package:fluency/providers/learning_session/intensive_listen_player_provider.dart';
import 'package:fluency/providers/learning_session/learning_session_provider.dart';
import 'package:fluency/router/app_router.dart';
import 'package:fluency/screens/intensive_listen_player_screen.dart';
import 'package:fluency/widgets/intensive_listen/sentence_annotation_card.dart';

import '../helpers/test_notifiers.dart';

/// 精听播放器集成测试
void intensiveListenTests() {
  group('流程 6：精听播放器', () {
    /// 导航到精听播放器的辅助方法
    ///
    /// 需要先设置 LearningSession 为精听模式，
    /// 并初始化 IntensiveListenPlayer 句子数据。
    Future<void> navigateToIntensiveListen(WidgetTester tester) async {
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(FluencyApp));
      final container = ProviderScope.containerOf(context);

      // 设置学习会话为精听模式
      final session =
          container.read(learningSessionProvider.notifier) as TestLearningSession;
      session.setState(const LearningSessionState(
        learningMode: LearningMode.intensiveListen,
        audioItemId: 'test-audio-1',
      ));

      // 初始化精听播放器的句子数据
      final player = container.read(intensiveListenPlayerProvider.notifier)
          as TestIntensiveListenPlayer;
      final sentences = createTestSentences();
      player.setTestSentences(sentences);
      player.setState(IntensiveListenState(
        currentSentenceIndex: 0,
        totalSentences: sentences.length,
      ));

      container.read(appRouterProvider).push(
        '/collections/test-collection-1/test-audio-1/intensive-listen',
      );
      await tester.pumpAndSettle();
    }

    /// 获取 ProviderContainer 辅助方法
    ProviderContainer getContainer(WidgetTester tester) {
      final context = tester.element(find.byType(IntensiveListenPlayerScreen));
      return ProviderScope.containerOf(context);
    }

    testWidgets('精听页面基本 UI', (tester) async {
      await tester.pumpWidget(createTestAppWithAudio(
        progressOverride: createTestLearningProgress(
          currentSubStage: SubStageType.intensiveListen,
          currentStageStartedAt: DateTime.now(),
        ),
      ));
      await navigateToIntensiveListen(tester);

      // 验证 AppBar 标题
      expect(find.text('Intensive Listening'), findsOneWidget);

      // 验证进度条
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      // 验证播放控制按钮
      expect(find.byIcon(Icons.skip_previous), findsOneWidget);
      expect(find.byIcon(Icons.skip_next), findsOneWidget);
      // 进入后自动播放 → pause 图标
      expect(find.byIcon(Icons.pause), findsOneWidget);

      // 验证偷看和听不懂按钮
      expect(find.text('Peek'), findsOneWidget);
      expect(find.text("Can't understand"), findsOneWidget);
    });

    testWidgets('偷看字幕切换', (tester) async {
      await tester.pumpWidget(createTestAppWithAudio(
        progressOverride: createTestLearningProgress(
          currentSubStage: SubStageType.intensiveListen,
          currentStageStartedAt: DateTime.now(),
        ),
      ));
      await navigateToIntensiveListen(tester);

      // 初始状态：文字隐藏
      expect(find.text('Test sentence number 1.'), findsNothing);

      // 点击"Peek"
      await tester.tap(find.text('Peek'));
      await tester.pumpAndSettle();

      // 验证文本显示
      expect(find.text('Test sentence number 1.'), findsOneWidget);
      // 按钮文案变为"Hide"
      expect(find.text('Hide'), findsOneWidget);

      // 再点击隐藏
      await tester.tap(find.text('Hide'));
      await tester.pumpAndSettle();

      // 验证文本隐藏
      expect(find.text('Test sentence number 1.'), findsNothing);
      // 按钮文案变回"Peek"
      expect(find.text('Peek'), findsOneWidget);
    });

    testWidgets('上一句/下一句导航', (tester) async {
      await tester.pumpWidget(createTestAppWithAudio(
        progressOverride: createTestLearningProgress(
          currentSubStage: SubStageType.intensiveListen,
          currentStageStartedAt: DateTime.now(),
        ),
      ));
      await navigateToIntensiveListen(tester);

      // 初始在第 1 句（索引 0），进度显示 "Intensive 1/5"
      expect(find.textContaining('1/5'), findsOneWidget);

      // 点击下一句
      await tester.tap(find.byIcon(Icons.skip_next));
      await tester.pumpAndSettle();

      // 验证进度变为 2/5
      expect(find.textContaining('2/5'), findsOneWidget);

      // 再点击下一句
      await tester.tap(find.byIcon(Icons.skip_next));
      await tester.pumpAndSettle();

      // 验证进度变为 3/5
      expect(find.textContaining('3/5'), findsOneWidget);

      // 点击上一句
      await tester.tap(find.byIcon(Icons.skip_previous));
      await tester.pumpAndSettle();

      // 验证进度回到 2/5
      expect(find.textContaining('2/5'), findsOneWidget);
    });

    testWidgets('标注模式进入', (tester) async {
      await tester.pumpWidget(createTestAppWithAudio(
        progressOverride: createTestLearningProgress(
          currentSubStage: SubStageType.intensiveListen,
          currentStageStartedAt: DateTime.now(),
        ),
      ));
      await navigateToIntensiveListen(tester);

      // 点击"Can't understand"进入标注模式
      await tester.tap(find.text("Can't understand"));
      await tester.pumpAndSettle();

      // 验证标注卡片出现
      expect(find.byType(SentenceAnnotationCard), findsOneWidget);
      // 验证"Continue"按钮
      expect(find.text('Continue'), findsOneWidget);
      // 偷看和听不懂按钮应消失
      expect(find.text('Peek'), findsNothing);
      expect(find.text("Can't understand"), findsNothing);
    });

    testWidgets('标注模式退出', (tester) async {
      await tester.pumpWidget(createTestAppWithAudio(
        progressOverride: createTestLearningProgress(
          currentSubStage: SubStageType.intensiveListen,
          currentStageStartedAt: DateTime.now(),
        ),
      ));
      await navigateToIntensiveListen(tester);

      // 进入标注模式
      await tester.tap(find.text("Can't understand"));
      await tester.pumpAndSettle();

      // 验证标注卡片存在
      expect(find.byType(SentenceAnnotationCard), findsOneWidget);

      // 点击"Continue"退出标注模式
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // 验证标注卡片消失
      expect(find.byType(SentenceAnnotationCard), findsNothing);
    });

    testWidgets('精听完成对话框', (tester) async {
      await tester.pumpWidget(createTestAppWithAudio(
        progressOverride: createTestLearningProgress(
          currentSubStage: SubStageType.intensiveListen,
          currentStageStartedAt: DateTime.now(),
        ),
      ));
      await navigateToIntensiveListen(tester);

      final container = getContainer(tester);

      // 触发完成：设置 isCompleted = true
      final player = container.read(intensiveListenPlayerProvider.notifier)
          as TestIntensiveListenPlayer;
      player.setState(player.state.copyWith(isCompleted: true));
      await tester.pumpAndSettle();

      // 验证完成对话框弹出
      expect(find.text('Intensive Listening Complete'), findsOneWidget);
      // 验证步骤进度信息
      expect(find.textContaining('2/4'), findsOneWidget);
      // 精听后的步骤（listenAndRepeat）有播放器，显示"继续"和"返回计划"两个按钮
      expect(find.text('Back to Plan'), findsOneWidget);
      expect(find.textContaining('Continue'), findsOneWidget);
    });

    testWidgets('精听中退出保存断点', (tester) async {
      await tester.pumpWidget(createTestAppWithAudio(
        progressOverride: createTestLearningProgress(
          currentSubStage: SubStageType.intensiveListen,
          currentStageStartedAt: DateTime.now(),
        ),
      ));
      await navigateToIntensiveListen(tester);

      // 导航到第 3 句（索引 2）
      await tester.tap(find.byIcon(Icons.skip_next));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.skip_next));
      await tester.pumpAndSettle();

      // 验证当前在第 3 句
      expect(find.textContaining('3/5'), findsOneWidget);

      // 点击返回按钮触发退出
      final backButton = find.byType(BackButton);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // 验证确认对话框弹出
      expect(find.text('Exit Intensive Listening?'), findsOneWidget);

      // 点击"Exit"确认退出
      await tester.tap(find.text('Exit'));
      await tester.pumpAndSettle();

      // 验证精听页面已退出
      expect(find.byType(IntensiveListenPlayerScreen), findsNothing);

      // 验证断点已保存（通过检查进度 state）
      final context = tester.element(find.byType(FluencyApp));
      final container2 = ProviderScope.containerOf(context);
      final progressState = container2.read(learningProgressNotifierProvider);
      final progress = progressState.progressMap['test-audio-1'];
      expect(progress?.intensiveListenSentenceIndex, equals(2));
    });
  });
}
