/// 全文盲听完成对话框
///
/// 基于通用 [StepCompleteDialog] 的薄封装，保留 [BlindListenResult]
/// 返回类型以兼容现有调用方。
library;

import 'package:flutter/material.dart';
import '../database/enums.dart';
import '../l10n/app_localizations.dart';
import 'dialogs/step_complete_dialog.dart';

/// 盲听完成对话框返回结果
///
/// [difficulty] 为用户选择的难度等级。
/// [continueToNext] 为 true 表示用户选择"继续下一步"，
/// false 表示"返回计划"或"完成阶段"。
typedef BlindListenResult = ({DifficultyLevel difficulty, bool continueToNext});

/// 显示盲听完成对话框
///
/// 返回 `null` 表示用户选择"再听一遍"，
/// 返回 [BlindListenResult] 表示用户选择难度后点击了操作按钮。
///
/// [passCount] 已完成的盲听遍数，显示为内容文本。
/// [stepIndex] 当前完成的步骤序号（0-based）。
/// [totalSteps] 当前阶段总步骤数。
/// [stageName] 当前阶段名称（如"首次学习"）。
/// [nextStepName] 下一步名称（null 表示下一步不可用或不存在）。
/// [isLastStep] 是否为当前阶段的最后一步。
/// [showDifficultySelector] 是否显示 5 档难度选择器（复习模式下隐藏）。
Future<BlindListenResult?> showBlindListenCompleteDialog({
  required BuildContext context,
  required int passCount,
  required int stepIndex,
  required int totalSteps,
  required String stageName,
  String? nextStepName,
  bool isLastStep = false,
  bool showDifficultySelector = true,
}) async {
  final l10n = AppLocalizations.of(context)!;

  final result = await showStepCompleteDialog(
    context: context,
    title: l10n.blindListenComplete,
    contentBody: Text(l10n.blindListenPassInfo(passCount)),
    stepIndex: stepIndex,
    totalSteps: totalSteps,
    stageName: stageName,
    nextStepName: nextStepName,
    isLastStep: isLastStep,
    showDifficultySelector: showDifficultySelector,
    replayLabel: l10n.listenAgain,
  );

  // 将 StepCompleteResult? 转换为 BlindListenResult? 以保持向后兼容
  if (result == null) return null;
  return (
    difficulty: result.difficulty ?? DifficultyLevel.medium,
    continueToNext: result.continueToNext,
  );
}
