import 'package:flutter_test/flutter_test.dart';

import 'package:echo_loop/services/asr/offline_asr_engine.dart';
import 'package:echo_loop/services/asr/sherpa_onnx_engine.dart';

void main() {
  group('SherpaOnnxEngine', () {
    test('初始状态：isReady 为 false，currentModel 为 null', () {
      final engine = SherpaOnnxEngine();
      expect(engine.isReady, isFalse);
      expect(engine.currentModel, isNull);
      expect(engine.name, 'sherpa-onnx');
    });

    test('未初始化时 transcribe 抛出 StateError', () async {
      final engine = SherpaOnnxEngine();
      expect(() => engine.transcribe('/any/path.wav'), throwsStateError);
    });
  });
}
