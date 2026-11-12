import 'package:flutter_test/flutter_test.dart';

import 'package:echo_loop/providers/tts/tts_controller_provider.dart';
import 'package:echo_loop/services/tts/tts_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('effectiveTtsEngine 生效门控', () {
    test('选平台 → 始终平台', () {
      expect(
        effectiveTtsEngine(
          TtsEngineKind.platform,
          kokoroReady: false,
          piperReady: false,
        ),
        TtsEngineKind.platform,
      );
      expect(
        effectiveTtsEngine(
          TtsEngineKind.platform,
          kokoroReady: true,
          piperReady: true,
        ),
        TtsEngineKind.platform,
      );
    });

    test('选 Echo Loop 但未就绪 → 德语版统一走平台 Fish 网关', () {
      expect(
        effectiveTtsEngine(
          TtsEngineKind.kokoro,
          kokoroReady: false,
          piperReady: true,
        ),
        TtsEngineKind.platform,
      );
    });

    test('选 Echo Loop 且已就绪 → 德语版仍走平台 Fish 网关', () {
      expect(
        effectiveTtsEngine(
          TtsEngineKind.kokoro,
          kokoroReady: true,
          piperReady: false,
        ),
        TtsEngineKind.platform,
      );
    });

    test('选 Piper 但未就绪 → 德语版统一走平台 Fish 网关', () {
      expect(
        effectiveTtsEngine(
          TtsEngineKind.piper,
          kokoroReady: true,
          piperReady: false,
        ),
        TtsEngineKind.platform,
      );
    });

    test('选 Piper 且已就绪 → 德语版仍走平台 Fish 网关', () {
      expect(
        effectiveTtsEngine(
          TtsEngineKind.piper,
          kokoroReady: false,
          piperReady: true,
        ),
        TtsEngineKind.platform,
      );
    });
  });
}
