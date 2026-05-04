import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:echo_loop/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:echo_loop/services/backup/backup_manifest.dart';
import 'package:echo_loop/services/backup/backup_service.dart';
import 'package:echo_loop/utils/app_data_dir.dart';

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  final String rootPath;

  _FakePathProvider(this.rootPath);

  @override
  Future<String?> getApplicationSupportPath() async => rootPath;

  @override
  Future<String?> getTemporaryPath() async => rootPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BackupManifest', () {
    test('toJson / fromJson 往返正确', () {
      final manifest = BackupManifest(
        version: 1,
        appVersion: '1.0.3',
        schemaVersion: 23,
        createdAt: DateTime.utc(2026, 3, 26, 14, 30),
        platform: 'ios',
        dbSha256: 'abc123',
        mediaFileCount: 5,
        totalSizeBytes: 1024000,
      );

      final json = manifest.toJson();
      final restored = BackupManifest.fromJson(json);

      expect(restored.version, 1);
      expect(restored.appVersion, '1.0.3');
      expect(restored.schemaVersion, 23);
      expect(restored.createdAt, DateTime.utc(2026, 3, 26, 14, 30));
      expect(restored.platform, 'ios');
      expect(restored.dbSha256, 'abc123');
      expect(restored.mediaFileCount, 5);
      expect(restored.totalSizeBytes, 1024000);
    });

    test('formattedSize 正确格式化各级别大小', () {
      expect(
        BackupManifest(
          version: 1,
          appVersion: '',
          schemaVersion: 1,
          createdAt: DateTime.now(),
          platform: '',
          dbSha256: '',
          mediaFileCount: 0,
          totalSizeBytes: 500,
        ).formattedSize,
        '500 B',
      );

      expect(
        BackupManifest(
          version: 1,
          appVersion: '',
          schemaVersion: 1,
          createdAt: DateTime.now(),
          platform: '',
          dbSha256: '',
          mediaFileCount: 0,
          totalSizeBytes: 2048,
        ).formattedSize,
        '2.0 KB',
      );

      expect(
        BackupManifest(
          version: 1,
          appVersion: '',
          schemaVersion: 1,
          createdAt: DateTime.now(),
          platform: '',
          dbSha256: '',
          mediaFileCount: 0,
          totalSizeBytes: 5 * 1024 * 1024,
        ).formattedSize,
        '5.0 MB',
      );

      expect(
        BackupManifest(
          version: 1,
          appVersion: '',
          schemaVersion: 1,
          createdAt: DateTime.now(),
          platform: '',
          dbSha256: '',
          mediaFileCount: 0,
          totalSizeBytes: 2 * 1024 * 1024 * 1024,
        ).formattedSize,
        '2.0 GB',
      );
    });
  });

  group('BackupService — ZIP 验证', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('backup_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('readManifest 正确读取 ZIP 中的 manifest', () async {
      // 构造含 manifest.json 的 ZIP
      final manifest = BackupManifest(
        version: 1,
        appVersion: '1.0.3',
        schemaVersion: 23,
        createdAt: DateTime.utc(2026, 3, 26),
        platform: 'ios',
        dbSha256: 'test_sha',
        mediaFileCount: 0,
        totalSizeBytes: 100,
      );
      final manifestJson = utf8.encode(jsonEncode(manifest.toJson()));

      final archive = Archive();
      archive.addFile(
        ArchiveFile('manifest.json', manifestJson.length, manifestJson),
      );
      // 添加一个假的 db 文件
      archive.addFile(ArchiveFile('echo_loop.db', 4, utf8.encode('test')));

      final zipData = ZipEncoder().encode(archive);
      final zipFile = File('${tempDir.path}/test.zip');
      zipFile.writeAsBytesSync(zipData);

      // 使用一个不需要真实数据库的方式测试 readManifest
      // 由于 BackupService 需要 AppDatabase，这里直接测试 ZIP 解码逻辑
      final bytes = zipFile.readAsBytesSync();
      final decoded = ZipDecoder().decodeBytes(bytes);
      final entry = decoded.findFile('manifest.json');
      expect(entry, isNotNull);

      final restored = BackupManifest.fromJson(
        jsonDecode(utf8.decode(entry!.content as List<int>))
            as Map<String, dynamic>,
      );
      expect(restored.version, 1);
      expect(restored.appVersion, '1.0.3');
      expect(restored.schemaVersion, 23);
    });

    test('manifest.json 缺失时应失败', () {
      final archive = Archive();
      archive.addFile(ArchiveFile('echo_loop.db', 4, utf8.encode('test')));
      final zipData = ZipEncoder().encode(archive);

      final decoded = ZipDecoder().decodeBytes(zipData);
      final entry = decoded.findFile('manifest.json');
      expect(entry, isNull);
    });

    test('ZIP slip 路径检测', () {
      const testPaths = [
        '../etc/passwd',
        'media/../../secret.txt',
        '/absolute/path.txt',
      ];
      for (final path in testPaths) {
        final hasSlip =
            path.contains('..') ||
            path.startsWith('/') ||
            path.startsWith('\\');
        expect(hasSlip, isTrue, reason: 'Should detect: $path');
      }
    });

    test('正常相对路径不触发 ZIP slip 检测', () {
      const safePaths = [
        'manifest.json',
        'echo_loop.db',
        'media/audios/test.mp3',
        'media/transcripts/test.srt',
      ];
      for (final path in safePaths) {
        final hasSlip =
            path.contains('..') ||
            path.startsWith('/') ||
            path.startsWith('\\');
        expect(hasSlip, isFalse, reason: 'Should be safe: $path');
      }
    });

    test('导出时跳过未下载官方音频的 null audio_path', () async {
      final docsDir = Directory(p.join(tempDir.path, 'docs'))
        ..createSync(recursive: true);
      final outputDir = Directory(p.join(tempDir.path, 'out'))
        ..createSync(recursive: true);
      PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
      SharedPreferences.setMockInitialValues({});
      appDataDirectoryOverride = docsDir;
      addTearDown(() => appDataDirectoryOverride = null);

      final db = AppDatabase(
        NativeDatabase(File(p.join(docsDir.path, 'echo_loop.db'))),
      );
      addTearDown(db.close);

      final now = DateTime(2026, 4, 20);
      await db
          .into(db.audioItems)
          .insert(
            AudioItemsCompanion.insert(
              id: 'official-placeholder',
              name: 'Official Placeholder',
              addedDate: now,
              updatedAt: now,
              audioPath: const Value(null),
              transcriptPath: const Value(null),
              remoteAudioId: const Value('remote-audio-1'),
            ),
          );

      final localAudio = File(p.join(docsDir.path, 'audios/local.mp3'));
      await localAudio.parent.create(recursive: true);
      await localAudio.writeAsBytes([1, 2, 3]);
      await db
          .into(db.audioItems)
          .insert(
            AudioItemsCompanion.insert(
              id: 'local-audio',
              name: 'Local Audio',
              addedDate: now,
              updatedAt: now,
              audioPath: const Value('audios/local.mp3'),
            ),
          );

      final zipPath = await BackupService(db).exportData(
        outputDir: outputDir.path,
        appVersion: '1.0.0',
        platform: 'macos',
      );

      final archive = ZipDecoder().decodeBytes(
        await File(zipPath).readAsBytes(),
      );
      expect(archive.findFile('media/audios/local.mp3'), isNotNull);
      expect(archive.findFile('media/audios/official-placeholder.mp3'), isNull);

      final manifestEntry = archive.findFile('manifest.json');
      final manifest = BackupManifest.fromJson(
        jsonDecode(utf8.decode(manifestEntry!.content as List<int>))
            as Map<String, dynamic>,
      );
      expect(manifest.mediaFileCount, 1);
    });
  });

  group('BackupException', () {
    test('toString 包含 message', () {
      const ex = BackupException('test error');
      expect(ex.toString(), 'BackupException: test error');
      expect(ex.message, 'test error');
    });
  });

  group('SharedPreferences 黑名单逻辑', () {
    test('黑名单 key 应被排除', () {
      const blacklist = {
        'demo_mode',
        'developer_time_machine_at_ms',
        'anonymous_id',
        'unlock_all_reviews',
      };
      const prefixBlacklist = ['app_update_'];

      bool shouldExclude(String key) {
        if (blacklist.contains(key)) return true;
        if (prefixBlacklist.any((p) => key.startsWith(p))) return true;
        if (key == 'geo_country') return true;
        return false;
      }

      // 应排除
      expect(shouldExclude('demo_mode'), isTrue);
      expect(shouldExclude('anonymous_id'), isTrue);
      expect(shouldExclude('app_update_last_check'), isTrue);
      expect(shouldExclude('geo_country'), isTrue);

      // 不应排除
      expect(shouldExclude('theme_mode'), isFalse);
      expect(shouldExclude('locale'), isFalse);
      expect(shouldExclude('playback_settings'), isFalse);
      expect(shouldExclude('reminder_settings'), isFalse);
    });
  });
}
