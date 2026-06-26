/// 学习子阶段「槽位」与入口弹窗停顿选择
///
/// 各听说子阶段的设置已迁移到按槽位 typed 偏好(见 `*_prefs.dart` / `slot_prefs.dart`),
/// 不再用稀疏覆盖表存储。本文件保留两类仍通用的纯定义:
/// - 槽位常量 [StageSettingsSlots] 与 [stageSlotKey](子阶段 × 复习轮次的 key)
/// - 入口弹窗停顿下拉的值类型 [BriefingPauseChoice]
library;

import '../database/enums.dart' show LearningStage;
import 'intensive_listen_settings.dart' show PauseMode;

/// 各听说子阶段的 slot 前缀常量。
///
/// 完整 slot key = `子阶段:轮次`(见 [stageSlotKey])。
abstract final class StageSettingsSlots {
  static const blindListen = 'blindListen';
  static const intensiveListen = 'intensiveListen';
  static const listenAndRepeat = 'listenAndRepeat';
  static const retell = 'retell';
  static const reviewDifficultPractice = 'reviewDifficultPractice';
  static const bookmarkReview = 'bookmarkReview';
}

/// 构造完整 slot key:`子阶段:轮次`。
///
/// [subStage] 取 [StageSettingsSlots] 常量;[stage] 为当前复习轮次,
/// 不绑学习流程(如收藏句复习)传 `null` → 轮次后缀为 `none`。
String stageSlotKey(String subStage, LearningStage? stage) =>
    '$subStage:${stage?.name ?? 'none'}';

/// 入口弹窗「句间停顿」的一次选择,覆盖三种模式(自动 / 固定间隔 / 句长倍数),
/// 与播放器内 🔧 面板一致。
///
/// 作为弹窗停顿下拉(`PauseChoiceDropdown`)的值类型;具备值相等以适配 DropdownButton。
class BriefingPauseChoice {
  final PauseMode mode;

  /// 固定间隔秒数(仅 [PauseMode.fixed] 有效)。
  final int fixedSeconds;

  /// 句长倍数(仅 [PauseMode.multiplier] 有效)。
  final double multiplier;

  const BriefingPauseChoice.smart()
    : mode = PauseMode.smart,
      fixedSeconds = 0,
      multiplier = 0.0;

  const BriefingPauseChoice.fixed(this.fixedSeconds)
    : mode = PauseMode.fixed,
      multiplier = 0.0;

  const BriefingPauseChoice.multiplier(this.multiplier)
    : mode = PauseMode.multiplier,
      fixedSeconds = 0;

  /// 兼容用 pauseMultiplier:仅倍数模式给真实倍数,自动/固定给 `-1.0`(走 smart 估算)。
  /// 供 `paragraph_selection_sheet` 的时长预估等仍以倍数表达的旧接口使用。
  double get legacyPauseMultiplier =>
      mode == PauseMode.multiplier ? multiplier : -1.0;

  @override
  bool operator ==(Object other) =>
      other is BriefingPauseChoice &&
      mode == other.mode &&
      fixedSeconds == other.fixedSeconds &&
      multiplier == other.multiplier;

  @override
  int get hashCode => Object.hash(mode, fixedSeconds, multiplier);
}
