/// Apple 录音识别平台桥接。
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/speech_practice_models.dart';

/// 平台桥接异常。
class SpeechPracticePlatformException implements Exception {
  /// 平台错误码。
  final String code;

  /// 错误消息。
  final String message;

  const SpeechPracticePlatformException(this.code, this.message);

  @override
  String toString() => 'SpeechPracticePlatformException($code, $message)';
}

/// 统一的录音识别后端接口。
abstract class SpeechPracticeBackend {
  /// 当前平台是否支持该能力。
  bool get isSupported;

  /// 获取权限状态。
  Future<SpeechPracticePermissionState> getPermissionStatus();

  /// 请求权限。
  Future<SpeechPracticePermissionState> requestPermissions();

  /// 录音识别事件流。
  Stream<SpeechPracticeEvent> get events;

  /// 开始 live ASR 录音。
  Future<String> startSession({
    required String promptId,
    String locale = 'en-US',
  });

  /// 停止 live ASR 录音。
  Future<SpeechPracticeStopResult> stopSession();

  /// 取消当前录音识别会话。
  Future<void> cancelSession();

  /// 删除临时录音文件。
  Future<void> deleteRecording(String filePath);
}

/// 原生录音识别桥接。
class SpeechPracticePlatform implements SpeechPracticeBackend {
  SpeechPracticePlatform();

  static SpeechPracticePlatform _instance = SpeechPracticePlatform();
  static const MethodChannel _channel = MethodChannel(
    'top.valuespot.fluency/speech_practice',
  );
  static const EventChannel _eventChannel = EventChannel(
    'top.valuespot.fluency/speech_practice/events',
  );

  Stream<SpeechPracticeEvent>? _events;

  /// 全局单例。
  static SpeechPracticePlatform get instance => _instance;

  /// 测试时替换单例。
  @visibleForTesting
  static SpeechPracticePlatform replaceInstance(
    SpeechPracticePlatform platform,
  ) {
    final old = _instance;
    _instance = platform;
    return old;
  }

  @override
  bool get isSupported => !kIsWeb && (Platform.isIOS || Platform.isMacOS);

  @override
  Future<SpeechPracticePermissionState> getPermissionStatus() async {
    _ensureSupported();
    final result = await _invokeMap('getPermissionStatus');
    return SpeechPracticePermissionState(
      microphone: _parsePermissionStatus(result['microphoneStatus'] as String?),
      speech: _parsePermissionStatus(result['speechStatus'] as String?),
    );
  }

  @override
  Future<SpeechPracticePermissionState> requestPermissions() async {
    _ensureSupported();
    final result = await _invokeMap('requestPermissions');
    return SpeechPracticePermissionState(
      microphone: _parsePermissionStatus(result['microphoneStatus'] as String?),
      speech: _parsePermissionStatus(result['speechStatus'] as String?),
    );
  }

  @override
  Stream<SpeechPracticeEvent> get events {
    _ensureSupported();
    return _events ??= _eventChannel
        .receiveBroadcastStream()
        .map(
          (event) => _parseEvent(
            (event as Map<Object?, Object?>?) ?? <Object?, Object?>{},
          ),
        )
        .handleError((error) {
          throw _parseException(error);
        })
        .asBroadcastStream();
  }

  @override
  Future<String> startSession({
    required String promptId,
    String locale = 'en-US',
  }) async {
    _ensureSupported();
    final result = await _invokeMap('startSession', {
      'promptId': promptId,
      'locale': locale,
    });
    final filePath = result['filePath'] as String?;
    if (filePath == null || filePath.isEmpty) {
      throw const SpeechPracticePlatformException(
        'invalidResult',
        'Missing recording file path',
      );
    }
    return filePath;
  }

  @override
  Future<SpeechPracticeStopResult> stopSession() async {
    _ensureSupported();
    final result = await _invokeMap('stopSession');
    return SpeechPracticeStopResult(filePath: result['filePath'] as String?);
  }

  @override
  Future<void> cancelSession() async {
    _ensureSupported();
    await _invokeMap('cancelSession');
  }

  @override
  Future<void> deleteRecording(String filePath) async {
    _ensureSupported();
    await _invokeMap('deleteRecording', {'filePath': filePath});
  }

  void _ensureSupported() {
    if (!isSupported) {
      throw const SpeechPracticePlatformException(
        'notAvailable',
        'Speech practice is only supported on iOS and macOS',
      );
    }
  }

  Future<Map<Object?, Object?>> _invokeMap(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    try {
      final result = await _channel.invokeMethod<Object?>(method, arguments);
      return (result as Map<Object?, Object?>?) ?? <Object?, Object?>{};
    } on MissingPluginException {
      throw const SpeechPracticePlatformException(
        'notAvailable',
        'Speech practice plugin is not registered on this platform',
      );
    } on PlatformException catch (error) {
      throw SpeechPracticePlatformException(
        error.code,
        error.message ?? 'Unknown platform error',
      );
    }
  }

  SpeechPracticeEvent _parseEvent(Map<Object?, Object?> event) {
    final type = switch (event['type'] as String?) {
      'partialTranscriptUpdated' =>
        SpeechPracticeEventType.partialTranscriptUpdated,
      'speechStarted' => SpeechPracticeEventType.speechStarted,
      'silenceProgress' => SpeechPracticeEventType.silenceProgress,
      'finalTranscriptReady' => SpeechPracticeEventType.finalTranscriptReady,
      _ => SpeechPracticeEventType.error,
    };
    return SpeechPracticeEvent(
      type: type,
      promptId: (event['promptId'] as String?) ?? '',
      transcript: event['transcript'] as String?,
      errorCode: event['errorCode'] as String?,
      errorMessage: event['errorMessage'] as String?,
      silenceDuration: switch (event['silenceMs']) {
        final int ms => Duration(milliseconds: ms),
        final num ms => Duration(milliseconds: ms.round()),
        _ => null,
      },
    );
  }

  Exception _parseException(Object error) {
    if (error is PlatformException) {
      return SpeechPracticePlatformException(
        error.code,
        error.message ?? 'Unknown platform error',
      );
    }
    if (error is MissingPluginException) {
      return const SpeechPracticePlatformException(
        'notAvailable',
        'Speech practice plugin is not registered on this platform',
      );
    }
    return SpeechPracticePlatformException('unknown', error.toString());
  }

  SpeechPracticePermissionStatus _parsePermissionStatus(String? value) {
    return switch (value) {
      'granted' => SpeechPracticePermissionStatus.granted,
      'denied' => SpeechPracticePermissionStatus.denied,
      'restricted' => SpeechPracticePermissionStatus.restricted,
      _ => SpeechPracticePermissionStatus.notDetermined,
    };
  }
}
