/// 提醒设置模型
///
/// 控制收藏复习提醒和音频复习提醒的开关与时间，
/// 通过 SharedPreferences 持久化。
library;

/// 提醒设置
class ReminderSettings {
  /// 收藏复习提醒开关（默认开启）
  final bool savedReviewReminderEnabled;

  /// 收藏复习提醒时间 — 小时（0-23，默认 20）
  final int savedReviewReminderHour;

  /// 收藏复习提醒时间 — 分钟（0-59，默认 0）
  final int savedReviewReminderMinute;

  /// 音频复习提醒开关（默认开启）
  final bool perAudioReminderEnabled;

  const ReminderSettings({
    this.savedReviewReminderEnabled = true,
    this.savedReviewReminderHour = 20,
    this.savedReviewReminderMinute = 0,
    this.perAudioReminderEnabled = true,
  });

  /// 格式化的提醒时间字符串，如 "20:00"
  String get formattedTime =>
      '${savedReviewReminderHour.toString().padLeft(2, '0')}:'
      '${savedReviewReminderMinute.toString().padLeft(2, '0')}';

  ReminderSettings copyWith({
    bool? savedReviewReminderEnabled,
    int? savedReviewReminderHour,
    int? savedReviewReminderMinute,
    bool? perAudioReminderEnabled,
  }) {
    return ReminderSettings(
      savedReviewReminderEnabled:
          savedReviewReminderEnabled ?? this.savedReviewReminderEnabled,
      savedReviewReminderHour:
          savedReviewReminderHour ?? this.savedReviewReminderHour,
      savedReviewReminderMinute:
          savedReviewReminderMinute ?? this.savedReviewReminderMinute,
      perAudioReminderEnabled:
          perAudioReminderEnabled ?? this.perAudioReminderEnabled,
    );
  }

  /// JSON key 保持 `dailyReminder*` 前缀以兼容老版本数据
  Map<String, dynamic> toJson() => {
    'dailyReminderEnabled': savedReviewReminderEnabled,
    'dailyReminderHour': savedReviewReminderHour,
    'dailyReminderMinute': savedReviewReminderMinute,
    'perAudioReminderEnabled': perAudioReminderEnabled,
  };

  /// 防御性解析：非法值回退默认
  ///
  /// SP 无 key 或字段缺失时，返回与硬编码行为一致的默认值，
  /// 保证老用户升级后零感知变化。
  /// JSON key 为 `dailyReminder*`（历史兼容）。
  factory ReminderSettings.fromJson(Map<String, dynamic> json) {
    return ReminderSettings(
      savedReviewReminderEnabled: json['dailyReminderEnabled'] is bool
          ? json['dailyReminderEnabled'] as bool
          : true,
      savedReviewReminderHour: _parseHour(json['dailyReminderHour']),
      savedReviewReminderMinute: _parseMinute(json['dailyReminderMinute']),
      perAudioReminderEnabled: json['perAudioReminderEnabled'] is bool
          ? json['perAudioReminderEnabled'] as bool
          : true,
    );
  }

  /// 解析小时：必须在 0-23 范围内，否则回退 20
  static int _parseHour(dynamic raw) {
    if (raw is! int) return 20;
    if (raw < 0 || raw > 23) return 20;
    return raw;
  }

  /// 解析分钟：必须在 0-59 范围内，否则回退 0
  static int _parseMinute(dynamic raw) {
    if (raw is! int) return 0;
    if (raw < 0 || raw > 59) return 0;
    return raw;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReminderSettings &&
          runtimeType == other.runtimeType &&
          savedReviewReminderEnabled == other.savedReviewReminderEnabled &&
          savedReviewReminderHour == other.savedReviewReminderHour &&
          savedReviewReminderMinute == other.savedReviewReminderMinute &&
          perAudioReminderEnabled == other.perAudioReminderEnabled;

  @override
  int get hashCode => Object.hash(
    savedReviewReminderEnabled,
    savedReviewReminderHour,
    savedReviewReminderMinute,
    perAudioReminderEnabled,
  );
}
