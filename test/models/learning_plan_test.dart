/// LearningPlan 值对象测试
///
/// plan 现在按 audio 的 review0PlanVersion 派生：v2（默认）的 review0 为
/// `[难句补练, 全文盲听]`，v1 的 review0 为 `[难句补练, 段落复述]`；
/// 其它阶段直接用 `stage.allSubStages`。「不做某类子阶段」的语义通过
/// `LearningProgress.skippedSubStageKeys` 承载，不再由 plan 过滤。
library;

import 'package:echo_loop/database/enums.dart';
import 'package:echo_loop/models/learning_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LearningPlan.standard (默认 v2)', () {
    final plan = LearningPlan.standard();

    test('非 review0 阶段直接走 stage.allSubStages', () {
      for (final stage in LearningStage.values) {
        if (stage == LearningStage.review0) continue;
        expect(
          plan.subStagesFor(stage),
          equals(stage.allSubStages),
          reason: 'stage=$stage',
        );
      }
    });

    test('review0 = 新版「难句补练 + 全文盲听」', () {
      expect(plan.subStagesFor(LearningStage.review0), [
        SubStageType.reviewDifficultPractice,
        SubStageType.blindListen,
      ]);
    });

    test('completed 阶段返回空列表（allSubStages 本身为空）', () {
      expect(plan.subStagesFor(LearningStage.completed), isEmpty);
    });
  });

  group('LearningPlan.standard(review0PlanVersion: 1)', () {
    final plan = LearningPlan.standard(review0PlanVersion: 1);

    test('review0 = 旧版「难句补练 + 段落复述」', () {
      expect(plan.subStagesFor(LearningStage.review0), [
        SubStageType.reviewDifficultPractice,
        SubStageType.reviewRetellParagraph,
      ]);
    });

    test('非 review0 阶段与 v2 一致', () {
      for (final stage in LearningStage.values) {
        if (stage == LearningStage.review0) continue;
        expect(
          plan.subStagesFor(stage),
          equals(LearningPlan.standard().subStagesFor(stage)),
          reason: 'stage=$stage',
        );
      }
    });
  });

  group('LearningPlan API', () {
    final plan = LearningPlan.standard();

    test('includes 判定 sub 是否在 plan 内（始终 true，除非该阶段无此 sub）', () {
      expect(
        plan.includes(LearningStage.firstLearn, SubStageType.blindListen),
        isTrue,
      );
      expect(
        plan.includes(LearningStage.firstLearn, SubStageType.retell),
        isTrue,
      );
    });

    test('indexOf 返回 plan 内位置', () {
      expect(
        plan.indexOf(LearningStage.firstLearn, SubStageType.listenAndRepeat),
        2,
      );
      expect(
        plan.indexOf(LearningStage.firstLearn, SubStageType.retell),
        3,
      );
    });

    test('totalPlannedCount 跨所有阶段求和', () {
      // v2: review0 = 2 项，其它阶段同 allSubStages
      final expected = LearningStage.values.fold<int>(0, (s, stage) {
        if (stage == LearningStage.review0) return s + 2;
        return s + stage.allSubStages.length;
      });
      expect(plan.totalPlannedCount, expected);
    });
  });

  group('LearningPlan.nextPlannedAfter', () {
    final plan = LearningPlan.standard();

    test('当前阶段 plan 中间项 → 返回下一项', () {
      // firstLearn = [blind, intensive, shadow, retell]
      final next = plan.nextPlannedAfter(
        LearningStage.firstLearn,
        SubStageType.intensiveListen,
      );
      expect(next, isNotNull);
      expect(next!.stage, LearningStage.firstLearn);
      expect(next.subStage, SubStageType.listenAndRepeat);
    });

    test('当前阶段 plan 末尾 → 返回 null（不跨阶段引导）', () {
      final next = plan.nextPlannedAfter(
        LearningStage.firstLearn,
        SubStageType.retell,
      );
      expect(next, isNull);
    });
  });
}
