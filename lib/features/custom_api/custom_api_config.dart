import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AiProvider { openAI, anthropic, gemini, openRouter, custom }

class CustomApiConfig {
  final bool enabled;
  final String baseUrl;
  final String apiKey;
  final String model;
  final AiProvider provider;
  final bool transcriptionEnabled;
  final String transcriptionBaseUrl;
  final String transcriptionApiKey;
  final String transcriptionModel;
  final bool chatEnabled;
  final String chatBaseUrl;
  final String chatApiKey;
  final String chatModel;
  final AiProvider chatProvider;

  const CustomApiConfig({
    this.enabled = false,
    this.baseUrl = '',
    this.apiKey = '',
    this.model = '',
    this.provider = AiProvider.custom,
    this.transcriptionEnabled = false,
    this.transcriptionBaseUrl = '',
    this.transcriptionApiKey = '',
    this.transcriptionModel = 'FunAudioLLM/SenseVoiceSmall',
    this.chatEnabled = false,
    this.chatBaseUrl = '',
    this.chatApiKey = '',
    this.chatModel = '',
    this.chatProvider = AiProvider.custom,
  });

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'baseUrl': baseUrl,
    'apiKey': apiKey,
    'model': model,
    'provider': provider.name,
    'transcriptionEnabled': transcriptionEnabled,
    'transcriptionBaseUrl': transcriptionBaseUrl,
    'transcriptionApiKey': transcriptionApiKey,
    'transcriptionModel': transcriptionModel,
    'chatEnabled': chatEnabled,
    'chatBaseUrl': chatBaseUrl,
    'chatApiKey': chatApiKey,
    'chatModel': chatModel,
    'chatProvider': chatProvider.name,
  };

  factory CustomApiConfig.fromJson(Map<String, dynamic> j) => CustomApiConfig(
    enabled: j['enabled'] ?? false,
    baseUrl: j['baseUrl'] ?? '',
    apiKey: j['apiKey'] ?? '',
    model: j['model'] ?? '',
    provider: AiProvider.values.firstWhere(
      (e) => e.name == (j['provider'] as String? ?? ''),
      orElse: () => AiProvider.custom,
    ),
    transcriptionEnabled: j['transcriptionEnabled'] ?? false,
    transcriptionBaseUrl: j['transcriptionBaseUrl'] ?? '',
    transcriptionApiKey: j['transcriptionApiKey'] ?? '',
    transcriptionModel: j['transcriptionModel'] ?? 'FunAudioLLM/SenseVoiceSmall',
    chatEnabled: j['chatEnabled'] ?? false,
    chatBaseUrl: j['chatBaseUrl'] ?? '',
    chatApiKey: j['chatApiKey'] ?? '',
    chatModel: j['chatModel'] ?? '',
    chatProvider: AiProvider.values.firstWhere(
      (e) => e.name == (j['chatProvider'] as String? ?? ''),
      orElse: () => AiProvider.custom,
    ),
  );

  CustomApiConfig copyWith({
    bool? enabled,
    String? baseUrl,
    String? apiKey,
    String? model,
    AiProvider? provider,
    bool? transcriptionEnabled,
    String? transcriptionBaseUrl,
    String? transcriptionApiKey,
    String? transcriptionModel,
    bool? chatEnabled,
    String? chatBaseUrl,
    String? chatApiKey,
    String? chatModel,
    AiProvider? chatProvider,
  }) => CustomApiConfig(
    enabled: enabled ?? this.enabled,
    baseUrl: baseUrl ?? this.baseUrl,
    apiKey: apiKey ?? this.apiKey,
    model: model ?? this.model,
    provider: provider ?? this.provider,
    transcriptionEnabled: transcriptionEnabled ?? this.transcriptionEnabled,
    transcriptionBaseUrl: transcriptionBaseUrl ?? this.transcriptionBaseUrl,
    transcriptionApiKey: transcriptionApiKey ?? this.transcriptionApiKey,
    transcriptionModel: transcriptionModel ?? this.transcriptionModel,
    chatEnabled: chatEnabled ?? this.chatEnabled,
    chatBaseUrl: chatBaseUrl ?? this.chatBaseUrl,
    chatApiKey: chatApiKey ?? this.chatApiKey,
    chatModel: chatModel ?? this.chatModel,
    chatProvider: chatProvider ?? this.chatProvider,
  );
}

class CustomApiConfigNotifier extends StateNotifier<CustomApiConfig> {
  CustomApiConfigNotifier() : super(const CustomApiConfig()) { _load(); }

  Future<void> _load() async {
    final j = (await SharedPreferences.getInstance()).getString('custom_api_config');
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
    await (await SharedPreferences.getInstance()).setString(
      'custom_api_config',
      jsonEncode(c.toJson()),
    );
  }
}

final customApiConfigNotifierProvider =
    StateNotifierProvider<CustomApiConfigNotifier, CustomApiConfig>(
      (ref) => CustomApiConfigNotifier(),
    );
