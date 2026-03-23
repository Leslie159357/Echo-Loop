/// 复习提醒时间计算器
///
/// 当前默认策略：固定每天指定时间。
abstract class ReviewReminderTimeCalculator {
  DateTime nextTriggerAt(DateTime now);
}

/// 固定时间提醒策略
class FixedTimeReminderCalculator implements ReviewReminderTimeCalculator {
  final int hour;
  final int minute;

  const FixedTimeReminderCalculator({this.hour = 20, this.minute = 0});

  @override
  DateTime nextTriggerAt(DateTime now) {
    final today = DateTime(now.year, now.month, now.day, hour, minute);
    if (now.isBefore(today)) return today;
    return today.add(const Duration(days: 1));
  }
}

/// 预留：后续可按用户使用习惯动态推断最佳提醒时间
///
/// 当前版本不实现自适应，默认退回固定 20:00。
class AdaptiveReminderTimeCalculator implements ReviewReminderTimeCalculator {
  const AdaptiveReminderTimeCalculator({
    this.fallback = const FixedTimeReminderCalculator(),
  });

  final ReviewReminderTimeCalculator fallback;

  @override
  DateTime nextTriggerAt(DateTime now) {
    return fallback.nextTriggerAt(now);
  }
}
