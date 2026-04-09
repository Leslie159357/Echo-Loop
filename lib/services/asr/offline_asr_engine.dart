/// 离线 ASR 引擎统一接口和数据类。
///
/// 定义 [OfflineAsrEngine] 抽象接口，sherpa-onnx（Moonshine/Whisper ONNX）
/// 和 whisper.cpp（Whisper GGML）都实现此接口，上层不感知具体引擎差异。
library;

/// ASR 模型类型。
enum AsrModelType {
  /// Moonshine 系列（Useful Sensors），ONNX 格式，sherpa-onnx 加载。
  moonshine,

  /// Whisper 系列（OpenAI），ONNX 格式，sherpa-onnx 加载。
  whisper,
}

/// ASR 模型信息。
class AsrModelInfo {
  /// 模型唯一标识，如 "moonshine-tiny-en-int8"。
  final String id;

  /// 显示名称，如 "Moonshine Tiny"。
  final String displayName;

  /// 模型类型。
  final AsrModelType type;

  /// 模型文件总大小（字节），用于 UI 展示。
  final int fileSizeBytes;

  const AsrModelInfo({
    required this.id,
    required this.displayName,
    required this.type,
    required this.fileSizeBytes,
  });
}

/// ASR 模型配置（用于初始化引擎）。
class AsrModelConfig {
  /// 模型信息。
  final AsrModelInfo model;

  /// 模型文件本地目录路径。
  final String modelDir;

  /// 推理线程数。
  final int numThreads;

  /// 推理加速 provider（仅 sherpa-onnx 使用）。
  ///
  /// null 时自动选择平台默认值（Android: nnapi, 其他: cpu）。
  final String? provider;

  const AsrModelConfig({
    required this.model,
    required this.modelDir,
    this.numThreads = 4,
    this.provider,
  });
}

/// ASR 转录结果。
class AsrResult {
  /// 转录文本。
  final String text;

  /// 推理耗时。
  final Duration inferenceTime;

  const AsrResult({required this.text, required this.inferenceTime});
}

/// 离线 ASR 引擎抽象接口。
///
/// 统一 Moonshine、Whisper 等模型的转录能力，
/// 由 [SherpaOnnxEngine] 实现。
abstract class OfflineAsrEngine {
  /// 引擎显示名称。
  String get name;

  /// 是否已初始化（模型已加载到内存）。
  bool get isReady;

  /// 当前加载的模型信息，未初始化时为 null。
  AsrModelInfo? get currentModel;

  /// 加载指定模型，初始化推理引擎。
  ///
  /// 如果已加载其他模型，会先释放再重新加载。
  Future<void> initialize(AsrModelConfig config);

  /// 转录 WAV 文件（16kHz/mono/PCM16），返回结果。
  ///
  /// 在后台执行推理，不阻塞 UI 线程。
  /// 引擎未初始化时抛出 [StateError]。
  Future<AsrResult> transcribe(String wavPath);

  /// 释放模型和引擎资源。
  Future<void> dispose();
}
