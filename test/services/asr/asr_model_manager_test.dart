import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:echo_loop/services/asr/asr_model_manager.dart';

class _TestAsrModelManager extends AsrModelManager {
  _TestAsrModelManager(
    this.rootDir, {
    required super.modelRegistryOverride,
    super.dio,
    super.baseUrlOverride,
  });

  final Directory rootDir;

  @override
  Future<String> modelDir(String modelId) async =>
      p.join(rootDir.path, modelId);
}

void main() {
  late Map<String, AsrModelManifest> manifest;

  setUp(() {
    final encoderBytes = List<int>.filled(100, 1);
    final decoderBytes = List<int>.filled(100, 2);
    final tokensBytes = List<int>.filled(50, 3);

    manifest = {
      'test-model': AsrModelManifest(
        files: [
          AsrModelFileSpec(
            path: 'encoder.onnx',
            sha256: sha256.convert(encoderBytes).toString(),
          ),
          AsrModelFileSpec(
            path: 'decoder.onnx',
            sha256: sha256.convert(decoderBytes).toString(),
          ),
          AsrModelFileSpec(
            path: 'tokens.txt',
            sha256: sha256.convert(tokensBytes).toString(),
          ),
        ],
      ),
    };
  });

  test('validateModel 对残缺模型返回 false', () async {
    final rootDir = await Directory.systemTemp.createTemp('asr-model-test');
    addTearDown(() async {
      if (await rootDir.exists()) {
        await rootDir.delete(recursive: true);
      }
    });

    final manager = _TestAsrModelManager(
      rootDir,
      modelRegistryOverride: manifest,
    );
    final modelDir = Directory(await manager.modelDir('test-model'));
    await modelDir.create(recursive: true);
    await File(
      p.join(modelDir.path, 'encoder.onnx'),
    ).writeAsBytes(List.filled(64, 1));
    await File(
      p.join(modelDir.path, 'decoder.onnx'),
    ).writeAsBytes(List.filled(100, 2));
    await File(
      p.join(modelDir.path, 'tokens.txt'),
    ).writeAsBytes(List.filled(50, 3));

    final result = await manager.validateModel('test-model');
    expect(result.isValid, isFalse);
    expect(result.filePath, 'encoder.onnx');
    expect(result.reason, 'SHA-256 mismatch');
  });

  test('downloadModel 会重新下载已存在但哈希不匹配的文件', () async {
    final rootDir = await Directory.systemTemp.createTemp('asr-redownload');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async {
      await server.close(force: true);
      if (await rootDir.exists()) {
        await rootDir.delete(recursive: true);
      }
    });

    final filePayloads = <String, List<int>>{
      'encoder.onnx': List<int>.filled(100, 1),
      'decoder.onnx': List<int>.filled(100, 2),
      'tokens.txt': List<int>.filled(50, 3),
    };

    server.listen((request) async {
      final fileName = request.uri.pathSegments.last;
      final payload = filePayloads[fileName]!;
      request.response.headers.contentLength = payload.length;
      if (request.method == 'HEAD') {
        await request.response.close();
        return;
      }
      request.response.add(payload);
      await request.response.close();
    });

    final manager = _TestAsrModelManager(
      rootDir,
      dio: Dio(),
      baseUrlOverride: 'http://${server.address.host}:${server.port}',
      modelRegistryOverride: manifest,
    );
    final modelDir = Directory(await manager.modelDir('test-model'));
    await modelDir.create(recursive: true);
    await File(
      p.join(modelDir.path, 'encoder.onnx'),
    ).writeAsBytes(List.filled(100, 9));
    await File(
      p.join(modelDir.path, 'decoder.onnx'),
    ).writeAsBytes(filePayloads['decoder.onnx']!);
    await File(
      p.join(modelDir.path, 'tokens.txt'),
    ).writeAsBytes(filePayloads['tokens.txt']!);

    await manager.downloadModel('test-model');

    final encoder = File(p.join(modelDir.path, 'encoder.onnx'));
    expect(await encoder.length(), 100);
    final result = await manager.validateModel('test-model');
    expect(result.isValid, isTrue);
  });
}
