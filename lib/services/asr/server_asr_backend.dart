/// 独服云端 Whisper 大模型打分后端 (Large-v3-Turbo)。
///
/// 组合 Native 录音 + 自建独服 `/api/v2/speech/transcribe` 同步 ASR。
library;

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import '../../models/speech_practice_models.dart';
import '../app_logger.dart';
import '../speech_practice_platform.dart';

class ServerAsrBackend implements SpeechPracticeBackend {
  final SpeechPracticePlatform _platform;
  final Dio _dio;
  final String _serverUrl;

  String? _currentFilePath;
  int _generation = 0;

  StreamController<SpeechPracticeEvent>? _mergedController;
  StreamSubscription<SpeechPracticeEvent>? _platformSubscription;

  ServerAsrBackend({
    required SpeechPracticePlatform platform,
    String serverUrl = 'https://echoloop.1122275.xyz/api/v2/speech/transcribe',
  })  : _platform = platform,
        _serverUrl = serverUrl,
        _dio = Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 15),
          ),
        );

  @override
  bool get isSupported => _platform.isSupported;

  @override
  Future<SpeechPracticePermissionState> getPermissionStatus() =>
      _platform.getPermissionStatus();

  @override
  Future<SpeechPracticePermissionState> requestPermissions({
    bool onlyMic = false,
  }) =>
      _platform.requestPermissions(onlyMic: true);

  @override
  Future<int> getDeviceRamBytes() => _platform.getDeviceRamBytes();

  @override
  Future<void> setRecognitionEnabled(bool enabled) =>
      _platform.setRecognitionEnabled(false);

  @override
  Stream<SpeechPracticeEvent> get events {
    final existing = _mergedController;
    if (existing != null && !existing.isClosed) return existing.stream;

    final controller = StreamController<SpeechPracticeEvent>.broadcast();
    _mergedController = controller;

    _platformSubscription = _platform.events.listen(
      (event) => _handlePlatformEvent(event, controller),
      onError: controller.addError,
    );

    return controller.stream;
  }

  @override
  Future<void> warmup({String locale = 'de-DE'}) =>
      _platform.warmup(locale: locale);

  @override
  Future<String> startSession({
    required String promptId,
    String locale = 'de-DE',
  }) async {
    _generation++;
    AppLogger.log(
      'ServerASR',
      '┌ startSession promptId=$promptId locale=$locale generation=$_generation',
    );
    final filePath = await _platform.startSession(
      promptId: promptId,
      locale: locale,
    );
    _currentFilePath = filePath;
    AppLogger.log('ServerASR', '└ startSession filePath=$filePath');
    return filePath;
  }

  @override
  Future<SpeechPracticeStopResult> stopSession() async {
    AppLogger.log(
      'ServerASR',
      '┌ stopSession currentFilePath=${_currentFilePath ?? '(null)'} generation=$_generation',
    );
    final result = await _platform.stopSession();
    AppLogger.log(
      'ServerASR',
      '└ stopSession filePath=${result.filePath ?? '(null)'}',
    );
    return result;
  }

  @override
  Future<void> cancelSession() {
    _generation++;
    _currentFilePath = null;
    AppLogger.log('ServerASR', '● cancelSession generation=$_generation');
    return _platform.cancelSession();
  }

  @override
  Future<void> deleteRecording(String filePath) =>
      _platform.deleteRecording(filePath);

  @override
  Future<void> shutdown() async {
    _generation++;
    _currentFilePath = null;
    AppLogger.log('ServerASR', '● shutdown generation=$_generation');
    await _platformSubscription?.cancel();
    _platformSubscription = null;
    await _mergedController?.close();
    _mergedController = null;
    await _platform.shutdown();
  }

  void _handlePlatformEvent(
    SpeechPracticeEvent event,
    StreamController<SpeechPracticeEvent> controller,
  ) {
    if (controller.isClosed) return;

    if (event.type != SpeechPracticeEventType.finalTranscriptReady) {
      controller.add(event);
      return;
    }

    final filePath = _currentFilePath;
    if (filePath == null) {
      controller.add(event);
      return;
    }

    final generation = _generation;
    AppLogger.log(
      'ServerASR',
      '⏳ 独服 Large-v3 实时转录开始 promptId=${event.promptId} filePath=$filePath generation=$generation',
    );

    _transcribeViaServer(filePath)
        .then((text) {
          if (_generation != generation || controller.isClosed) return;

          AppLogger.log(
            'ServerASR',
            '✓ 独服转录完成 promptId=${event.promptId} text="$text"',
          );
          controller.add(
            SpeechPracticeEvent(
              type: SpeechPracticeEventType.finalTranscriptReady,
              promptId: event.promptId,
              transcript: text,
            ),
          );
        })
        .catchError((Object error) {
          if (_generation != generation || controller.isClosed) return;

          AppLogger.log(
            'ServerASR',
            '✗ 独服转录失败 promptId=${event.promptId}: $error',
          );
          controller.add(event);
        });
  }

  Future<String> _transcribeViaServer(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw StateError('Audio file not found: $filePath');
    }
    final bytes = await file.readAsBytes();

    final resp = await _dio.post<Map<String, dynamic>>(
      _serverUrl,
      data: bytes,
      options: Options(
        headers: {'Content-Type': 'audio/wav'},
      ),
    );

    final data = resp.data;
    if (data != null && data['transcript'] != null) {
      return (data['transcript'] as String).trim();
    }
    return '';
  }
}
