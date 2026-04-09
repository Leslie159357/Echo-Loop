/// ASR 模型下载、校验、缓存管理。
///
/// 负责从远程下载模型文件到本地，校验完整性，
/// 管理缓存目录。不依赖具体引擎实现。
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'offline_asr_engine.dart';

// ---------------------------------------------------------------------------
// 模型注册表
// ---------------------------------------------------------------------------

/// HuggingFace 镜像基础 URL（大陆可用）。
const _hfMirrorBase = 'https://hf-mirror.com';

/// HuggingFace 官方基础 URL。
const _hfOfficialBase = 'https://huggingface.co';

/// 模型文件清单：每个模型需要下载的文件列表。
class _ModelFiles {
  final String hfRepo;
  final List<String> files;
  const _ModelFiles({required this.hfRepo, required this.files});
}

/// 各模型对应的 HuggingFace 仓库和文件清单。
const _modelFileRegistry = <String, _ModelFiles>{
  'moonshine-tiny-en-int8': _ModelFiles(
    hfRepo: 'csukuangfj/sherpa-onnx-moonshine-tiny-en-int8',
    files: [
      'preprocess.onnx',
      'encode.int8.onnx',
      'uncached_decode.int8.onnx',
      'cached_decode.int8.onnx',
      'tokens.txt',
    ],
  ),
  'moonshine-base-en-int8': _ModelFiles(
    hfRepo: 'csukuangfj/sherpa-onnx-moonshine-base-en-int8',
    files: [
      'preprocess.onnx',
      'encode.int8.onnx',
      'uncached_decode.int8.onnx',
      'cached_decode.int8.onnx',
      'tokens.txt',
    ],
  ),
  'whisper-tiny-en-int8': _ModelFiles(
    hfRepo: 'csukuangfj/sherpa-onnx-whisper-tiny.en',
    files: [
      'tiny.en-encoder.int8.onnx',
      'tiny.en-decoder.int8.onnx',
      'tiny.en-tokens.txt',
    ],
  ),
  'whisper-base-en-int8': _ModelFiles(
    hfRepo: 'csukuangfj/sherpa-onnx-whisper-base.en',
    files: [
      'base.en-encoder.int8.onnx',
      'base.en-decoder.int8.onnx',
      'base.en-tokens.txt',
    ],
  ),
  'whisper-small-en-int8': _ModelFiles(
    hfRepo: 'csukuangfj/sherpa-onnx-whisper-small.en',
    files: [
      'small.en-encoder.int8.onnx',
      'small.en-decoder.int8.onnx',
      'small.en-tokens.txt',
    ],
  ),
};

/// 所有可用模型的元信息。
final List<AsrModelInfo> availableModels = [
  const AsrModelInfo(
    id: 'moonshine-tiny-en-int8',
    displayName: 'Moonshine Tiny',
    type: AsrModelType.moonshine,
    fileSizeBytes: 124 * 1024 * 1024, // ~124 MB
  ),
  const AsrModelInfo(
    id: 'moonshine-base-en-int8',
    displayName: 'Moonshine Base',
    type: AsrModelType.moonshine,
    fileSizeBytes: 250 * 1024 * 1024, // ~250 MB
  ),
  const AsrModelInfo(
    id: 'whisper-tiny-en-int8',
    displayName: 'Whisper Tiny.en',
    type: AsrModelType.whisper,
    fileSizeBytes: 104 * 1024 * 1024, // ~104 MB
  ),
  const AsrModelInfo(
    id: 'whisper-base-en-int8',
    displayName: 'Whisper Base.en',
    type: AsrModelType.whisper,
    fileSizeBytes: 209 * 1024 * 1024, // ~209 MB
  ),
  const AsrModelInfo(
    id: 'whisper-small-en-int8',
    displayName: 'Whisper Small.en',
    type: AsrModelType.whisper,
    fileSizeBytes: 636 * 1024 * 1024, // ~636 MB
  ),
];

// ---------------------------------------------------------------------------
// 模型下载状态
// ---------------------------------------------------------------------------

/// 模型下载状态。
enum AsrModelDownloadStatus {
  /// 未下载。
  notDownloaded,

  /// 下载中。
  downloading,

  /// 已下载。
  downloaded,

  /// 下载失败。
  failed,
}

/// 模型下载进度。
class AsrModelDownloadProgress {
  /// 下载状态。
  final AsrModelDownloadStatus status;

  /// 下载进度 0.0 ~ 1.0。
  final double progress;

  /// 已下载字节数。
  final int downloadedBytes;

  /// 总字节数。
  final int totalBytes;

  /// 错误信息（仅 [AsrModelDownloadStatus.failed] 时有值）。
  final String? error;

  const AsrModelDownloadProgress({
    required this.status,
    this.progress = 0,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.error,
  });

  /// 未下载的初始状态。
  static const notDownloaded = AsrModelDownloadProgress(
    status: AsrModelDownloadStatus.notDownloaded,
  );
}

// ---------------------------------------------------------------------------
// AsrModelManager
// ---------------------------------------------------------------------------

/// ASR 模型管理器。
///
/// 职责：模型下载、本地缓存管理、完整性校验、设备推荐。
class AsrModelManager {
  final Dio _dio;

  /// 是否使用 HuggingFace 镜像（大陆优先）。
  final bool useMirror;

  AsrModelManager({Dio? dio, this.useMirror = true}) : _dio = dio ?? Dio();

  /// 模型存储根目录。
  Future<String> get _modelsRoot async {
    final appDir = await getApplicationSupportDirectory();
    return p.join(appDir.path, 'asr-models');
  }

  /// 获取指定模型的本地目录路径。
  Future<String> modelDir(String modelId) async {
    final root = await _modelsRoot;
    return p.join(root, modelId);
  }

  /// 检查模型是否已下载且完整。
  Future<bool> isModelDownloaded(String modelId) async {
    final files = _modelFileRegistry[modelId];
    if (files == null) return false;

    final dir = await modelDir(modelId);
    for (final file in files.files) {
      if (!File(p.join(dir, file)).existsSync()) return false;
    }
    return true;
  }

  /// 获取模型本地占用空间（字节）。
  Future<int> modelLocalSize(String modelId) async {
    final dir = Directory(await modelDir(modelId));
    if (!dir.existsSync()) return 0;

    var total = 0;
    await for (final entity in dir.list()) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }

  /// 下载模型，通过 [onProgress] 回调报告进度。
  ///
  /// 下载过程中可通过 [cancelToken] 取消。
  /// 返回模型本地目录路径。
  Future<String> downloadModel(
    String modelId, {
    void Function(AsrModelDownloadProgress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final modelFiles = _modelFileRegistry[modelId];
    if (modelFiles == null) {
      throw ArgumentError('Unknown model: $modelId');
    }

    final dir = await modelDir(modelId);
    await Directory(dir).create(recursive: true);

    final baseUrl = useMirror ? _hfMirrorBase : _hfOfficialBase;
    final repoUrl = '$baseUrl/${modelFiles.hfRepo}/resolve/main';

    // 先获取所有文件的大小。
    var totalBytes = 0;
    final fileSizes = <String, int>{};
    for (final file in modelFiles.files) {
      final localFile = File(p.join(dir, file));
      if (localFile.existsSync()) {
        // 已存在的文件跳过下载，但计入总进度。
        final size = localFile.lengthSync();
        fileSizes[file] = size;
        totalBytes += size;
      } else {
        // 用 HEAD 请求获取文件大小。
        try {
          final response = await _dio.head<void>(
            '$repoUrl/$file',
            cancelToken: cancelToken,
          );
          final size =
              int.tryParse('${response.headers.value('content-length')}') ?? 0;
          fileSizes[file] = size;
          totalBytes += size;
        } on DioException {
          // HEAD 失败时用预估大小。
          fileSizes[file] = 0;
        }
      }
    }

    var downloadedBytes = 0;

    // 已存在的文件直接计入进度。
    for (final file in modelFiles.files) {
      final localFile = File(p.join(dir, file));
      if (localFile.existsSync()) {
        downloadedBytes += localFile.lengthSync();
      }
    }

    void reportProgress() {
      onProgress?.call(
        AsrModelDownloadProgress(
          status: AsrModelDownloadStatus.downloading,
          progress: totalBytes > 0 ? downloadedBytes / totalBytes : 0,
          downloadedBytes: downloadedBytes,
          totalBytes: totalBytes,
        ),
      );
    }

    reportProgress();

    // 逐个下载缺失的文件。
    for (final file in modelFiles.files) {
      final localFile = File(p.join(dir, file));
      if (localFile.existsSync()) continue;

      final tempFile = File('${localFile.path}.tmp');
      try {
        await _dio.download(
          '$repoUrl/$file',
          tempFile.path,
          cancelToken: cancelToken,
          onReceiveProgress: (received, total) {
            onProgress?.call(
              AsrModelDownloadProgress(
                status: AsrModelDownloadStatus.downloading,
                progress: totalBytes > 0
                    ? (downloadedBytes + received) / totalBytes
                    : 0,
                downloadedBytes: downloadedBytes + received,
                totalBytes: totalBytes,
              ),
            );
          },
        );
        await tempFile.rename(localFile.path);
        downloadedBytes += fileSizes[file] ?? 0;
      } catch (e) {
        // 清理临时文件。
        if (tempFile.existsSync()) {
          await tempFile.delete();
        }
        rethrow;
      }
    }

    onProgress?.call(
      AsrModelDownloadProgress(
        status: AsrModelDownloadStatus.downloaded,
        progress: 1.0,
        downloadedBytes: totalBytes,
        totalBytes: totalBytes,
      ),
    );

    return dir;
  }

  /// 删除本地模型缓存。
  Future<void> deleteModel(String modelId) async {
    final dir = Directory(await modelDir(modelId));
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
    }
  }

  /// 根据设备性能推荐模型。
  ///
  /// 基于 CPU 核心数和可用内存做简单启发式判断。
  AsrModelInfo recommendModel() {
    final cores = Platform.numberOfProcessors;
    // 简单启发式：核心数反映设备档次。
    if (cores >= 8) {
      return availableModels.firstWhere((m) => m.id == 'whisper-base-en-int8');
    }
    if (cores >= 6) {
      return availableModels.firstWhere(
        (m) => m.id == 'moonshine-base-en-int8',
      );
    }
    return availableModels.firstWhere((m) => m.id == 'moonshine-tiny-en-int8');
  }

  /// 释放资源。
  void dispose() {
    _dio.close();
  }
}
