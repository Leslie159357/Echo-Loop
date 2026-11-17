import 'package:flutter_test/flutter_test.dart';

import 'package:echo_loop/providers/tts/tts_controller_provider.dart';
import 'package:echo_loop/services/tts/tts_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('effectiveTtsEngine 生效规则', () {
    test('德语版统一走平台引擎，所选引擎不影响结果', () {
      for (final kind in TtsEngineKind.values) {
        expect(
          effectiveTtsEngine(kind),
          TtsEngineKind.platform,
          reason: '所选 $kind 应统一落到平台引擎（自建 Fish 网关）',
        );
      }
    });
  });
}
