/// 德语特化版的行为基线。
///
/// 这些是 fork 刻意偏离上游的产品决策，必须由本文件守住；
/// 上游自带用例中与之冲突的部分见 `tool/fork_test_exclusions.txt`。
library;

import 'package:echo_loop/config/api_config.dart';
import 'package:echo_loop/features/auth/providers/auth_providers.dart';
import 'package:echo_loop/features/subscription/models/premium_feature.dart';
import 'package:echo_loop/features/subscription/providers/feature_access_provider.dart';
import 'package:echo_loop/models/dictionary/dictionary_settings.dart';
import 'package:echo_loop/providers/tts/tts_settings_provider.dart';
import 'package:echo_loop/services/tts/edge_voices.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('免登录自建网关', () {
    test('始终提供 self-hosted 会话，isAuthenticated 为 true', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.listen(supabaseSessionProvider, (_, __) {});

      final session = await container.read(supabaseSessionProvider.future);
      expect(session, isNotNull);
      expect(session!.user.id, 'self-hosted-user');
      expect(container.read(isAuthenticatedProvider), isTrue);
    });

    test('所有高级功能对本机用户直接放行', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      for (final feature in [
        PremiumFeature.aiTranslation,
        PremiumFeature.aiAnalysis,
        PremiumFeature.aiSenseGroup,
      ]) {
        expect(
          container.read(featureAccessProvider(feature)),
          isTrue,
          reason: '德语版免登录全开：$feature',
        );
      }
    });
  });

  group('德语化默认值', () {
    test('词典默认源是德语助手', () {
      expect(DictionarySettings.defaultId, 'dehelper');
    });

    test('TTS 语言标签固定 de-DE，默认音色是德语音色', () {
      const settings = TtsSettings();
      expect(settings.languageTag, 'de-DE');
      expect(settings.toSpeechConfig().languageTag, 'de-DE');
      expect(settings.toSpeechConfig().voiceName, 'de1');
      expect(edgeDefaultVoiceUs, startsWith('de-DE-'));
      expect(edgeDefaultVoiceUk, startsWith('de-DE-'));
    });

    test('后端基址走自建网关', () {
      expect(apiBaseUrl, 'https://echoloop.1122275.xyz');
    });
  });
}
