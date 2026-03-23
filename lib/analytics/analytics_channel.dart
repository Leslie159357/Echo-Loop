/// 上报通道抽象接口（Strategy Pattern）
///
/// 业务代码不直接依赖 Firebase/友盟，只通过此接口上报事件。
/// 具体实现见 [FirebaseChannel]、[UmengChannel]、[LogOnlyChannel]。
library;

/// 分析上报通道
///
/// 每个实现类封装一个第三方 SDK（Firebase Analytics、友盟等）。
/// [AnalyticsService] 持有一个 Channel 实例，将事件转发到此接口。
abstract class AnalyticsChannel {
  /// 通道名称（用于日志和调试）
  String get name;

  /// 初始化通道（如 SDK 初始化）
  Future<void> initialize();

  /// 记录事件
  ///
  /// [name] 事件名（使用 [Events] 常量）。
  /// [parameters] 事件属性，值只允许 String/int/double/bool。
  Future<void> logEvent(String name, Map<String, Object>? parameters);

  /// 设置用户 ID（匿名 ID 或登录后的真实 ID）
  Future<void> setUserId(String? id);

  /// 设置用户属性
  Future<void> setUserProperty(String name, String? value);
}
