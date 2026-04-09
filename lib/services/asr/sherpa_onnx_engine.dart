/// sherpa-onnx 离线 ASR 引擎实现。
///
/// 通过 sherpa-onnx FFI 绑定加载 Moonshine 或 Whisper ONNX 模型，
/// Recognizer 实例在 [initialize] 时创建并常驻内存，
/// [transcribe] 直接复用，避免每次重新加载模型。
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'audio_file_reader.dart';
import 'offline_asr_engine.dart';

/// sherpa-onnx 离线 ASR 引擎。
///
/// [initialize] 时加载模型到内存（耗时数秒），之后 [transcribe] 仅执行推理。
/// 切换模型需先 [dispose] 再重新 [initialize]。
class SherpaOnnxEngine implements OfflineAsrEngine {
  AsrModelConfig? _config;
  sherpa.OfflineRecognizer? _recognizer;
  static bool _bindingsInitialized = false;

  /// 创建 Recognizer，使用指定 provider，失败时回退到 CPU。
  static sherpa.OfflineRecognizer _createRecognizer(AsrModelConfig config) {
    final requestedProvider = config.provider ?? _platformProvider();
    final primaryConfig = _buildConfig(
      modelDir: config.modelDir,
      modelType: config.model.type,
      modelId: config.model.id,
      numThreads: config.numThreads,
      provider: requestedProvider,
    );

    try {
      return sherpa.OfflineRecognizer(primaryConfig);
    } catch (e) {
      if (requestedProvider == 'cpu') rethrow;
      // 硬件加速失败，回退到 CPU。
      final cpuConfig = _buildConfig(
        modelDir: config.modelDir,
        modelType: config.model.type,
        modelId: config.model.id,
        numThreads: config.numThreads,
        provider: 'cpu',
      );
      return sherpa.OfflineRecognizer(cpuConfig);
    }
  }

  @override
  String get name => 'sherpa-onnx';

  @override
  bool get isReady => _recognizer != null;

  @override
  AsrModelInfo? get currentModel => _config?.model;

  @override
  Future<void> initialize(AsrModelConfig config) async {
    // 如果已加载相同模型且 provider 相同，跳过。
    if (_config?.model.id == config.model.id &&
        _config?.provider == config.provider &&
        _recognizer != null) {
      return;
    }

    // 先释放旧 Recognizer。
    await dispose();

    if (!_bindingsInitialized) {
      sherpa.initBindings();
      _bindingsInitialized = true;
    }

    _recognizer = _createRecognizer(config);
    _config = config;
  }

  /// 转录音频文件。
  ///
  /// 当前限制：FFI 推理在主线程同步执行（~0.5-2s），会短暂阻塞 UI。
  /// Recognizer FFI 指针无法跨 Isolate 传递，常驻 Isolate + SendPort
  /// 模式留待生产环境接入时优化。
  @override
  Future<AsrResult> transcribe(String wavPath) async {
    final recognizer = _recognizer;
    if (recognizer == null) {
      throw StateError('Engine not initialized. Call initialize() first.');
    }

    // 读取音频文件（支持 WAV 和 CAF 格式）。
    final audioData = readAudioFile(wavPath);
    if (audioData.samples.isEmpty) {
      return const AsrResult(text: '', inferenceTime: Duration.zero);
    }

    final stopwatch = Stopwatch()..start();

    final stream = recognizer.createStream();
    stream.acceptWaveform(
      samples: audioData.samples,
      sampleRate: audioData.sampleRate,
    );
    recognizer.decode(stream);
    final result = recognizer.getResult(stream);

    stopwatch.stop();

    final text = result.text.trim();
    stream.free();

    return AsrResult(text: text, inferenceTime: stopwatch.elapsed);
  }

  @override
  Future<void> dispose() async {
    _recognizer?.free();
    _recognizer = null;
    _config = null;
  }
}

// ---------------------------------------------------------------------------
// sherpa-onnx 配置构建
// ---------------------------------------------------------------------------

/// 获取当前平台的推理加速 provider。
///
/// iOS/macOS：CoreML 对 int8 量化模型反而更慢，使用 CPU。
/// Android：尝试 NNAPI（GPU/DSP/NPU 加速），失败时 fallback 到 CPU。
String _platformProvider() {
  if (Platform.isAndroid) return 'nnapi';
  return 'cpu';
}

/// 根据模型类型和目录构建 sherpa-onnx 配置。
sherpa.OfflineRecognizerConfig _buildConfig({
  required String modelDir,
  required AsrModelType modelType,
  required String modelId,
  required int numThreads,
  String? provider,
}) {
  final p = provider ?? _platformProvider();
  switch (modelType) {
    case AsrModelType.moonshine:
      return _buildMoonshineConfig(
        modelDir: modelDir,
        numThreads: numThreads,
        provider: p,
      );
    case AsrModelType.whisper:
      return _buildWhisperConfig(
        modelDir: modelDir,
        modelId: modelId,
        numThreads: numThreads,
        provider: p,
      );
  }
}

/// 构建 Moonshine 模型配置。
sherpa.OfflineRecognizerConfig _buildMoonshineConfig({
  required String modelDir,
  required int numThreads,
  required String provider,
}) {
  final moonshine = sherpa.OfflineMoonshineModelConfig(
    preprocessor: p.join(modelDir, 'preprocess.onnx'),
    encoder: p.join(modelDir, 'encode.int8.onnx'),
    uncachedDecoder: p.join(modelDir, 'uncached_decode.int8.onnx'),
    cachedDecoder: p.join(modelDir, 'cached_decode.int8.onnx'),
  );

  final model = sherpa.OfflineModelConfig(
    moonshine: moonshine,
    tokens: p.join(modelDir, 'tokens.txt'),
    numThreads: numThreads,
    debug: false,
    provider: provider,
  );

  return sherpa.OfflineRecognizerConfig(model: model);
}

/// 构建 Whisper 模型配置。
sherpa.OfflineRecognizerConfig _buildWhisperConfig({
  required String modelDir,
  required String modelId,
  required int numThreads,
  required String provider,
}) {
  final prefix = _whisperFilePrefix(modelId);

  final whisper = sherpa.OfflineWhisperModelConfig(
    encoder: p.join(modelDir, '$prefix-encoder.int8.onnx'),
    decoder: p.join(modelDir, '$prefix-decoder.int8.onnx'),
    language: 'en',
    task: 'transcribe',
  );

  final model = sherpa.OfflineModelConfig(
    whisper: whisper,
    tokens: p.join(modelDir, '$prefix-tokens.txt'),
    modelType: 'whisper',
    numThreads: numThreads,
    debug: false,
    provider: provider,
  );

  return sherpa.OfflineRecognizerConfig(model: model);
}

/// 从 modelId 提取 Whisper 文件名前缀。
String _whisperFilePrefix(String modelId) {
  if (modelId.contains('tiny')) return 'tiny.en';
  if (modelId.contains('base')) return 'base.en';
  if (modelId.contains('small')) return 'small.en';
  throw ArgumentError('Unknown Whisper model: $modelId');
}
