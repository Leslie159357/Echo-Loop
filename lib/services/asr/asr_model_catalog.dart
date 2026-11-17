/// ASR 模型发布规格目录。
///
/// 静态资源 CDN 路径、归档摘要、预计流量和解压后关键文件只在本文件维护；
/// 下载与安装行为由 ASR 专属归档安装器负责。
///
/// 注意：三个 Whisper 归档的内容是 sherpa-onnx 的**多语种** int8 模型
/// （k2-fsa/sherpa-onnx asr-models 的 sherpa-onnx-whisper-{tiny,base,small}，
/// 非 `.en` 专用版），id 里的 `-en-` 是历史命名，不代表模型只能识别英文。
/// 引擎以 `language: 'de'` 调用，德语识别依赖的正是多语种权重。
library;

/// 所有 Whisper 模型共享的 VAD 资源 ID。
const vadModelId = 'silero-vad';

class AsrModelResourceSpec {
  const AsrModelResourceSpec({
    required this.id,
    required this.archivePath,
    required this.sha256,
    required this.estimatedDownloadBytes,
    required this.requiredFiles,
    this.dependencies = const [],
  });

  final String id;
  final String archivePath;
  final String sha256;
  final int estimatedDownloadBytes;
  final List<String> requiredFiles;
  final List<String> dependencies;
}

const asrModelResourceCatalog = <String, AsrModelResourceSpec>{
  vadModelId: AsrModelResourceSpec(
    id: vadModelId,
    archivePath: 'asr/silero-vad-v1.zip',
    sha256: 'e7ae67c1610b5ef8d1f00d2e0e42e833ced8d3bc22f8e59a809d36616028f5e2',
    estimatedDownloadBytes: 508294,
    requiredFiles: ['silero_vad.onnx'],
  ),
  'whisper-tiny-en-int8': AsrModelResourceSpec(
    id: 'whisper-tiny-en-int8',
    archivePath: 'asr/whisper-tiny-int8-v1.zip',
    sha256: 'f3db44cf505de830522d3e0453ebd14c82ee8676a5e235a31f2f88a5edf20a6e',
    estimatedDownloadBytes: 60745245,
    requiredFiles: [
      'tiny-encoder.int8.onnx',
      'tiny-decoder.int8.onnx',
      'tiny-tokens.txt',
    ],
    dependencies: [vadModelId],
  ),
  'whisper-base-en-int8': AsrModelResourceSpec(
    id: 'whisper-base-en-int8',
    archivePath: 'asr/whisper-base-int8-v1.zip',
    sha256: 'ce4a9956456cca43b6013e050cc04c0cd16a55373bf39cb11154dc24c3df7a47',
    estimatedDownloadBytes: 94464537,
    requiredFiles: [
      'base-encoder.int8.onnx',
      'base-decoder.int8.onnx',
      'base-tokens.txt',
    ],
    dependencies: [vadModelId],
  ),
  'whisper-small-en-int8': AsrModelResourceSpec(
    id: 'whisper-small-en-int8',
    archivePath: 'asr/whisper-small-int8-v1.zip',
    sha256: '7b32cbab610bb221834c1b0ff0892f9889fab1718b6fe35fa9561a5f9dbe2c51',
    estimatedDownloadBytes: 232673926,
    requiredFiles: [
      'small-encoder.int8.onnx',
      'small-decoder.int8.onnx',
      'small-tokens.txt',
    ],
    dependencies: [vadModelId],
  ),
};
