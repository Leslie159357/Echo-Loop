import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:echo_loop/providers/offline_asr_settings_provider.dart';
import 'package:echo_loop/services/asr/asr_model_manager.dart';
import 'package:echo_loop/services/asr/offline_asr_engine.dart';

class _FakeAsrModelManager extends AsrModelManager {
  _FakeAsrModelManager({
    required this.downloaded,
    required this.localSizeBytes,
  });

  final bool downloaded;
  final int localSizeBytes;

  @override
  Future<bool> isModelDownloaded(String modelId) async => downloaded;

  @override
  Future<int> modelLocalSize(String modelId) async => localSizeBytes;
}

void main() {
  const recommendedModel = AsrModelInfo(
    id: 'whisper-base-en-int8',
    displayName: 'Whisper Base.en',
    type: AsrModelType.whisper,
  );

  test('启动加载时保留残留模型大小并标记为 failed', () async {
    SharedPreferences.setMockInitialValues({'offline_asr_enabled': true});
    final prefs = await SharedPreferences.getInstance();
    final manager = _FakeAsrModelManager(
      downloaded: false,
      localSizeBytes: 150 * 1024 * 1024,
    );

    final state = await loadInitialOfflineAsrSettingsState(
      prefs: prefs,
      modelManager: manager,
      recommendedModel: recommendedModel,
      defaultBackend: AsrBackend.offline,
    );

    expect(state.enabled, isTrue);
    expect(state.downloadStatus, AsrModelDownloadStatus.failed);
    expect(state.localSizeBytes, 150 * 1024 * 1024);
  });

  test('启动加载时完整模型保持 downloaded', () async {
    SharedPreferences.setMockInitialValues({
      'offline_asr_enabled': true,
      'offline_asr_downloaded_whisper-base-en-int8': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final manager = _FakeAsrModelManager(
      downloaded: true,
      localSizeBytes: 209 * 1024 * 1024,
    );

    final state = await loadInitialOfflineAsrSettingsState(
      prefs: prefs,
      modelManager: manager,
      recommendedModel: recommendedModel,
      defaultBackend: AsrBackend.offline,
    );

    expect(state.downloadStatus, AsrModelDownloadStatus.downloaded);
    expect(state.localSizeBytes, 209 * 1024 * 1024);
  });

  test('启动加载时没有完成标记的残留模型按 failed 处理', () async {
    SharedPreferences.setMockInitialValues({
      'offline_asr_enabled': true,
      'offline_asr_downloaded_whisper-base-en-int8': false,
    });
    final prefs = await SharedPreferences.getInstance();
    final manager = _FakeAsrModelManager(
      downloaded: true,
      localSizeBytes: 209 * 1024 * 1024,
    );

    final state = await loadInitialOfflineAsrSettingsState(
      prefs: prefs,
      modelManager: manager,
      recommendedModel: recommendedModel,
      defaultBackend: AsrBackend.offline,
    );

    expect(state.downloadStatus, AsrModelDownloadStatus.failed);
    expect(
      prefs.getBool('offline_asr_downloaded_whisper-base-en-int8'),
      isFalse,
    );
  });
}
