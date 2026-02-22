import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/playback_settings.dart';

/// SharedPreferences 存储服务
/// 保留纯设置项的存取（PlaybackSettings）
class StorageService {
  static const String _settingsKey = 'playback_settings';

  // Playback Settings
  static Future<PlaybackSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_settingsKey);
    if (jsonString == null) return PlaybackSettings();

    try {
      return PlaybackSettings.fromJson(json.decode(jsonString));
    } catch (e) {
      print('Error loading settings: $e');
      return PlaybackSettings();
    }
  }

  static Future<void> saveSettings(PlaybackSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = json.encode(settings.toJson());
    await prefs.setString(_settingsKey, jsonString);
  }
}
