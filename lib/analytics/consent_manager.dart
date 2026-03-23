/// 用户数据采集同意管理
///
/// 使用 [SharedPreferences] 持久化同意状态。
/// 本期默认同意（不弹窗），上线前补隐私政策弹窗。
library;

import 'package:shared_preferences/shared_preferences.dart';

/// 管理用户是否同意数据采集
///
/// [AnalyticsService] 在每次 track/setUserId/setUserProperty 前检查此状态。
/// 用户拒绝后 App 完全可用（纯本地模式），[StudyTimeService] 不受影响。
class ConsentManager {
  final SharedPreferences _prefs;

  static const _consentKey = 'analytics_consent';

  ConsentManager(this._prefs);

  /// 用户是否已同意数据采集
  ///
  /// 本期默认 true（不弹窗），上线前改为默认 false + 弹窗。
  bool get hasConsented => _prefs.getBool(_consentKey) ?? true;

  /// 记录用户同意
  Future<void> grantConsent() async {
    await _prefs.setBool(_consentKey, true);
  }

  /// 撤回同意（设置页"关闭数据采集"开关）
  Future<void> revokeConsent() async {
    await _prefs.setBool(_consentKey, false);
  }
}
