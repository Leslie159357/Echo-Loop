import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/services/temp_cleanup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory fakeDocsDir;
  late Directory fakeCacheDir;
  late Directory fakeTmpDir;

  setUp(() {
    // 创建模拟的沙盒结构：sandbox/Documents, sandbox/tmp, sandbox/Library/Caches
    final sandbox = Directory.systemTemp.createTempSync('cleanup_test_');
    fakeDocsDir = Directory('${sandbox.path}/Documents')..createSync();
    fakeTmpDir = Directory('${sandbox.path}/tmp')..createSync();
    fakeCacheDir = Directory('${sandbox.path}/Library/Caches')
      ..createSync(recursive: true);

    // Mock path_provider
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async {
            if (call.method == 'getApplicationDocumentsDirectory') {
              return fakeDocsDir.path;
            }
            if (call.method == 'getTemporaryDirectory') {
              return fakeCacheDir.path;
            }
            return null;
          },
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    // 清理整个模拟沙盒
    final sandbox = fakeDocsDir.parent;
    if (sandbox.existsSync()) {
      sandbox.deleteSync(recursive: true);
    }
  });

  group('cleanupRecordingTempFiles', () {
    test('删除 tmp/ 中的旧文件', () async {
      final oldFile = File('${fakeTmpDir.path}/old.caf');
      oldFile.writeAsBytesSync(List.filled(1000, 0));
      // 将修改时间设为 2 分钟前
      oldFile.setLastModifiedSync(
        DateTime.now().subtract(const Duration(minutes: 2)),
      );

      final result = await cleanupRecordingTempFiles();

      expect(result.freedBytes, 1000);
      expect(oldFile.existsSync(), false);
    });

    test('跳过 tmp/ 中不足 minAge 的文件', () async {
      final newFile = File('${fakeTmpDir.path}/new.caf');
      newFile.writeAsBytesSync(List.filled(500, 0));
      // 刚创建的文件，不足 60 秒

      final result = await cleanupRecordingTempFiles();

      expect(result.freedBytes, 0);
      expect(newFile.existsSync(), true);
    });

    test('不清理 Library/Caches', () async {
      final cacheFile = File('${fakeCacheDir.path}/cached.dat');
      cacheFile.writeAsBytesSync(List.filled(2000, 0));
      cacheFile.setLastModifiedSync(
        DateTime.now().subtract(const Duration(minutes: 5)),
      );

      await cleanupRecordingTempFiles();

      expect(cacheFile.existsSync(), true);
    });

    test('tmp/ 不存在时返回 0', () async {
      fakeTmpDir.deleteSync(recursive: true);

      final result = await cleanupRecordingTempFiles();

      expect(result.freedBytes, 0);
    });
  });

  group('cleanupAllTempFiles', () {
    test('同时清理 tmp/ 和 Library/Caches', () async {
      final tmpFile = File('${fakeTmpDir.path}/rec.caf');
      tmpFile.writeAsBytesSync(List.filled(1000, 0));
      final cacheFile = File('${fakeCacheDir.path}/cached.dat');
      cacheFile.writeAsBytesSync(List.filled(2000, 0));

      final result = await cleanupAllTempFiles();

      expect(result.freedBytes, greaterThanOrEqualTo(3000));
      expect(tmpFile.existsSync(), false);
      expect(cacheFile.existsSync(), false);
    });

    test('递归删除子目录', () async {
      final subDir = Directory('${fakeTmpDir.path}/echoloop_export_123')
        ..createSync();
      File('${subDir.path}/data.zip').writeAsBytesSync(List.filled(5000, 0));

      final result = await cleanupAllTempFiles();

      expect(result.freedBytes, greaterThanOrEqualTo(5000));
      expect(subDir.existsSync(), false);
    });
  });
}
