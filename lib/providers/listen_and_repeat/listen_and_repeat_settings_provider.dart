/// 跟读设置 Provider
///
/// 存储跟读会话**当前生效**的设置(state),作为播放/倒计时的工作副本;持久化真相源是
/// 按槽位的 [intensiveListenPrefsProvider](难句跟读槽位 `listenAndRepeat:firstLearn`)。
/// 入口 [initialize] 由 controller 用 prefs.resolve 出完整设置后注入;设置面板 [update]
/// 把改动写穿到偏好(只记手动改动、不冻结智能默认)。
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../models/intensive_listen_settings.dart';
import '../intensive_listen_prefs_provider.dart';

part 'listen_and_repeat_settings_provider.g.dart';

/// 跟读设置 Provider
@Riverpod(keepAlive: true)
class ListenAndRepeatSettings extends _$ListenAndRepeatSettings {
  /// 持久化槽位(子阶段×轮次);null 表示尚未初始化。
  String? _settingsSlot;

  @override
  IntensiveListenSettings build() => const IntensiveListenSettings();

  /// 用 controller 解析好的完整设置 + 槽位初始化。
  void initialize(IntensiveListenSettings settings, String settingsSlot) {
    _settingsSlot = settingsSlot;
    state = settings;
  }

  /// 更新设置(设置面板触发):把改动写穿到偏好后替换 state。
  void update(IntensiveListenSettings newSettings) {
    final slot = _settingsSlot;
    if (slot != null) {
      persistIntensiveSettingsDiff(
        ref.read(intensiveListenPrefsProvider.notifier),
        slot,
        state,
        newSettings,
      );
    }
    state = newSettings;
  }
}
