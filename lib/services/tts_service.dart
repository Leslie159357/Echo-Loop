/// TTS 发音服务
///
/// 封装 flutter_tts，提供单词发音功能。
/// 单例模式，Flashcard 和词典弹窗共用。
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// TTS 发音服务单例
class TtsService {
  TtsService._() {
    _init();
  }

  /// 测试用构造器，允许注入 mock FlutterTts
  @visibleForTesting
  TtsService.withTts(FlutterTts tts) : _tts = tts;

  static TtsService _instance = TtsService._();

  /// 全局单例
  static TtsService get instance => _instance;

  /// 测试用：替换全局单例，返回旧实例以便恢复
  @visibleForTesting
  static TtsService replaceInstance(TtsService service) {
    final old = _instance;
    _instance = service;
    return old;
  }

  late final FlutterTts _tts;

  /// 初始化 TTS 引擎
  void _init() {
    _tts = FlutterTts();
    _tts.setLanguage('en-US');
    _tts.setSpeechRate(0.45);
    _tts.setVolume(1.0);
    _tts.setPitch(1.0);
    _tts.awaitSpeakCompletion(true);
  }

  /// 朗读文本
  ///
  /// 如果正在播放则先停止再播放新内容。
  /// 返回的 Future 在 TTS 播报完成后才 complete。
  Future<void> speak(String text) async {
    await _tts.stop();
    await _tts.speak(text);
  }

  /// 停止播放
  Future<void> stop() async {
    await _tts.stop();
  }

  /// 释放资源
  void dispose() {
    _tts.stop();
  }
}
