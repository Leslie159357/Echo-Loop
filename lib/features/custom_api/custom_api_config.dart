/// 自定义 AI API 配置与安全持久化。
///
/// 普通设置写入 SharedPreferences；API Key 仅写入系统安全存储（iOS Keychain）。
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/app_logger.dart';

const defaultCustomApiBaseUrl = 'https://api.openai.com/v1';
const defaultTextAiModel = 'gpt-5.6';
const defaultCloudTranscriptionModel = 'gpt-4o-transcribe-diarize';

/// 可由个人版 App 直接调用的 OpenAI 兼容 API 设置。
class CustomApiConfig {
  final bool enabled;
  final String baseUrl;
  final String textModel;
  final String transcriptionModel;
  final bool hasApiKey;
  final List<String> modelList;
  final int lastRefreshedAtMs;

  const CustomApiConfig({
    this.enabled = false,
    this.baseUrl = defaultCustomApiBaseUrl,
    this.textModel = defaultTextAiModel,
    this.transcriptionModel = defaultCloudTranscriptionModel,
    this.hasApiKey = false,
    this.modelList = const [],
    this.lastRefreshedAtMs = 0,
  });

  bool get isReady => enabled && baseUrl.trim().isNotEmpty && hasApiKey;

  /// API Key 不属于可序列化配置，避免落入普通偏好或备份文件。
  Map<String, dynamic> toPreferencesJson() => {
    'enabled': enabled,
    'baseUrl': baseUrl,
    'textModel': textModel,
    'transcriptionModel': transcriptionModel,
    'modelList': modelList,
    'lastRefreshedAtMs': lastRefreshedAtMs,
  };

  factory CustomApiConfig.fromPreferencesJson(
    Map<String, dynamic> json, {
    required bool hasApiKey,
  }) {
    final enabled = json['enabled'];
    final baseUrl = json['baseUrl'];
    final textModel = json['textModel'];
    final transcriptionModel = json['transcriptionModel'];
    final rawModelList = json['modelList'];
    final lastRefreshedAtMs = json['lastRefreshedAtMs'];
    return CustomApiConfig(
      enabled: enabled is bool ? enabled : false,
      baseUrl: baseUrl is String ? baseUrl : defaultCustomApiBaseUrl,
      textModel: textModel is String ? textModel : defaultTextAiModel,
      transcriptionModel: transcriptionModel is String
          ? transcriptionModel
          : defaultCloudTranscriptionModel,
      hasApiKey: hasApiKey,
      modelList: rawModelList is List
          ? rawModelList.whereType<String>().toList(growable: false)
          : const [],
      lastRefreshedAtMs: lastRefreshedAtMs is int ? lastRefreshedAtMs : 0,
    );
  }

  CustomApiConfig copyWith({
    bool? enabled,
    String? baseUrl,
    String? textModel,
    String? transcriptionModel,
    bool? hasApiKey,
    List<String>? modelList,
    int? lastRefreshedAtMs,
  }) => CustomApiConfig(
    enabled: enabled ?? this.enabled,
    baseUrl: baseUrl ?? this.baseUrl,
    textModel: textModel ?? this.textModel,
    transcriptionModel: transcriptionModel ?? this.transcriptionModel,
    hasApiKey: hasApiKey ?? this.hasApiKey,
    modelList: modelList ?? this.modelList,
    lastRefreshedAtMs: lastRefreshedAtMs ?? this.lastRefreshedAtMs,
  );
}

/// 配置存储边界，便于测试时注入内存实现。
abstract interface class CustomApiConfigStore {
  Future<CustomApiConfig> load();
  Future<String> readApiKey();
  Future<void> save(CustomApiConfig config, {String? apiKey});
  Future<void> clearApiKey();
}

class DeviceCustomApiConfigStore implements CustomApiConfigStore {
  static const _preferencesKey = 'custom_api_config_v2';
  static const _secureApiKey = 'custom_api_secret';

  final FlutterSecureStorage _secureStorage;

  const DeviceCustomApiConfigStore({
    FlutterSecureStorage secureStorage = const FlutterSecureStorage(),
  }) : _secureStorage = secureStorage;

  @override
  Future<CustomApiConfig> load() async {
    final apiKey = await readApiKey();
    try {
      final preferences = await SharedPreferences.getInstance();
      final encoded = preferences.getString(_preferencesKey);
      if (encoded == null || encoded.isEmpty) {
        return CustomApiConfig(hasApiKey: apiKey.isNotEmpty);
      }
      final decoded = jsonDecode(encoded);
      if (decoded is! Map<String, dynamic>) {
        return CustomApiConfig(hasApiKey: apiKey.isNotEmpty);
      }
      return CustomApiConfig.fromPreferencesJson(
        decoded,
        hasApiKey: apiKey.isNotEmpty,
      );
    } catch (error) {
      AppLogger.log('CustomAPI', '读取自定义 API 配置失败: $error');
      return CustomApiConfig(hasApiKey: apiKey.isNotEmpty);
    }
  }

  @override
  Future<String> readApiKey() async {
    try {
      return (await _secureStorage.read(key: _secureApiKey))?.trim() ?? '';
    } catch (error) {
      AppLogger.log('CustomAPI', '读取安全存储失败: $error');
      return '';
    }
  }

  @override
  Future<void> save(CustomApiConfig config, {String? apiKey}) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _preferencesKey,
      jsonEncode(config.toPreferencesJson()),
    );
    if (apiKey != null) {
      final normalized = apiKey.trim();
      if (normalized.isEmpty) {
        await clearApiKey();
      } else {
        await _secureStorage.write(key: _secureApiKey, value: normalized);
      }
    }
  }

  @override
  Future<void> clearApiKey() => _secureStorage.delete(key: _secureApiKey);
}

class CustomApiConfigNotifier extends StateNotifier<CustomApiConfig> {
  final CustomApiConfigStore _store;
  String _apiKey = '';

  late final Future<void> ready;

  CustomApiConfigNotifier(this._store) : super(const CustomApiConfig()) {
    ready = _load();
  }

  String get apiKey => _apiKey;

  Future<void> _load() async {
    _apiKey = await _store.readApiKey();
    final loaded = await _store.load();
    if (!mounted) return;
    state = loaded.copyWith(hasApiKey: _apiKey.isNotEmpty);
  }

  Future<void> update(CustomApiConfig config, {String? apiKey}) async {
    await ready;
    if (apiKey != null) _apiKey = apiKey.trim();
    final next = config.copyWith(hasApiKey: _apiKey.isNotEmpty);
    await _store.save(next, apiKey: apiKey);
    state = next;
  }

  Future<void> clearApiKey() async {
    await ready;
    await _store.clearApiKey();
    _apiKey = '';
    state = state.copyWith(hasApiKey: false);
    await _store.save(state);
  }

  /// 从兼容的 `GET /v1/models` 端点刷新文本模型列表。
  Future<List<String>> refreshModels() async {
    await ready;
    if (!state.isReady) return const [];

    final baseUrl = normalizeCustomApiBaseUrl(state.baseUrl);
    final dio = Dio(
      BaseOptions(
        baseUrl: '$baseUrl/',
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        headers: {'Authorization': 'Bearer $_apiKey'},
      ),
    );
    try {
      final response = await dio.get<Map<String, dynamic>>('models');
      final rawModels = response.data?['data'];
      if (rawModels is! List) return const [];
      final models = rawModels
          .whereType<Map<String, dynamic>>()
          .map((model) => model['id'])
          .whereType<String>()
          .where((model) => model.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      final next = state.copyWith(
        modelList: models,
        lastRefreshedAtMs: DateTime.now().millisecondsSinceEpoch,
      );
      await _store.save(next);
      state = next;
      return models;
    } catch (error) {
      AppLogger.log('CustomAPI', '刷新模型列表失败: $error');
      return const [];
    } finally {
      dio.close();
    }
  }
}

String normalizeCustomApiBaseUrl(String value) =>
    value.trim().replaceFirst(RegExp(r'/+$'), '');

final customApiConfigNotifierProvider =
    StateNotifierProvider<CustomApiConfigNotifier, CustomApiConfig>(
      (ref) => CustomApiConfigNotifier(const DeviceCustomApiConfigStore()),
    );
