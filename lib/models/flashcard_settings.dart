/// Flashcard 设置模型
///
/// 控制卡片排序方式、控制模式和倒计时模式，通过 SharedPreferences 持久化。
library;

import 'intensive_listen_settings.dart' show ShadowingControlMode;

/// 倒计时模式
enum FlashcardTimerMode {
  /// 智能倒计时（根据单词长度 × 练习次数动态调整）
  smart,

  /// 固定时间
  fixed,
}

/// 卡片排序方式
enum FlashcardSortMode {
  /// 字母 A → Z
  alphabeticalAsc,

  /// 字母 Z → A
  alphabeticalDesc,

  /// 最早收藏优先
  timeAsc,

  /// 最近收藏优先
  timeDesc,

  /// 随机排序
  random,

  /// 智能排序（练习少、没翻过背面、很久没练的优先）
  smart,
}

/// Flashcard 设置
class FlashcardSettings {
  /// 控制模式（自动/手动，默认 auto）
  final ShadowingControlMode controlMode;

  /// 倒计时模式（默认 smart）
  final FlashcardTimerMode timerMode;

  /// 正面固定倒计时秒数（默认 5）
  final int fixedTimerSeconds;

  /// 背面固定倒计时秒数（默认 10）
  final int fixedTimerBackSeconds;

  /// 排序方式（默认 random）
  final FlashcardSortMode sortMode;

  /// 翻转到背面时自动播放来源例句（默认 true）
  final bool autoPlaySentence;

  /// 进入卡片 / 翻转时自动 TTS 朗读单词（默认 true）
  final bool autoPlayWord;

  /// 是否手动模式
  bool get isManualMode => controlMode == ShadowingControlMode.manual;

  /// 固定倒计时可选值
  static const List<int> fixedTimerOptions = [3, 5, 8, 10, 15, 20, 30];

  const FlashcardSettings({
    this.controlMode = ShadowingControlMode.auto,
    this.timerMode = FlashcardTimerMode.smart,
    this.fixedTimerSeconds = 5,
    this.fixedTimerBackSeconds = 10,
    this.sortMode = FlashcardSortMode.random,
    this.autoPlaySentence = true,
    this.autoPlayWord = true,
  });

  FlashcardSettings copyWith({
    ShadowingControlMode? controlMode,
    FlashcardTimerMode? timerMode,
    int? fixedTimerSeconds,
    int? fixedTimerBackSeconds,
    FlashcardSortMode? sortMode,
    bool? autoPlaySentence,
    bool? autoPlayWord,
  }) {
    return FlashcardSettings(
      controlMode: controlMode ?? this.controlMode,
      timerMode: timerMode ?? this.timerMode,
      fixedTimerSeconds: fixedTimerSeconds ?? this.fixedTimerSeconds,
      fixedTimerBackSeconds:
          fixedTimerBackSeconds ?? this.fixedTimerBackSeconds,
      sortMode: sortMode ?? this.sortMode,
      autoPlaySentence: autoPlaySentence ?? this.autoPlaySentence,
      autoPlayWord: autoPlayWord ?? this.autoPlayWord,
    );
  }

  Map<String, dynamic> toJson() => {
    'controlMode': controlMode.name,
    'timerMode': timerMode.name,
    'fixedTimerSeconds': fixedTimerSeconds,
    'fixedTimerBackSeconds': fixedTimerBackSeconds,
    'sortMode': sortMode.name,
    'autoPlaySentence': autoPlaySentence,
    'autoPlayWord': autoPlayWord,
  };

  /// 防御性解析：非法值回退默认
  ///
  /// 兼容旧数据：
  /// - timerMode 为 'off' → controlMode 迁移为 manual，timerMode 回退 smart
  /// - 无 controlMode 字段（旧版本） → timerMode 强制迁移为 smart（新默认值）
  factory FlashcardSettings.fromJson(Map<String, dynamic> json) {
    final rawTimerMode = json['timerMode'];
    final isLegacyOff = rawTimerMode == 'off';
    final isLegacyData = !json.containsKey('controlMode');

    return FlashcardSettings(
      controlMode: isLegacyOff
          ? ShadowingControlMode.manual
          : _parseControlMode(json['controlMode']),
      timerMode: isLegacyData
          ? FlashcardTimerMode.smart
          : _parseTimerMode(rawTimerMode),
      fixedTimerSeconds:
          _parseFixedTimerSeconds(json['fixedTimerSeconds'], fallback: 5),
      fixedTimerBackSeconds:
          _parseFixedTimerSeconds(json['fixedTimerBackSeconds'], fallback: 10),
      sortMode: _parseSortMode(json['sortMode']),
      autoPlaySentence: json['autoPlaySentence'] is bool
          ? json['autoPlaySentence'] as bool
          : true,
      autoPlayWord: json['autoPlayWord'] is bool
          ? json['autoPlayWord'] as bool
          : true,
    );
  }

  /// 计算智能倒计时秒数
  ///
  /// 双因子：单词长度 × 练习次数
  /// - 短词(≤4字符): maxTime=4s, minTime=2s
  /// - 长词(≥12字符): maxTime=8s, minTime=5s
  /// - 中间长度: 线性插值
  /// - practiceCount=0: 使用 maxTime
  /// - practiceCount≥5: 使用 minTime
  static int calculateSmartSeconds({
    required int wordLength,
    required int practiceCount,
  }) {
    // 根据单词长度确定 base 范围
    final ratio = ((wordLength - 4) / (12 - 4)).clamp(0.0, 1.0);
    final maxTime = 4.0 + ratio * 4.0; // 4→8
    final minTime = 2.0 + ratio * 3.0; // 2→5

    // 根据练习次数从 maxTime 衰减到 minTime
    final decay = (practiceCount / 5.0).clamp(0.0, 1.0);
    return (maxTime - decay * (maxTime - minTime)).round();
  }

  /// 计算智能排序分数（分数越高越靠前）
  ///
  /// score = -10*practiceCount + (viewedBack ? -5 : 0) + minutesSinceLastPractice/60
  static double calculateSmartScore({
    required int practiceCount,
    required bool viewedBack,
    required DateTime? lastPracticedAt,
  }) {
    final now = DateTime.now();
    final minutesSinceLastPractice = lastPracticedAt != null
        ? now.difference(lastPracticedAt).inMinutes.toDouble()
        : 10080.0; // 7 天（首次未练习给予高优先级）
    return -10.0 * practiceCount +
        (viewedBack ? -5.0 : 0.0) +
        minutesSinceLastPractice / 60.0;
  }

  /// 解析控制模式：非法值回退 auto
  static ShadowingControlMode _parseControlMode(dynamic raw) {
    if (raw is! String) return ShadowingControlMode.auto;
    return ShadowingControlMode.values
            .where((e) => e.name == raw)
            .firstOrNull ??
        ShadowingControlMode.auto;
  }

  /// 解析倒计时模式：非法值回退 smart
  ///
  /// 旧数据 'off' 也回退为 smart（controlMode 负责手动逻辑）。
  static FlashcardTimerMode _parseTimerMode(dynamic raw) {
    if (raw is! String) return FlashcardTimerMode.smart;
    return FlashcardTimerMode.values.where((e) => e.name == raw).firstOrNull ??
        FlashcardTimerMode.smart;
  }

  /// 解析固定秒数：必须在可选值列表中，否则回退 [fallback]
  static int _parseFixedTimerSeconds(dynamic raw, {int fallback = 5}) {
    if (raw is! int) return fallback;
    if (!fixedTimerOptions.contains(raw)) return fallback;
    return raw;
  }

  /// 解析排序模式：非法值回退 random
  static FlashcardSortMode _parseSortMode(dynamic raw) {
    if (raw is! String) return FlashcardSortMode.random;
    return FlashcardSortMode.values.where((e) => e.name == raw).firstOrNull ??
        FlashcardSortMode.random;
  }
}
