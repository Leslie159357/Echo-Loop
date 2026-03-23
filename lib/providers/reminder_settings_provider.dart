/// 提醒设置状态管理 Provider
///
/// 使用 riverpod_generator 生成 keepAlive Notifier，
/// 通过 SharedPreferences 持久化提醒开关和时间设置。
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/reminder_settings.dart';

part 'reminder_settings_provider.g.dart';

const _spKey = 'reminder_settings';

/// 提醒设置 Notifier
///
/// `build()` 返回默认值并异步从 SP 加载持久化数据。
/// 外部通过 [update] 更新设置，自动持久化并同步 state。
@Riverpod(keepAlive: true)
class ReminderSettingsNotifier extends _$ReminderSettingsNotifier {
  @override
  ReminderSettings build() {
    _load();
    return const ReminderSettings();
  }

  /// 异步加载持久化设置
  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_spKey);
      if (jsonStr != null) {
        final loaded = ReminderSettings.fromJson(
          json.decode(jsonStr) as Map<String, dynamic>,
        );
        state = loaded;
      }
    } catch (e) {
      debugPrint('ReminderSettings: 加载设置失败: $e');
    }
  }

  /// 更新设置并持久化
  Future<void> update(ReminderSettings settings) async {
    state = settings;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_spKey, json.encode(settings.toJson()));
    } catch (e) {
      debugPrint('ReminderSettings: 保存设置失败: $e');
    }
  }
}
