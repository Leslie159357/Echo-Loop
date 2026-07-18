import 'package:echo_loop/features/custom_api/custom_api_config.dart';
import 'package:echo_loop/services/sentence_ai_api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryCustomApiConfigStore implements CustomApiConfigStore {
  CustomApiConfig config;
  String apiKey;

  _MemoryCustomApiConfigStore({
    this.config = const CustomApiConfig(),
    this.apiKey = '',
  });

  @override
  Future<void> clearApiKey() async => apiKey = '';

  @override
  Future<CustomApiConfig> load() async =>
      config.copyWith(hasApiKey: apiKey.isNotEmpty);

  @override
  Future<String> readApiKey() async => apiKey;

  @override
  Future<void> save(CustomApiConfig value, {String? apiKey}) async {
    config = value;
    if (apiKey != null) this.apiKey = apiKey;
  }
}

void main() {
  group('CustomApiConfig', () {
    test('uses personal edition defaults', () {
      const config = CustomApiConfig();

      expect(config.baseUrl, defaultCustomApiBaseUrl);
      expect(config.textModel, defaultTextAiModel);
      expect(
        config.transcriptionModel,
        defaultCloudTranscriptionModel,
      );
      expect(config.isReady, isFalse);
    });

    test('never serializes the API key', () {
      const config = CustomApiConfig(enabled: true, hasApiKey: true);

      final json = config.toPreferencesJson();

      expect(json.containsKey('apiKey'), isFalse);
      expect(json.containsKey('hasApiKey'), isFalse);
    });

    test('normalizes a trailing slash in base URLs', () {
      expect(
        normalizeCustomApiBaseUrl('https://api.openai.com/v1///'),
        'https://api.openai.com/v1',
      );
    });
  });

  group('CustomApiConfigNotifier', () {
    test('loads the API key without exposing it in persisted settings', () async {
      final store = _MemoryCustomApiConfigStore(
        config: const CustomApiConfig(enabled: true),
        apiKey: 'secret-key',
      );
      final notifier = CustomApiConfigNotifier(store);
      addTearDown(notifier.dispose);

      await notifier.ready;

      expect(notifier.state.hasApiKey, isTrue);
      expect(notifier.state.isReady, isTrue);
      expect(notifier.apiKey, 'secret-key');
      expect(
        notifier.state.toPreferencesJson().values,
        isNot(contains('secret-key')),
      );
    });

    test('updates and clears the secure key separately', () async {
      final store = _MemoryCustomApiConfigStore();
      final notifier = CustomApiConfigNotifier(store);
      addTearDown(notifier.dispose);
      await notifier.ready;

      await notifier.update(
        notifier.state.copyWith(enabled: true),
        apiKey: 'new-key',
      );

      expect(store.apiKey, 'new-key');
      expect(notifier.state.hasApiKey, isTrue);

      await notifier.clearApiKey();

      expect(store.apiKey, isEmpty);
      expect(notifier.state.hasApiKey, isFalse);
      expect(notifier.state.isReady, isFalse);
    });

    test(
      'selects the direct text AI client when configuration is ready',
      () async {
        final store = _MemoryCustomApiConfigStore(
          config: const CustomApiConfig(enabled: true),
          apiKey: 'personal-key',
        );
        final container = ProviderContainer(
          overrides: [
            customApiConfigNotifierProvider.overrideWith(
              (ref) => CustomApiConfigNotifier(store),
            ),
          ],
        );
        addTearDown(container.dispose);
        await container
            .read(customApiConfigNotifierProvider.notifier)
            .ready;

        expect(
          container.read(sentenceAiApiClientProvider),
          isA<CustomSentenceAiApiClient>(),
        );
      },
    );
  });
}
