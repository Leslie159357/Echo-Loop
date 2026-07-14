/// 自定义 API 配置
///
/// 管理 OpenAI 兼容 API 的连接参数和可用模型列表。
/// 支持模型列表刷新（调用 GET /v1/models）。
library;

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/app_logger.dart';

enum AiProvider { openAI, anthropic, gemini, openRouter, custom }

class CustomApiConfig {
  final bool enabled;
  final String baseUrl;
  final String apiKey;
  final String model;
  final AiProvider provider;

  /// 缓存的可用模型列表（由 [CustomApiConfigNotifier.refreshModels] 填充）。
  final List<String> modelList;

  /// 上次刷新模型列表的时间（毫秒时间戳，0 表示从未刷新）。
  final int lastRefreshedAtMs;

  const CustomApiConfig({
    this.enabled = false,
    this.baseUrl = '',
    this.apiKey = '',
    this.model = '',
    this.provider = AiProvider.custom,
    this.modelList = const [],
    this.lastRefreshedAtMs = 0,
  });

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'baseUrl': baseUrl,
        'apiKey': apiKey,
        'model': model,
        'provider': provider.name,
        'modelList': modelList,
        'lastRefreshedAtMs': lastRefreshedAtMs,
      };

  factory CustomApiConfig.fromJson(Map<String, dynamic> j) => CustomApiConfig(
        enabled: j['enabled'] ?? false,
        baseUrl: j['baseUrl'] ?? '',
        apiKey: j['apiKey'] ?? '',
        model: j['model'] ?? '',
        provider: AiProvider.values.firstWhere(
          (p) => p.name == j['provider'],
          orElse: () => AiProvider.custom,
        ),
        modelList: (j['modelList'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        lastRefreshedAtMs: j['lastRefreshedAtMs'] as int? ?? 0,
      );

  CustomApiConfig copyWith({
    bool? enabled,
    String? baseUrl,
    String? apiKey,
    String? model,
    AiProvider? provider,
    List<String>? modelList,
    int? lastRefreshedAtMs,
  }) =>
      CustomApiConfig(
        enabled: enabled ?? this.enabled,
        baseUrl: baseUrl ?? this.baseUrl,
        apiKey: apiKey ?? this.apiKey,
        model: model ?? this.model,
        provider: provider ?? this.provider,
        modelList: modelList ?? this.modelList,
        lastRefreshedAtMs: lastRefreshedAtMs ?? this.lastRefreshedAtMs,
      );
}

class CustomApiConfigNotifier extends StateNotifier<CustomApiConfig> {
  CustomApiConfigNotifier() : super(const CustomApiConfig()) {
    _load();
  }

  Future<void> _load() async {
    final j =
        (await SharedPreferences.getInstance()).getString('custom_api_config');
    if (j != null) {
      try {
        state = CustomApiConfig.fromJson(
          Map<String, dynamic>.from(jsonDecode(j) as Map),
        );
      } catch (_) {}
    }
  }

  Future<void> update(CustomApiConfig c) async {
    state = c;
    await (await SharedPreferences.getInstance())
        .setString('custom_api_config', jsonEncode(c.toJson()));
  }

  Future<void> toggle(bool e) async => await update(state.copyWith(enabled: e));

  /// 刷新模型列表：调用 API 的 `GET /v1/models` 端点。
  ///
  /// 需要 [baseUrl] 已配置。返回拉取到的模型 ID 列表。
  Future<List<String>> refreshModels() async {
    final baseUrl = state.baseUrl.trim();
    if (baseUrl.isEmpty) return [];

    try {
      final dio = Dio(BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          if (state.apiKey.isNotEmpty)
            'Authorization': 'Bearer ${state.apiKey}',
        },
      ));
      final response = await dio.get<Map<String, dynamic>>('/models');
      final data = response.data;
      if (data == null) return [];

      final models = data['data'];
      if (models is! List) return [];

      final modelList = models
          .map((m) => m is Map ? m['id']?.toString() ?? '' : '')
          .where((id) => id.isNotEmpty)
          .toList()
        ..sort();

      await update(state.copyWith(
        modelList: modelList,
        lastRefreshedAtMs: DateTime.now().millisecondsSinceEpoch,
      ));
      return modelList;
    } catch (e) {
      AppLogger.log('CustomAPI', '刷新模型列表失败: $e');
      return [];
    }
  }
}

final customApiConfigNotifierProvider =
    StateNotifierProvider<CustomApiConfigNotifier, CustomApiConfig>(
  (ref) => CustomApiConfigNotifier(),
);
