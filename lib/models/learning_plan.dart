/// 全局学习计划值对象
///
/// 单一事实来源：每个大阶段当前实际计划做哪些子步骤。
/// 当前为静态结构（全量 `stage.allSubStages`）——「跳过复述」等行为通过
/// `LearningProgress.skippedSubStageKeys` 在进度侧承载，plan 不再受全局设置影响。
///
/// 未来扩展（用户自定义学习计划）：扩 [LearningPlan] 构造工厂为非静态形式，
/// consumer 仍只读 API（`subStagesFor` / `includes` / `indexOf`），零改动。
library;

import '../database/enums.dart';

/// 不可变学习计划。
class LearningPlan {
  final Map<LearningStage, List<SubStageType>> _stages;

  const LearningPlan(this._stages);

  /// 标准计划。
  ///
  /// [review0PlanVersion]：1 = 旧版「难句补练 + 段落复述」，
  /// 2 = 新版「难句补练 + 全文盲听」。默认 2。
  ///
  /// 其它阶段直接读 `stage.allSubStages`；只有 review0 因变体需要显式派生。
  /// `LearningStage.review0.allSubStages` 是 v1 ∪ v2 的展示并集，
  /// 不能直接当 plan，必须经过此处按版本筛选。
  factory LearningPlan.standard({int review0PlanVersion = 2}) {
    final review0Subs = review0PlanVersion == 1
        ? const [
            SubStageType.reviewDifficultPractice,
            SubStageType.reviewRetellParagraph,
          ]
        : const [
            SubStageType.reviewDifficultPractice,
            SubStageType.blindListen,
          ];
    return LearningPlan({
      for (final stage in LearningStage.values)
        stage: stage == LearningStage.review0
            ? List<SubStageType>.unmodifiable(review0Subs)
            : List<SubStageType>.unmodifiable(stage.allSubStages),
    });
  }

  /// 指定大阶段的计划子步骤列表（有序）。
  ///
  /// 该阶段无任何 planned 子步骤时返回空列表（如 [LearningStage.completed]）。
  List<SubStageType> subStagesFor(LearningStage stage) =>
      _stages[stage] ?? const [];

  /// 判断 [sub] 是否在 [stage] 的计划列表内。
  bool includes(LearningStage stage, SubStageType sub) =>
      subStagesFor(stage).contains(sub);

  /// 返回 [sub] 在 [stage] 计划列表中的索引；不在列表返回 -1。
  int indexOf(LearningStage stage, SubStageType sub) =>
      subStagesFor(stage).indexOf(sub);

  /// 全部 planned 子步骤计数（跨所有阶段，用作进度比例分母）。
  int get totalPlannedCount =>
      _stages.values.fold(0, (s, l) => s + l.length);

  /// 找当前阶段 plan 内 [currentSubStage] 之后的下一个 planned 子步骤。
  ///
  /// - 当前阶段 plan 内有后续 → 返回 `(stage, nextSubStage)`
  /// - 当前是 plan 末尾、不在 plan、或阶段 plan 空 → 返回 `null`
  ///
  /// 跨阶段不引导：完成本大阶段是自然终点，调用方按 `null` 表示"无后续"
  /// 来决定 UI（例如完成弹窗只显示「完成」按钮）。
  ({LearningStage stage, SubStageType subStage})? nextPlannedAfter(
    LearningStage currentStage,
    SubStageType currentSubStage,
  ) {
    final planned = subStagesFor(currentStage);
    final idx = planned.indexOf(currentSubStage);
    if (idx < 0) return null;
    if (idx + 1 >= planned.length) return null;
    return (stage: currentStage, subStage: planned[idx + 1]);
  }
}
