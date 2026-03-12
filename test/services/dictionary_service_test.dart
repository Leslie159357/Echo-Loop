/// DictionaryService 词形还原查询测试
///
/// 使用内存 SQLite 数据库验证精确匹配和词形还原 fallback 逻辑。
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluency/services/dictionary_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

/// 创建内存数据库并插入测试数据
Database _createTestDb() {
  final db = sqlite3.openInMemory();
  db.execute('''
    CREATE TABLE words (
      word TEXT PRIMARY KEY,
      phonetic TEXT NOT NULL,
      translation TEXT,
      collins INTEGER DEFAULT 0,
      tag TEXT
    )
  ''');
  final insertSql =
      "INSERT INTO words (word, phonetic, translation, collins, tag) VALUES"
      " ('professor', 'prəfesər', 'n. 教授', 4, 'gk cet4 cet6 ky toefl ielts'),"
      " ('run', 'rʌn', 'vi. 跑, 奔', 5, 'zk gk cet4'),"
      " ('go', 'gəu', 'vi. 去, 走', 5, 'zk gk cet4'),"
      " ('good', 'gud', 'a. 好的', 5, 'zk gk cet4'),"
      " ('happy', 'hæpi', 'a. 快乐的', 4, 'zk gk cet4'),"
      " ('study', 'stʌdi', 'n. 学习, 研究', 4, 'zk gk cet4'),"
      " ('child', 'tʃaild', 'n. 孩子', 5, 'zk gk cet4'),"
      " ('mouse', 'maus', 'n. 鼠, 鼠标', 3, 'zk gk cet4')";
  db.execute(insertSql);
  return db;
}

Future<Uint8List> _createTestDbBytes(List<String> words) async {
  final dir = await Directory.systemTemp.createTemp('dict_service_test_');
  final path = '${dir.path}/dict.db';
  final db = sqlite3.open(path);
  db.execute('''
    CREATE TABLE words (
      word TEXT PRIMARY KEY,
      phonetic TEXT NOT NULL,
      translation TEXT,
      collins INTEGER DEFAULT 0,
      tag TEXT
    )
  ''');
  for (final word in words) {
    db.execute(
      'INSERT INTO words (word, phonetic, translation, collins, tag) VALUES (?, ?, ?, 0, ?)',
      [word, word, '$word translation', ''],
    );
  }
  db.dispose();
  final bytes = await File(path).readAsBytes();
  await dir.delete(recursive: true);
  return bytes;
}

void main() {
  late DictionaryService service;
  late Database db;

  setUp(() {
    db = _createTestDb();
    service = DictionaryService.withDatabase(db);
  });

  tearDown(() {
    db.dispose();
  });

  group('精确匹配', () {
    test('查到已有单词', () async {
      final entry = await service.lookup('professor');
      expect(entry, isNotNull);
      expect(entry!.word, 'professor');
      expect(entry.phonetic, contains('fes'));
    });

    test('大小写不敏感', () async {
      final entry = await service.lookup('Professor');
      expect(entry, isNotNull);
      expect(entry!.word, 'professor');
    });

    test('查不到且无法还原的词返回 null', () async {
      final entry = await service.lookup('xyznotaword');
      expect(entry, isNull);
    });

    test('会去掉单词两侧多余符号', () async {
      final entry = await service.lookup(' "Professor!" ');
      expect(entry, isNotNull);
      expect(entry!.word, 'professor');
    });

    test('只有符号时返回 null', () async {
      final entry = await service.lookup('..."\'!?');
      expect(entry, isNull);
    });
  });

  group('词形还原 fallback', () {
    test('复数 -s → 原形（professors → professor）', () async {
      final entry = await service.lookup('professors');
      expect(entry, isNotNull);
      expect(entry!.word, 'professor');
    });

    test('动词 -ing → 原形（running → run）', () async {
      final entry = await service.lookup('running');
      expect(entry, isNotNull);
      expect(entry!.word, 'run');
    });

    test('动词 -s → 原形（goes → go）', () async {
      final entry = await service.lookup('goes');
      expect(entry, isNotNull);
      expect(entry!.word, 'go');
    });

    test('比较级 -er → 原形（happier → happy）', () async {
      final entry = await service.lookup('happier');
      expect(entry, isNotNull);
      expect(entry!.word, 'happy');
    });

    test('过去式 -ied → 原形（studied → study）', () async {
      final entry = await service.lookup('studied');
      expect(entry, isNotNull);
      expect(entry!.word, 'study');
    });

    test('不规则复数（children → child）', () async {
      final entry = await service.lookup('children');
      expect(entry, isNotNull);
      expect(entry!.word, 'child');
    });

    test('不规则复数（mice → mouse）', () async {
      final entry = await service.lookup('mice');
      expect(entry, isNotNull);
      expect(entry!.word, 'mouse');
    });

    test('不规则过去式（went → go）', () async {
      final entry = await service.lookup('went');
      expect(entry, isNotNull);
      expect(entry!.word, 'go');
    });

    test('最高级 -est → 原形（happiest → happy）', () async {
      final entry = await service.lookup('happiest');
      expect(entry, isNotNull);
      expect(entry!.word, 'happy');
    });

    test('过去分词 -ed（studied → study）', () async {
      final entry = await service.lookup('studies');
      expect(entry, isNotNull);
      expect(entry!.word, 'study');
    });
  });

  group('词典 asset 自动升级', () {
    late Directory appDir;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      appDir = await Directory.systemTemp.createTemp('dict_upgrade_app_dir_');
    });

    tearDown(() async {
      if (appDir.existsSync()) {
        await appDir.delete(recursive: true);
      }
    });

    test('首次使用时会复制 asset 词典', () async {
      var installCount = 0;
      final bytes = await _createTestDbBytes(['prioritize']);
      final installService = DictionaryService.withEnvironment(
        prefs: prefs,
        appDirProvider: () async => appDir,
        assetBytesLoader: () async => bytes,
        onDictionaryInstalled: () => installCount++,
      );

      final entry = await installService.lookup('prioritize');

      expect(entry, isNotNull);
      expect(entry!.word, 'prioritize');
      expect(File('${appDir.path}/dict.db').existsSync(), isTrue);
      expect(installCount, 1);
    });

    test('asset 未变化时不会重复覆盖本地词典', () async {
      var installCount = 0;
      final bytes = await _createTestDbBytes(['prioritize']);
      final firstService = DictionaryService.withEnvironment(
        prefs: prefs,
        appDirProvider: () async => appDir,
        assetBytesLoader: () async => bytes,
        onDictionaryInstalled: () => installCount++,
      );
      await firstService.lookup('prioritize');
      firstService.dispose();

      final secondService = DictionaryService.withEnvironment(
        prefs: prefs,
        appDirProvider: () async => appDir,
        assetBytesLoader: () async => bytes,
        onDictionaryInstalled: () => installCount++,
      );
      final entry = await secondService.lookup('prioritize');

      expect(entry, isNotNull);
      expect(entry!.word, 'prioritize');
      expect(installCount, 1);
    });

    test('旧用户本地已有旧库时会被新版 asset 自动覆盖', () async {
      final oldBytes = await _createTestDbBytes(['hello']);
      await File('${appDir.path}/dict.db').writeAsBytes(oldBytes, flush: true);

      final newBytes = await _createTestDbBytes(['prioritize']);
      final upgradeService = DictionaryService.withEnvironment(
        prefs: prefs,
        appDirProvider: () async => appDir,
        assetBytesLoader: () async => newBytes,
      );

      final newEntry = await upgradeService.lookup('prioritize');
      final oldEntry = await upgradeService.lookup('hello');

      expect(newEntry, isNotNull);
      expect(newEntry!.word, 'prioritize');
      expect(oldEntry, isNull);
    });
  });
}
