/// ASR 模型发布规格目录。
///
/// 模型 CDN 路径、归档摘要、预计流量和解压后关键文件只在本文件维护；
/// 下载与安装行为由 ASR 专属归档安装器负责。
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
    sha256: 'b35097783b5bd8c7403d8146a3ebd3c2c0fe16935cdabed12b8b09ee1eef97f0',
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
    sha256: '2599a592259c6332ee17492caf4e4f39692364efcee0d61318596ede238b2755',
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
    sha256: 'aa01d2f60d36a9d1aa806fd0cfffbfdabed25d64966faa960a82cb9f05b3a99c',
    estimatedDownloadBytes: 232673926,
    requiredFiles: [
      'small-encoder.int8.onnx',
      'small-decoder.int8.onnx',
      'small-tokens.txt',
    ],
    dependencies: [vadModelId],
  ),
};
