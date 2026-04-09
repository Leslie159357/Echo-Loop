/// 音频文件读取工具，支持 WAV（RIFF）和 CAF（Core Audio Format）。
///
/// 用于将录音文件解析为 sherpa-onnx 可接受的 Float32 PCM 数据。
/// Android 录音输出 WAV（16kHz/mono/PCM16），
/// macOS/iOS 录音输出 CAF（48kHz/mono/Float32 或 PCM16）。
library;

import 'dart:io';
import 'dart:typed_data';

/// 解析后的音频数据。
class AudioData {
  /// 归一化到 [-1, 1] 的单声道 PCM 样本。
  final Float32List samples;

  /// 采样率（Hz）。
  final int sampleRate;

  const AudioData({required this.samples, required this.sampleRate});

  /// 空音频数据。
  static final empty = AudioData(samples: Float32List(0), sampleRate: 0);
}

/// 读取音频文件，支持 WAV（RIFF）和 CAF（caff）格式。
///
/// 返回归一化到 [-1, 1] 的 Float32List 单声道 PCM 样本。
/// 不支持的格式抛出 [FormatException]。
AudioData readAudioFile(String path) {
  final bytes = File(path).readAsBytesSync();
  if (bytes.length < 12) return AudioData.empty;

  final data = ByteData.sublistView(bytes);

  // 检查文件头判断格式。
  final magic = String.fromCharCodes(bytes.sublist(0, 4));
  if (magic == 'RIFF') return readWav(data);
  if (magic == 'caff') return readCaf(data);

  throw FormatException('Unsupported audio format: $magic');
}

/// 解析 WAV 文件（RIFF/WAVE，PCM 16-bit Little-Endian）。
AudioData readWav(ByteData data) {
  // 跳过 RIFF header (12 bytes)。
  var offset = 12;
  int sampleRate = 16000;
  int numChannels = 1;

  // 遍历 chunks。
  while (offset + 8 <= data.lengthInBytes) {
    final chunkId = String.fromCharCodes(
      data.buffer.asUint8List(data.offsetInBytes + offset, 4),
    );
    final chunkSize = data.getUint32(offset + 4, Endian.little);
    offset += 8;

    if (chunkId == 'fmt ') {
      numChannels = data.getUint16(offset + 2, Endian.little);
      sampleRate = data.getUint32(offset + 4, Endian.little);
    } else if (chunkId == 'data') {
      final pcmBytes = data.buffer.asUint8List(
        data.offsetInBytes + offset,
        chunkSize,
      );
      return AudioData(
        samples: pcm16ToFloat32(pcmBytes, Endian.little, numChannels),
        sampleRate: sampleRate,
      );
    }

    offset += chunkSize;
    // Chunks are word-aligned。
    if (chunkSize.isOdd) offset++;
  }

  return AudioData.empty;
}

/// 解析 CAF 文件（Core Audio Format）。
///
/// macOS/iOS 的 AVAudioEngine 录音默认输出 CAF + Linear PCM。
/// 支持 Float32 和 Int16 两种 PCM 格式。
AudioData readCaf(ByteData data) {
  // CAF header: "caff" (4) + version (2) + flags (2) = 8 bytes。
  var offset = 8;
  int sampleRate = 16000;
  int numChannels = 1;
  int bitsPerChannel = 16;
  var isFloat = false;
  var isLittleEndian = false;

  while (offset + 12 <= data.lengthInBytes) {
    final chunkType = String.fromCharCodes(
      data.buffer.asUint8List(data.offsetInBytes + offset, 4),
    );
    // CAF chunk size 是 Int64 Big-Endian。
    // data chunk 可能使用 -1 哨兵表示"到文件末尾"。
    final chunkSize = data.getInt64(offset + 4, Endian.big);
    offset += 12;

    if (chunkType == 'desc') {
      // Audio Description chunk (CAF spec):
      // Float64 sampleRate, 4 bytes formatID, UInt32 formatFlags,
      // UInt32 bytesPerPacket, UInt32 framesPerPacket,
      // UInt32 channelsPerFrame, UInt32 bitsPerChannel
      final srBits = data.getUint64(offset, Endian.big);
      sampleRate = float64FromBits(srBits).round();

      final formatFlags = data.getUint32(offset + 12, Endian.big);
      numChannels = data.getUint32(offset + 24, Endian.big);
      bitsPerChannel = data.getUint32(offset + 28, Endian.big);

      // kCAFLinearPCMFormatFlagIsFloat = 0x1
      isFloat = (formatFlags & 0x1) != 0;
      // kCAFLinearPCMFormatFlagIsLittleEndian = 0x2
      isLittleEndian = (formatFlags & 0x2) != 0;
    } else if (chunkType == 'data') {
      // data chunk 的前 4 字节是 editCount（跳过）。
      final pcmOffset = offset + 4;
      final pcmSize = chunkSize == -1
          ? data.lengthInBytes - pcmOffset
          : chunkSize - 4;

      if (pcmSize <= 0) return AudioData.empty;

      final pcmBytes = data.buffer.asUint8List(
        data.offsetInBytes + pcmOffset,
        pcmSize,
      );
      final endian = isLittleEndian ? Endian.little : Endian.big;

      final Float32List samples;
      if (isFloat && bitsPerChannel == 32) {
        samples = float32PcmToMono(pcmBytes, endian, numChannels);
      } else {
        samples = pcm16ToFloat32(pcmBytes, endian, numChannels);
      }

      return AudioData(samples: samples, sampleRate: sampleRate);
    }

    if (chunkSize > 0) {
      offset += chunkSize;
    } else {
      // chunkSize == -1 表示到文件末尾（data chunk 专用）。
      break;
    }
  }

  return AudioData.empty;
}

/// 将 Float32 PCM 字节数组提取为单声道 Float32List。
Float32List float32PcmToMono(Uint8List bytes, Endian endian, int numChannels) {
  final byteData = ByteData.sublistView(bytes);
  final totalSamples = bytes.length ~/ 4;
  final frameSamples = totalSamples ~/ numChannels;
  final result = Float32List(frameSamples);
  final step = numChannels * 4;

  for (var i = 0; i < frameSamples; i++) {
    result[i] = byteData.getFloat32(i * step, endian);
  }

  return result;
}

/// 将 PCM 16-bit 字节数组转为归一化 [-1, 1] 的 Float32List。
Float32List pcm16ToFloat32(Uint8List bytes, Endian endian, int numChannels) {
  final byteData = ByteData.sublistView(bytes);
  final totalSamples = bytes.length ~/ 2;
  final frameSamples = totalSamples ~/ numChannels;
  final result = Float32List(frameSamples);
  final step = numChannels * 2;

  for (var i = 0; i < frameSamples; i++) {
    final sample = byteData.getInt16(i * step, endian);
    result[i] = sample / 32768.0;
  }

  return result;
}

/// 从 IEEE 754 64-bit 位模式还原 double。
double float64FromBits(int bits) {
  final bd = ByteData(8)..setUint64(0, bits, Endian.big);
  return bd.getFloat64(0, Endian.big);
}
