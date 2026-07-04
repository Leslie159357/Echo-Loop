/// DictionaryService 词形还原查询测试
///
/// 使用内存 SQLite 数据库验证精确匹配和词形还原 fallback 逻辑。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/services/dictionary_service.dart';
import 'package:path/path.dart' as p;
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

void main() {
  late DictionaryService service;
  late Database db;

  setUp(() {
    db = _createTestDb();
    service = DictionaryService.withDatabase(db);
  });

  tearDown(() {
    service.close();
  });

  group('isAvailable', () {
    test('withDatabase 构造后为 true', () {
      expect(service.isAvailable, isTrue);
    });

    test('未打开数据库时为 false', () {
      final emptyService = DictionaryService.withDatabase(_createTestDb());
      emptyService.close();
      expect(emptyService.isAvailable, isFalse);
    });
  });

  group('openDatabase 补建 NOCASE 索引 + 预热', () {
    test('打开文件库时补建 idx_words_word_nocase，大小写不敏感查询命中', () async {
      final dir = await Directory.systemTemp.createTemp('dict_test');
      final path = p.join(dir.path, 'dict.db');
      // 预置一个无索引的 words 表文件库（headword 含大写）
      final seed = sqlite3.open(path);
      seed.execute(
        'CREATE TABLE words (word TEXT, phonetic TEXT NOT NULL, '
        'translation TEXT, collins INTEGER DEFAULT 0, tag TEXT)',
      );
      seed.execute(
        "INSERT INTO words (word, phonetic, translation) "
        "VALUES ('Message', 'ˈmesɪdʒ', 'n. 消息')",
      );
      seed.dispose();

      final svc = DictionaryService.instance;
      svc.openDatabase(path);
      addTearDown(() async {
        svc.close();
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      });

      // 索引已补建
      final checker = sqlite3.open(path, mode: OpenMode.readOnly);
      final idx = checker.select(
        "SELECT name FROM sqlite_master WHERE type='index' "
        "AND name='idx_words_word_nocase'",
      );
      checker.dispose();
      expect(idx, isNotEmpty);

      // NOCASE 查询命中（输入小写，headword 大写）
      expect(svc.lookup('message')?.word, 'Message');

      // 预热词形还原器不抛异常
      svc.warmUpLemmatizer();
      // 预热数据库页缓存不抛异常，且不影响后续查询
      svc.warmUpDatabase();
      expect(svc.lookup('message')?.word, 'Message');

      svc.close();
      await dir.delete(recursive: true);
    });

    test('warmUpDatabase 在数据库未就绪时安全 no-op', () {
      final closedService = DictionaryService.withDatabase(_createTestDb());
      closedService.close();
      expect(closedService.warmUpDatabase, returnsNormally);
    });
  });

  group('数据库未就绪', () {
    test('lookup 返回 null', () {
      final closedService = DictionaryService.withDatabase(_createTestDb());
      closedService.close();
      expect(closedService.lookup('professor'), isNull);
    });

    test('lookupAll 返回空 map', () {
      final closedService = DictionaryService.withDatabase(_createTestDb());
      closedService.close();
      expect(closedService.lookupAll(['professor']), isEmpty);
    });
  });

  group('精确匹配', () {
    test('查到已有单词', () {
      final entry = service.lookup('professor');
      expect(entry, isNotNull);
      expect(entry!.word, 'professor');
      expect(entry.phonetic, contains('fes'));
    });

    test('大小写不敏感', () {
      final entry = service.lookup('Professor');
      expect(entry, isNotNull);
      expect(entry!.word, 'professor');
    });

    test('查不到且无法还原的词返回 null', () {
      final entry = service.lookup('xyznotaword');
      expect(entry, isNull);
    });

    test('会去掉单词两侧多余符号', () {
      final entry = service.lookup(' "Professor!" ');
      expect(entry, isNotNull);
      expect(entry!.word, 'professor');
    });

    test('只有符号时返回 null', () {
      final entry = service.lookup('..."\'!?');
      expect(entry, isNull);
    });
  });

  group('词形还原 fallback', () {
    test('复数 -s → 原形（professors → professor）', () {
      final entry = service.lookup('professors');
      expect(entry, isNotNull);
      expect(entry!.word, 'professor');
    });

    test('动词 -ing → 原形（running → run）', () {
      final entry = service.lookup('running');
      expect(entry, isNotNull);
      expect(entry!.word, 'run');
    });

    test('动词 -s → 原形（goes → go）', () {
      final entry = service.lookup('goes');
      expect(entry, isNotNull);
      expect(entry!.word, 'go');
    });

    test('比较级 -er → 原形（happier → happy）', () {
      final entry = service.lookup('happier');
      expect(entry, isNotNull);
      expect(entry!.word, 'happy');
    });

    test('过去式 -ied → 原形（studied → study）', () {
      final entry = service.lookup('studied');
      expect(entry, isNotNull);
      expect(entry!.word, 'study');
    });

    test('不规则复数（children → child）', () {
      final entry = service.lookup('children');
      expect(entry, isNotNull);
      expect(entry!.word, 'child');
    });

    test('不规则复数（mice → mouse）', () {
      final entry = service.lookup('mice');
      expect(entry, isNotNull);
      expect(entry!.word, 'mouse');
    });

    test('不规则过去式（went → go）', () {
      final entry = service.lookup('went');
      expect(entry, isNotNull);
      expect(entry!.word, 'go');
    });

    test('最高级 -est → 原形（happiest → happy）', () {
      final entry = service.lookup('happiest');
      expect(entry, isNotNull);
      expect(entry!.word, 'happy');
    });

    test('过去分词 -ed（studied → study）', () {
      final entry = service.lookup('studies');
      expect(entry, isNotNull);
      expect(entry!.word, 'study');
    });
  });

  group('批量查询 lookupAll', () {
    test('大小写不敏感', () {
      final results = service.lookupAll(['Professor', 'RUN']);
      expect(results['Professor'], isNotNull);
      expect(results['Professor']!.word, 'professor');
      expect(results['RUN'], isNotNull);
      expect(results['RUN']!.word, 'run');
    });

    test('未收录的词不出现在结果中', () {
      final results = service.lookupAll(['professor', 'xyznotaword']);
      expect(results.containsKey('professor'), isTrue);
      expect(results.containsKey('xyznotaword'), isFalse);
    });

    test('词形还原 fallback', () {
      final results = service.lookupAll(['professors', 'running']);
      expect(results['professors'], isNotNull);
      expect(results['professors']!.word, 'professor');
      expect(results['running'], isNotNull);
      expect(results['running']!.word, 'run');
    });

    test('词组（含空格）不做词形还原，未收录即不命中', () {
      // "going to" 是词组，本地库只收单词，不应被拆词还原到 go
      final results = service.lookupAll(['going to']);
      expect(results.containsKey('going to'), isFalse);
    });
  });

  group('词组不做词形还原', () {
    test('lookup 词组精确未命中直接返回 null（不还原到 go）', () {
      expect(service.lookup('going to'), isNull);
    });

    test('lookup 词组精确命中仍正常返回', () {
      // 若本地库恰好收录该词组，精确匹配照常命中
      db.execute(
        "INSERT INTO words (word, phonetic, translation) "
        "VALUES ('give up', 'ɡɪv ʌp', 'v. 放弃')",
      );
      final entry = service.lookup('give up');
      expect(entry?.word, 'give up');
    });
  });
}
