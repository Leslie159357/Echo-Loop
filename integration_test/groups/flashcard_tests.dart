/// Flashcard 单词卡片复习集成测试
///
/// 验证卡片显示、翻转交互、前后切换、完成流程、退出清理等端到端行为。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluency/main.dart';
import 'package:fluency/database/app_database.dart' show SavedWord;
import 'package:fluency/providers/flashcard/flashcard_provider.dart';
import 'package:fluency/models/flashcard_settings.dart';
import 'package:fluency/router/app_router.dart';
import 'package:fluency/screens/flashcard_screen.dart';

import '../helpers/test_notifiers.dart';

// ========== 测试数据工厂 ==========

SavedWord _createWord({
  required int id,
  required String word,
  int practiceCount = 0,
}) {
  return SavedWord(
    id: id,
    word: word,
    audioItemId: null,
    sentenceIndex: null,
    sentenceText: null,
    sentenceStartMs: null,
    sentenceEndMs: null,
    practiceCount: practiceCount,
    totalStudyMs: 0,
    viewedBack: false,
    lastPracticedAt: null,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    deletedAt: null,
    syncStatus: 0,
  );
}

List<FlashcardWordItem> _createWordItems(int count) {
  return List.generate(count, (i) {
    return FlashcardWordItem(
      savedWord: _createWord(id: i + 1, word: 'word${i + 1}'),
    );
  });
}

/// Flashcard 集成测试
void flashcardTests() {
  group('流程 10：Flashcard 单词卡片复习', () {
    // ========== 导航 + 基本显示 ==========

    testWidgets('导航到 Flashcard 页面并显示卡片', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // 获取容器和 notifier
      final context = tester.element(find.byType(FluencyApp));
      final container = ProviderScope.containerOf(context);

      // 预设卡片数据
      final notifier = container.read(flashcardNotifierProvider.notifier)
          as TestFlashcardNotifier;
      notifier.setState(FlashcardState(
        words: _createWordItems(3),
        currentIndex: 0,
      ));

      // 导航到 Flashcard 页面
      container.read(appRouterProvider).push(AppRoutes.flashcard);
      await tester.pumpAndSettle();

      // 验证页面已显示
      expect(find.byType(FlashcardScreen), findsOneWidget);
      // 验证进度文本
      expect(find.text('1/3'), findsOneWidget);
      // 验证当前单词
      expect(find.text('word1'), findsOneWidget);
    });

    // ========== 翻转交互 ==========

    testWidgets('点击卡片翻转到背面', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(FluencyApp));
      final container = ProviderScope.containerOf(context);

      final notifier = container.read(flashcardNotifierProvider.notifier)
          as TestFlashcardNotifier;
      notifier.setState(FlashcardState(
        words: _createWordItems(2),
        currentIndex: 0,
      ));

      container.read(appRouterProvider).push(AppRoutes.flashcard);
      await tester.pumpAndSettle();

      // 初始状态：正面
      final state1 = container.read(flashcardNotifierProvider);
      expect(state1.isShowingBack, false);

      // 点击卡片翻转
      await tester.tap(find.text('word1'));
      await tester.pumpAndSettle();

      // 验证翻到背面
      final state2 = container.read(flashcardNotifierProvider);
      expect(state2.isShowingBack, true);
    });

    // ========== 前后切换 ==========

    testWidgets('点击下一张切换到第二张卡片', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(FluencyApp));
      final container = ProviderScope.containerOf(context);

      final notifier = container.read(flashcardNotifierProvider.notifier)
          as TestFlashcardNotifier;
      notifier.setState(FlashcardState(
        words: _createWordItems(3),
        currentIndex: 0,
      ));

      container.read(appRouterProvider).push(AppRoutes.flashcard);
      await tester.pumpAndSettle();

      expect(find.text('1/3'), findsOneWidget);

      // 点击下一张按钮
      await tester.tap(find.byIcon(Icons.arrow_forward_ios));
      await tester.pumpAndSettle();

      // 验证进度更新
      expect(find.text('2/3'), findsOneWidget);
      expect(find.text('word2'), findsOneWidget);
    });

    testWidgets('上一张按钮在第一张时禁用', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(FluencyApp));
      final container = ProviderScope.containerOf(context);

      final notifier = container.read(flashcardNotifierProvider.notifier)
          as TestFlashcardNotifier;
      notifier.setState(FlashcardState(
        words: _createWordItems(3),
        currentIndex: 0,
      ));

      container.read(appRouterProvider).push(AppRoutes.flashcard);
      await tester.pumpAndSettle();

      // 第一张时，上一张按钮应该禁用（onPressed 为 null）
      final prevButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.arrow_back_ios_new),
      );
      expect(prevButton.onPressed, isNull);
    });

    testWidgets('先前进再后退回到第一张', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(FluencyApp));
      final container = ProviderScope.containerOf(context);

      final notifier = container.read(flashcardNotifierProvider.notifier)
          as TestFlashcardNotifier;
      notifier.setState(FlashcardState(
        words: _createWordItems(3),
        currentIndex: 0,
      ));

      container.read(appRouterProvider).push(AppRoutes.flashcard);
      await tester.pumpAndSettle();

      // 前进到第二张
      await tester.tap(find.byIcon(Icons.arrow_forward_ios));
      await tester.pumpAndSettle();
      expect(find.text('2/3'), findsOneWidget);

      // 后退到第一张
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
      await tester.pumpAndSettle();
      expect(find.text('1/3'), findsOneWidget);
      expect(find.text('word1'), findsOneWidget);
    });

    // ========== 完成流程 ==========

    testWidgets('最后一张点击下一张 → 显示完成视图', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(FluencyApp));
      final container = ProviderScope.containerOf(context);

      final notifier = container.read(flashcardNotifierProvider.notifier)
          as TestFlashcardNotifier;
      notifier.setState(FlashcardState(
        words: _createWordItems(2),
        currentIndex: 1, // 已在最后一张
      ));

      container.read(appRouterProvider).push(AppRoutes.flashcard);
      await tester.pumpAndSettle();

      expect(find.text('2/2'), findsOneWidget);

      // 点击下一张触发完成
      await tester.tap(find.byIcon(Icons.arrow_forward_ios));
      await tester.pumpAndSettle();

      // 验证完成视图
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      expect(find.byType(OutlinedButton), findsOneWidget); // 再来一遍
      expect(find.byType(FilledButton), findsOneWidget); // 完成
    });

    testWidgets('完成视图点击「再来一遍」重置卡片', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(FluencyApp));
      final container = ProviderScope.containerOf(context);

      final items = _createWordItems(2);
      final notifier = container.read(flashcardNotifierProvider.notifier)
          as TestFlashcardNotifier;
      notifier.setState(FlashcardState(
        words: items,
        isCompleted: true,
      ));

      container.read(appRouterProvider).push(AppRoutes.flashcard);
      await tester.pumpAndSettle();

      // 验证完成视图已显示
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);

      // 点击「再来一遍」
      await tester.tap(find.byType(OutlinedButton));
      await tester.pumpAndSettle();

      // 验证重置后回到第一张
      final state = container.read(flashcardNotifierProvider);
      expect(state.isCompleted, false);
      expect(state.currentIndex, 0);
    });

    // ========== 暂停/恢复 ==========

    testWidgets('倒计时模式下暂停和恢复', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(FluencyApp));
      final container = ProviderScope.containerOf(context);

      final notifier = container.read(flashcardNotifierProvider.notifier)
          as TestFlashcardNotifier;
      notifier.setState(FlashcardState(
        words: _createWordItems(2),
        currentIndex: 0,
        settings: const FlashcardSettings(
          timerMode: FlashcardTimerMode.fixed,
          fixedTimerSeconds: 8,
        ),
        countdownRemaining: 5,
        countdownTotal: 8,
      ));

      container.read(appRouterProvider).push(AppRoutes.flashcard);
      await tester.pumpAndSettle();

      // 应显示暂停按钮（pause_rounded 图标）
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

      // 点击暂停
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pumpAndSettle();

      // 暂停后显示播放按钮
      final state = container.read(flashcardNotifierProvider);
      expect(state.isPaused, true);
    });

    // ========== 退出清理 ==========

    testWidgets('点击返回按钮退出 Flashcard 页面', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(FluencyApp));
      final container = ProviderScope.containerOf(context);

      final notifier = container.read(flashcardNotifierProvider.notifier)
          as TestFlashcardNotifier;
      notifier.setState(FlashcardState(
        words: _createWordItems(2),
        currentIndex: 0,
      ));

      container.read(appRouterProvider).push(AppRoutes.flashcard);
      await tester.pumpAndSettle();

      // 验证在 Flashcard 页
      expect(find.byType(FlashcardScreen), findsOneWidget);

      // 点击返回按钮
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // 验证已退出
      expect(find.byType(FlashcardScreen), findsNothing);
    });

    // ========== 取消收藏（统计移除数） ==========

    testWidgets('完成视图显示移除数', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(FluencyApp));
      final container = ProviderScope.containerOf(context);

      final notifier = container.read(flashcardNotifierProvider.notifier)
          as TestFlashcardNotifier;
      notifier.setState(FlashcardState(
        words: _createWordItems(3),
        isCompleted: true,
        removedCount: 2,
      ));

      container.read(appRouterProvider).push(AppRoutes.flashcard);
      await tester.pumpAndSettle();

      // 完成视图应显示移除数信息
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      // 验证移除统计文本存在（具体格式由 l10n 决定）
      expect(find.textContaining('2'), findsWidgets);
    });
  });
}
