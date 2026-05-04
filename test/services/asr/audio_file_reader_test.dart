import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:echo_loop/services/asr/audio_file_reader.dart';

void main() {
  group('readAudioFile', () {
    test('正确读取 WAV 文件', () {
      final path = _fixturePath('8k.wav');
      final result = readAudioFile(path);

      // 8k.wav: 8000Hz, mono, 16-bit PCM
      expect(result.sampleRate, 8000);
      expect(result.samples.isNotEmpty, isTrue);
      // ~4.8s at 8000Hz ≈ 38600 samples
      expect(result.samples.length, greaterThan(30000));
      expect(result.samples.length, lessThan(50000));
    });

    test('WAV 样本值在 [-1, 1] 范围内', () {
      final result = readAudioFile(_fixturePath('8k.wav'));

      for (var i = 0; i < result.samples.length; i++) {
        expect(
          result.samples[i],
          inInclusiveRange(-1.0, 1.0),
          reason: 'sample[$i] = ${result.samples[i]} out of range',
        );
      }
    });

    test('WAV 包含非零音频数据', () {
      final result = readAudioFile(_fixturePath('8k.wav'));

      // 至少有一些样本绝对值 > 0.01（不是静音）。
      final hasAudio = result.samples.any((s) => s.abs() > 0.01);
      expect(hasAudio, isTrue, reason: 'audio should not be silent');
    });

    test('文件过短返回空数据', () {
      final tempFile = File('${Directory.systemTemp.path}/tiny.wav')
        ..writeAsBytesSync([0, 1, 2]);

      addTearDown(() => tempFile.deleteSync());

      final result = readAudioFile(tempFile.path);
      expect(result.samples.isEmpty, isTrue);
      expect(result.sampleRate, 0);
    });

    test('不支持的格式抛出 FormatException', () {
      final tempFile = File('${Directory.systemTemp.path}/bad.bin')
        ..writeAsBytesSync(List.filled(100, 0x42));

      addTearDown(() => tempFile.deleteSync());

      expect(
        () => readAudioFile(tempFile.path),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('pcm16ToFloat32', () {
    test('正确转换 16-bit PCM little-endian', () {
      // 0x7FFF = 32767 → 32767/32768 ≈ 0.99997
      // 0x8001 = -32767 → -32767/32768 ≈ -0.99997
      // 0x0000 = 0 → 0.0
      final bytes = Uint8List.fromList([
        0xFF, 0x7F, // 32767 (little-endian)
        0x01, 0x80, // -32767 (little-endian)
        0x00, 0x00, // 0
      ]);

      final result = pcm16ToFloat32(bytes, Endian.little, 1);

      expect(result.length, 3);
      expect(result[0], closeTo(32767 / 32768, 0.0001));
      expect(result[1], closeTo(-32767 / 32768, 0.0001));
      expect(result[2], 0.0);
    });

    test('多声道只取第一声道', () {
      // stereo: L=100 R=200, L=300 R=400
      final bytes = Uint8List.fromList([
        100, 0, // L=100
        200, 0, // R=200 (skipped)
        44, 1, // L=300
        144, 1, // R=400 (skipped)
      ]);

      final result = pcm16ToFloat32(bytes, Endian.little, 2);

      expect(result.length, 2);
      expect(result[0], closeTo(100 / 32768, 0.0001));
      expect(result[1], closeTo(300 / 32768, 0.0001));
    });
  });

  group('float32PcmToMono', () {
    test('正确读取 float32 样本', () {
      final bd = ByteData(12);
      bd.setFloat32(0, 0.5, Endian.little);
      bd.setFloat32(4, -0.25, Endian.little);
      bd.setFloat32(8, 0.0, Endian.little);

      final result = float32PcmToMono(
        bd.buffer.asUint8List(),
        Endian.little,
        1,
      );

      expect(result.length, 3);
      expect(result[0], closeTo(0.5, 0.0001));
      expect(result[1], closeTo(-0.25, 0.0001));
      expect(result[2], 0.0);
    });
  });

  group('readWav', () {
    test('解析最小有效 WAV', () {
      final wav = _buildMinimalWav(
        sampleRate: 16000,
        numChannels: 1,
        samples: [0x0100], // 256 as int16 LE
      );

      final result = readWav(ByteData.sublistView(wav));

      expect(result.sampleRate, 16000);
      expect(result.samples.length, 1);
      expect(result.samples[0], closeTo(256 / 32768, 0.001));
    });
  });

  group('readCaf', () {
    test('解析 Float32 LE 格式 CAF', () {
      final caf = _buildMinimalCaf(
        sampleRate: 48000,
        numChannels: 1,
        bitsPerChannel: 32,
        isFloat: true,
        isLittleEndian: true,
        float32Samples: [0.5, -0.25, 0.0],
      );

      final result = readCaf(ByteData.sublistView(caf));

      expect(result.sampleRate, 48000);
      expect(result.samples.length, 3);
      expect(result.samples[0], closeTo(0.5, 0.0001));
      expect(result.samples[1], closeTo(-0.25, 0.0001));
      expect(result.samples[2], 0.0);
    });

    test('解析 Int16 BE 格式 CAF', () {
      final caf = _buildMinimalCaf(
        sampleRate: 16000,
        numChannels: 1,
        bitsPerChannel: 16,
        isFloat: false,
        isLittleEndian: false,
        int16Samples: [1000, -1000, 0],
      );

      final result = readCaf(ByteData.sublistView(caf));

      expect(result.sampleRate, 16000);
      expect(result.samples.length, 3);
      expect(result.samples[0], closeTo(1000 / 32768, 0.001));
      expect(result.samples[1], closeTo(-1000 / 32768, 0.001));
      expect(result.samples[2], 0.0);
    });

    test('data chunk size 为 -1 时读到文件末尾', () {
      final caf = _buildMinimalCaf(
        sampleRate: 16000,
        numChannels: 1,
        bitsPerChannel: 16,
        isFloat: false,
        isLittleEndian: false,
        int16Samples: [500, 600],
        dataChunkSizeSentinel: true, // 使用 -1 哨兵
      );

      final result = readCaf(ByteData.sublistView(caf));

      expect(result.sampleRate, 16000);
      expect(result.samples.length, 2);
      expect(result.samples[0], closeTo(500 / 32768, 0.001));
    });
  });

  group('downsample', () {
    test('48kHz → 16kHz（3:1）均值降采样', () {
      // 3 组各 3 个样本，均值分别为 0.3, -0.6, 0.0
      final input = Float32List.fromList([
        0.1, 0.3, 0.5, // avg = 0.3
        -0.4, -0.6, -0.8, // avg = -0.6
        -0.1, 0.0, 0.1, // avg = 0.0
      ]);

      final result = downsample(input, 48000, 16000);

      expect(result.length, 3);
      expect(result[0], closeTo(0.3, 0.0001));
      expect(result[1], closeTo(-0.6, 0.0001));
      expect(result[2], closeTo(0.0, 0.0001));
    });

    test('振幅保持在合理范围', () {
      // 模拟真实语音信号（振幅 ~0.1）
      final input = Float32List(48000); // 1 秒 48kHz
      for (var i = 0; i < input.length; i++) {
        input[i] = 0.1 * (i.isEven ? 1.0 : -1.0);
      }

      final result = downsample(input, 48000, 16000);

      expect(result.length, 16000);
      for (final sample in result) {
        expect(sample.abs(), lessThanOrEqualTo(0.15));
      }
      expect(result.any((s) => s.abs() > 0.01), isTrue);
    });

    test('余尾样本被截断', () {
      // 10 个样本，ratio=3 → 输出 3 个，第 10 个被丢弃
      final input = Float32List.fromList([
        0.1, 0.2, 0.3,
        0.4, 0.5, 0.6,
        0.7, 0.8, 0.9,
        1.0, // 尾部不足一组，截断
      ]);

      final result = downsample(input, 48000, 16000);

      expect(result.length, 3);
    });

    test('对 CAF 48kHz Float32 降采样后保持非零', () {
      final caf = _buildMinimalCaf(
        sampleRate: 48000,
        numChannels: 1,
        bitsPerChannel: 32,
        isFloat: true,
        isLittleEndian: true,
        float32Samples: [
          // 模拟 3 帧 × 3 样本 = 9 个 48kHz 样本
          0.5, 0.5, 0.5,
          -0.3, -0.3, -0.3,
          0.1, 0.1, 0.1,
        ],
      );

      final audio = readCaf(ByteData.sublistView(caf));
      expect(audio.sampleRate, 48000);

      final result = downsample(audio.samples, 48000, 16000);

      expect(result.length, 3);
      expect(result[0], closeTo(0.5, 0.0001));
      expect(result[1], closeTo(-0.3, 0.0001));
      expect(result[2], closeTo(0.1, 0.0001));
    });
  });
}

/// 构造最小有效 CAF 文件。
Uint8List _buildMinimalCaf({
  required int sampleRate,
  required int numChannels,
  required int bitsPerChannel,
  required bool isFloat,
  required bool isLittleEndian,
  List<double>? float32Samples,
  List<int>? int16Samples,
  bool dataChunkSizeSentinel = false,
}) {
  final bytesPerSample = bitsPerChannel ~/ 8;
  final sampleCount = float32Samples?.length ?? int16Samples?.length ?? 0;
  final pcmSize = sampleCount * bytesPerSample * numChannels;

  // CAF: header(8) + desc chunk(12+32) + data chunk(12+4+pcm)
  final totalSize = 8 + 44 + 16 + pcmSize;
  final bd = ByteData(totalSize);
  var offset = 0;

  // CAF header: "caff" + version(1) + flags(0)
  for (final c in 'caff'.codeUnits) {
    bd.setUint8(offset++, c);
  }
  bd.setUint16(offset, 1, Endian.big); // version
  offset += 2;
  bd.setUint16(offset, 0, Endian.big); // flags
  offset += 2;

  // desc chunk: type(4) + size(8) + body(32)
  for (final c in 'desc'.codeUnits) {
    bd.setUint8(offset++, c);
  }
  bd.setInt64(offset, 32, Endian.big); // chunk size
  offset += 8;

  // desc body: Float64 sampleRate
  bd.setFloat64(offset, sampleRate.toDouble(), Endian.big);
  offset += 8;
  // formatID: 'lpcm'
  for (final c in 'lpcm'.codeUnits) {
    bd.setUint8(offset++, c);
  }
  // formatFlags
  var flags = 0;
  if (isFloat) flags |= 0x1;
  if (isLittleEndian) flags |= 0x2;
  bd.setUint32(offset, flags, Endian.big);
  offset += 4;
  // bytesPerPacket
  bd.setUint32(offset, bytesPerSample * numChannels, Endian.big);
  offset += 4;
  // framesPerPacket
  bd.setUint32(offset, 1, Endian.big);
  offset += 4;
  // channelsPerFrame
  bd.setUint32(offset, numChannels, Endian.big);
  offset += 4;
  // bitsPerChannel
  bd.setUint32(offset, bitsPerChannel, Endian.big);
  offset += 4;

  // data chunk: type(4) + size(8) + editCount(4) + pcm
  for (final c in 'data'.codeUnits) {
    bd.setUint8(offset++, c);
  }
  if (dataChunkSizeSentinel) {
    bd.setInt64(offset, -1, Endian.big); // -1 哨兵
  } else {
    bd.setInt64(offset, pcmSize + 4, Endian.big); // 含 editCount
  }
  offset += 8;
  // editCount
  bd.setUint32(offset, 0, Endian.big);
  offset += 4;

  // PCM data
  final endian = isLittleEndian ? Endian.little : Endian.big;
  if (isFloat && float32Samples != null) {
    for (final s in float32Samples) {
      bd.setFloat32(offset, s, endian);
      offset += 4;
    }
  } else if (int16Samples != null) {
    for (final s in int16Samples) {
      bd.setInt16(offset, s, endian);
      offset += 2;
    }
  }

  return bd.buffer.asUint8List(0, totalSize);
}

/// 获取测试固件文件路径。
String _fixturePath(String filename) {
  // flutter test 的工作目录是项目根目录。
  return 'test/fixtures/$filename';
}

/// 构造最小有效 WAV 文件。
Uint8List _buildMinimalWav({
  required int sampleRate,
  required int numChannels,
  required List<int> samples,
}) {
  final dataSize = samples.length * 2;
  final fileSize = 36 + dataSize;
  final byteRate = sampleRate * numChannels * 2;
  final blockAlign = numChannels * 2;

  final bd = ByteData(44 + dataSize);
  var offset = 0;

  // RIFF header
  for (final c in 'RIFF'.codeUnits) {
    bd.setUint8(offset++, c);
  }
  bd.setUint32(offset, fileSize, Endian.little);
  offset += 4;
  for (final c in 'WAVE'.codeUnits) {
    bd.setUint8(offset++, c);
  }

  // fmt chunk
  for (final c in 'fmt '.codeUnits) {
    bd.setUint8(offset++, c);
  }
  bd.setUint32(offset, 16, Endian.little);
  offset += 4;
  bd.setUint16(offset, 1, Endian.little); // PCM format
  offset += 2;
  bd.setUint16(offset, numChannels, Endian.little);
  offset += 2;
  bd.setUint32(offset, sampleRate, Endian.little);
  offset += 4;
  bd.setUint32(offset, byteRate, Endian.little);
  offset += 4;
  bd.setUint16(offset, blockAlign, Endian.little);
  offset += 2;
  bd.setUint16(offset, 16, Endian.little); // bits per sample
  offset += 2;

  // data chunk
  for (final c in 'data'.codeUnits) {
    bd.setUint8(offset++, c);
  }
  bd.setUint32(offset, dataSize, Endian.little);
  offset += 4;
  for (final s in samples) {
    bd.setInt16(offset, s, Endian.little);
    offset += 2;
  }

  return bd.buffer.asUint8List();
}
