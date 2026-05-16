/// 学习计划 Provider
///
/// 默认 plan（[learningPlanProvider]）走 v2（review0 = 难句补练 + 全文盲听），
/// 仅用于没有具体音频上下文的全局求和、设置页统计等场景。
///
/// 渲染或推进某条音频时必须用 [learningPlanForAudioProvider]：根据该音频的
/// `progress.review0PlanVersion` 派生 v1（旧版）或 v2（新版）plan，
/// 保证 review0 已完成的历史音频继续按旧 plan 渲染、新音频走新 plan。
///
/// 「不做某类子阶段」语义由 `LearningProgress.skippedSubStageKeys` 在进度侧承载，
/// 与未来「用户自定义学习计划」正交。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/learning_plan.dart';
import 'learning_progress_provider.dart';

/// 全局默认 plan（v2）。不绑定具体音频。
final learningPlanProvider = Provider<LearningPlan>((ref) {
  return LearningPlan.standard();
});

/// 按音频派生 plan。
///
/// 读取该音频 `progress.review0PlanVersion`：1 → v1 plan（review0 = 旧版），
/// 2 或缺省 → v2 plan（review0 = 新版）。
///
/// progress 不存在（音频从未开始学习）时返回 v2 plan，与新建 progress 默认一致。
final learningPlanForAudioProvider =
    Provider.family<LearningPlan, String>((ref, audioItemId) {
  final progressState = ref.watch(learningProgressNotifierProvider);
  final progress = progressState.progressMap[audioItemId];
  final version = progress?.review0PlanVersion ?? 2;
  return LearningPlan.standard(review0PlanVersion: version);
});
