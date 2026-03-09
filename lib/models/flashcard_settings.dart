/// Flashcard 设置模型
///
/// 控制卡片排序方式和倒计时模式，通过 SharedPreferences 持久化。
library;

/// 倒计时模式
enum FlashcardTimerMode {
  /// 固定时间（默认 8 秒）
  fixed,

  /// 智能倒计时（根据单词长度 × 练习次数动态调整）
  smart,

  /// 关闭自动倒计时，完全手动控制
  off,
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
  /// 倒计时模式（默认 fixed）
  final FlashcardTimerMode timerMode;

  /// 固定倒计时秒数（默认 8）
  final int fixedTimerSeconds;

  /// 排序方式（默认 random）
  final FlashcardSortMode sortMode;

  /// 翻转到背面时自动播放来源例句（默认 true）
  final bool autoPlaySentence;

  /// 固定倒计时可选值
  static const List<int> fixedTimerOptions = [3, 5, 8, 10, 15, 20, 30];

  const FlashcardSettings({
    this.timerMode = FlashcardTimerMode.fixed,
    this.fixedTimerSeconds = 8,
    this.sortMode = FlashcardSortMode.random,
    this.autoPlaySentence = true,
  });

  FlashcardSettings copyWith({
    FlashcardTimerMode? timerMode,
    int? fixedTimerSeconds,
    FlashcardSortMode? sortMode,
    bool? autoPlaySentence,
  }) {
    return FlashcardSettings(
      timerMode: timerMode ?? this.timerMode,
      fixedTimerSeconds: fixedTimerSeconds ?? this.fixedTimerSeconds,
      sortMode: sortMode ?? this.sortMode,
      autoPlaySentence: autoPlaySentence ?? this.autoPlaySentence,
    );
  }

  Map<String, dynamic> toJson() => {
    'timerMode': timerMode.name,
    'fixedTimerSeconds': fixedTimerSeconds,
    'sortMode': sortMode.name,
    'autoPlaySentence': autoPlaySentence,
  };

  /// 防御性解析：非法值回退默认
  factory FlashcardSettings.fromJson(Map<String, dynamic> json) {
    return FlashcardSettings(
      timerMode: _parseTimerMode(json['timerMode']),
      fixedTimerSeconds: _parseFixedTimerSeconds(json['fixedTimerSeconds']),
      sortMode: _parseSortMode(json['sortMode']),
      autoPlaySentence: json['autoPlaySentence'] is bool
          ? json['autoPlaySentence'] as bool
          : true,
    );
  }

  /// 计算智能倒计时秒数
  ///
  /// 双因子：单词长度 × 练习次数
  /// - 短词(≤4字符): maxTime=5s, minTime=2s
  /// - 长词(≥12字符): maxTime=10s, minTime=5s
  /// - 中间长度: 线性插值
  /// - practiceCount=0: 使用 maxTime
  /// - practiceCount≥5: 使用 minTime
  static int calculateSmartSeconds({
    required int wordLength,
    required int practiceCount,
  }) {
    // 根据单词长度确定 base 范围
    final ratio = ((wordLength - 4) / (12 - 4)).clamp(0.0, 1.0);
    final maxTime = 5.0 + ratio * 5.0; // 5→10
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

  /// 解析倒计时模式：非法值回退 fixed
  static FlashcardTimerMode _parseTimerMode(dynamic raw) {
    if (raw is! String) return FlashcardTimerMode.fixed;
    return FlashcardTimerMode.values.where((e) => e.name == raw).firstOrNull ??
        FlashcardTimerMode.fixed;
  }

  /// 解析固定秒数：必须在可选值列表中，否则回退 8
  static int _parseFixedTimerSeconds(dynamic raw) {
    if (raw is! int) return 8;
    if (!fixedTimerOptions.contains(raw)) return 8;
    return raw;
  }

  /// 解析排序模式：非法值回退 random
  static FlashcardSortMode _parseSortMode(dynamic raw) {
    if (raw is! String) return FlashcardSortMode.random;
    return FlashcardSortMode.values.where((e) => e.name == raw).firstOrNull ??
        FlashcardSortMode.random;
  }
}
