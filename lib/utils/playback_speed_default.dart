/// 盲听 / 复述入口播放速度默认值
///
/// 同一份映射由 [BlindListenSettings] 和 [RetellSettings] 复用：
/// 困难 / 很困难 的音频起始减速，随复习轮次逐步恢复到 1.0x；
/// 中等及以下默认保持 1.0x。
///
/// 注意：首次学习的全文盲听虽然此时用户还没评级（[DifficultyLevel.medium]
/// 是默认值），但 medium 在本映射下天然返回 1.0x，因此无需额外特判。
library;

import '../database/enums.dart';

/// 难度 + 轮次 → 默认播放速度
///
/// | 难度     | FL   | R0   | R1   | R2   | R4   | R7   | R14  | R28  |
/// |---------|------|------|------|------|------|------|------|------|
/// | 中等及以下 | 1.00 | 1.00 | 1.00 | 1.00 | 1.00 | 1.00 | 1.00 | 1.00 |
/// | 困难     | 0.90 | 0.90 | 0.90 | 0.90 | 0.90 | 1.00 | 1.00 | 1.00 |
/// | 很困难   | 0.80 | 0.80 | 0.80 | 0.90 | 0.90 | 0.90 | 1.00 | 1.00 |
///
/// [LearningStage.completed] 视同 review28（已通关，全速）。
double defaultPlaybackSpeedFor(
  DifficultyLevel difficulty,
  LearningStage stage,
) {
  switch (difficulty) {
    case DifficultyLevel.veryEasy:
    case DifficultyLevel.easy:
    case DifficultyLevel.medium:
      return 1.0;
    case DifficultyLevel.hard:
      return switch (stage) {
        LearningStage.firstLearn ||
        LearningStage.review0 ||
        LearningStage.review1 ||
        LearningStage.review2 ||
        LearningStage.review4 => 0.9,
        LearningStage.review7 ||
        LearningStage.review14 ||
        LearningStage.review28 ||
        LearningStage.completed => 1.0,
      };
    case DifficultyLevel.veryHard:
      return switch (stage) {
        LearningStage.firstLearn ||
        LearningStage.review0 ||
        LearningStage.review1 => 0.8,
        LearningStage.review2 ||
        LearningStage.review4 ||
        LearningStage.review7 => 0.9,
        LearningStage.review14 ||
        LearningStage.review28 ||
        LearningStage.completed => 1.0,
      };
  }
}
