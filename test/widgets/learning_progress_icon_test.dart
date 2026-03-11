// 环形学习进度图标测试
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluency/widgets/learning_progress_icon.dart';
import 'package:fluency/models/learning_progress.dart';
import 'package:fluency/database/enums.dart';

void main() {
  Widget createTestWidget(LearningProgress? progress) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: LearningProgressIcon(progress: progress),
        ),
      ),
    );
  }

  group('LearningProgressIcon', () {
    testWidgets('未学习 → 显示 audio icon + 灰色圆形背景', (tester) async {
      await tester.pumpWidget(createTestWidget(null));

      expect(find.byIcon(Icons.audiotrack), findsOneWidget);
      // Container with circle shape
      final container = tester.widget<Container>(
        find.byType(Container).first,
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.shape, BoxShape.circle);
      // 没有 CircularProgressIndicator
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('进行中 → 显示 CircularProgressIndicator + 进度值',
        (tester) async {
      final progress = LearningProgress(
        audioItemId: 'test-1',
        currentStage: LearningStage.firstLearn,
        currentSubStage: SubStageType.intensiveListen,
        updatedAt: DateTime(2026, 1, 1),
      );

      await tester.pumpWidget(createTestWidget(progress));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(indicator.value, progress.progressPercent);
      // 应显示 audiotrack 图标
      expect(find.byIcon(Icons.audiotrack), findsOneWidget);
    });

    testWidgets('已完成 → 显示 check icon + 绿色', (tester) async {
      final progress = LearningProgress(
        audioItemId: 'test-1',
        currentStage: LearningStage.completed,
        currentSubStage: SubStageType.blindListen,
        updatedAt: DateTime(2026, 1, 1),
      );

      await tester.pumpWidget(createTestWidget(progress));

      expect(find.byIcon(Icons.check), findsOneWidget);
      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(indicator.value, 1.0);
      expect(indicator.color, LearningProgressIcon.completedColor);
    });
  });
}
