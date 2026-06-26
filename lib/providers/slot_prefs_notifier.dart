/// 「按槽位」偏好 Notifier 基类
///
/// 复用各子阶段 typed 偏好 store 的公共逻辑:启动期注入初值、按槽位读、更新单槽位
/// 偏好并写 SharedPreferences。子类只需提供:SP key、单偏好的编/解码、空偏好,以及
/// 各自的细粒度 setter(在 [updateSlot] 之上拼)。
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/slot_prefs.dart';
import '../services/app_logger.dart';
import 'learning_settings_provider.dart' show sharedPreferencesProvider;

/// 按槽位偏好 Notifier 基类。[P] 为单槽位偏好(全字段可空、值相等)。
abstract class SlotPrefsNotifier<P> extends Notifier<SlotPrefs<P>> {
  /// 整份偏好表的 SharedPreferences key。
  String get spKey;

  /// 启动期 override 注入的初值 Provider。
  ProviderListenable<SlotPrefs<P>> get initialProvider;

  /// 该子阶段的空偏好(全 null)。
  P get emptyPrefs;

  /// 单槽位偏好 → JSON。
  Map<String, dynamic> encodePrefs(P prefs);

  @override
  SlotPrefs<P> build() => ref.read(initialProvider);

  /// 取某槽位偏好(无则空偏好)。
  P prefsFor(String slot) => state.maybe(slot) ?? emptyPrefs;

  /// 更新某槽位偏好并写盘;值未变化时跳过。
  Future<void> updateSlot(String slot, P next) async {
    if (state.maybe(slot) == next) return;
    state = state.withSlot(slot, next);
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setString(spKey, json.encode(state.toJson(encodePrefs)));
    } catch (e) {
      AppLogger.log('SlotPrefs', '写 SP 失败 key=$spKey: $e');
    }
  }
}
