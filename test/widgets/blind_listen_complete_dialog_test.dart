import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluency/database/enums.dart';
import 'package:fluency/widgets/blind_listen_complete_dialog.dart';

import '../helpers/test_app.dart';

void main() {
  group('BlindListenCompleteDialog', () {
    /// 非末步骤（有下一步可继续）
    testWidgets('非末步骤 — 显示步骤进度、难度选择、双按钮', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showBlindListenCompleteDialog(
                  context: context,
                  passCount: 2,
                  stepIndex: 0,
                  totalSteps: 4,
                  stageName: 'First Study',
                  nextStepName: 'Intensive Listening',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // 验证标题和步骤进度
      expect(find.text('Listening Complete'), findsOneWidget);
      expect(find.text('Step 1/4 (First Study)'), findsOneWidget);
      expect(find.text('Listened 2 time(s)'), findsOneWidget);
      expect(find.text('How did it feel?'), findsOneWidget);

      // 验证 5 个难度选项
      expect(find.text('Very Easy'), findsOneWidget);
      expect(find.text('Easy'), findsOneWidget);
      expect(find.text('Okay'), findsOneWidget);
      expect(find.text('Hard'), findsOneWidget);
      expect(find.text('Very Hard'), findsOneWidget);

      // 验证三个按钮
      expect(find.text('Listen Again'), findsOneWidget);
      expect(find.text('Back to Plan'), findsOneWidget);
      expect(find.text('Continue: Intensive Listening'), findsOneWidget);
    });

    testWidgets('非末步骤 — 未选择难度时按钮置灰', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showBlindListenCompleteDialog(
                  context: context,
                  passCount: 1,
                  stepIndex: 0,
                  totalSteps: 4,
                  stageName: 'First Study',
                  nextStepName: 'Intensive Listening',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // "继续"和"返回计划"按钮都应置灰
      final continueButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Continue: Intensive Listening'),
      );
      expect(continueButton.onPressed, isNull);

      final backButton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Back to Plan'),
      );
      expect(backButton.onPressed, isNull);
    });

    testWidgets('非末步骤 — 选择难度后点击"继续"返回 continueToNext=true',
        (tester) async {
      BlindListenResult? result;

      await tester.pumpWidget(
        createTestApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showBlindListenCompleteDialog(
                  context: context,
                  passCount: 2,
                  stepIndex: 0,
                  totalSteps: 4,
                  stageName: 'First Study',
                  nextStepName: 'Intensive Listening',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // 选择难度
      await tester.tap(find.text('Hard'));
      await tester.pumpAndSettle();

      // 点击"继续"
      await tester.tap(find.text('Continue: Intensive Listening'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.difficulty, DifficultyLevel.hard);
      expect(result!.continueToNext, isTrue);
    });

    testWidgets('非末步骤 — 选择难度后点击"返回计划"返回 continueToNext=false',
        (tester) async {
      BlindListenResult? result;

      await tester.pumpWidget(
        createTestApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showBlindListenCompleteDialog(
                  context: context,
                  passCount: 2,
                  stepIndex: 0,
                  totalSteps: 4,
                  stageName: 'First Study',
                  nextStepName: 'Intensive Listening',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // 选择难度
      await tester.tap(find.text('Easy'));
      await tester.pumpAndSettle();

      // 点击"返回计划"
      await tester.tap(find.text('Back to Plan'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.difficulty, DifficultyLevel.easy);
      expect(result!.continueToNext, isFalse);
    });

    testWidgets('"再听一遍"按钮返回 null', (tester) async {
      BlindListenResult? result =
          (difficulty: DifficultyLevel.medium, continueToNext: false);

      await tester.pumpWidget(
        createTestApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showBlindListenCompleteDialog(
                  context: context,
                  passCount: 1,
                  stepIndex: 0,
                  totalSteps: 4,
                  stageName: 'First Study',
                  nextStepName: 'Intensive Listening',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // 点击"再听一遍"（TextButton）
      await tester.tap(find.text('Listen Again'));
      await tester.pumpAndSettle();

      expect(result, isNull);
    });

    /// 末步骤（没有下一步）
    testWidgets('末步骤 — 显示"完成首次学习"按钮', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showBlindListenCompleteDialog(
                  context: context,
                  passCount: 2,
                  stepIndex: 3,
                  totalSteps: 4,
                  stageName: 'First Study',
                  isLastStep: true,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // 验证步骤进度
      expect(find.text('Step 4/4 (First Study)'), findsOneWidget);

      // 末步骤显示"完成首次学习"按钮（FilledButton）和"再听一遍"（OutlinedButton）
      expect(find.text('Complete First Study'), findsOneWidget);
      expect(find.text('Listen Again'), findsOneWidget);

      // 不应显示"返回计划"和"继续"
      expect(find.text('Back to Plan'), findsNothing);
    });

    testWidgets('末步骤 — 选择难度后点击"完成首次学习"返回 continueToNext=false',
        (tester) async {
      BlindListenResult? result;

      await tester.pumpWidget(
        createTestApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showBlindListenCompleteDialog(
                  context: context,
                  passCount: 2,
                  stepIndex: 3,
                  totalSteps: 4,
                  stageName: 'First Study',
                  isLastStep: true,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Okay'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Complete First Study'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.difficulty, DifficultyLevel.medium);
      expect(result!.continueToNext, isFalse);
    });

    /// 复习模式（隐藏难度选择器）
    testWidgets('showDifficultySelector=false — 隐藏难度选择器，按钮直接可用',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showBlindListenCompleteDialog(
                  context: context,
                  passCount: 1,
                  stepIndex: 0,
                  totalSteps: 3,
                  stageName: 'Review Round 1',
                  nextStepName: 'Difficult Sentence Practice',
                  showDifficultySelector: false,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // 难度选择器不可见
      expect(find.text('How did it feel?'), findsNothing);
      expect(find.text('Very Easy'), findsNothing);
      expect(find.text('Hard'), findsNothing);

      // 按钮直接可用（不需要选择难度）
      final continueButton = tester.widget<FilledButton>(
        find.widgetWithText(
          FilledButton,
          'Continue: Difficult Sentence Practice',
        ),
      );
      expect(continueButton.onPressed, isNotNull);

      final backButton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Back to Plan'),
      );
      expect(backButton.onPressed, isNotNull);
    });

    testWidgets('showDifficultySelector=false — 点击继续返回默认难度 medium',
        (tester) async {
      BlindListenResult? result;

      await tester.pumpWidget(
        createTestApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showBlindListenCompleteDialog(
                  context: context,
                  passCount: 1,
                  stepIndex: 0,
                  totalSteps: 3,
                  stageName: 'Review Round 1',
                  nextStepName: 'Difficult Sentence Practice',
                  showDifficultySelector: false,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // 直接点击"继续"
      await tester.tap(
        find.text('Continue: Difficult Sentence Practice'),
      );
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.difficulty, DifficultyLevel.medium);
      expect(result!.continueToNext, isTrue);
    });

    testWidgets('显示正确遍数', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showBlindListenCompleteDialog(
                  context: context,
                  passCount: 3,
                  stepIndex: 0,
                  totalSteps: 4,
                  stageName: 'First Study',
                  nextStepName: 'Intensive Listening',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Listened 3 time(s)'), findsOneWidget);
    });
  });
}
