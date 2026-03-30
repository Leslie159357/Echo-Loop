import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluency/database/app_database.dart';
import 'package:fluency/database/daos/bookmark_dao.dart';

/// 创建内存数据库用于测试
AppDatabase _createTestDb() {
  return AppDatabase(
    NativeDatabase.memory(
      setup: (db) => db.execute('PRAGMA foreign_keys = ON'),
    ),
  );
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = _createTestDb();
  });

  tearDown(() async {
    await db.close();
  });

  group('SavedWordDao', () {
    test('saveWord 插入新单词', () async {
      await db.savedWordDao.saveWord(word: 'hello');

      final words = await db.savedWordDao.getAll();
      expect(words.length, 1);
      expect(words.first.word, 'hello');
    });

    test('saveWord 含来源信息', () async {
      // 先插入音频项（外键约束）
      final now = DateTime.now();
      await db.audioItemDao.upsert(
        AudioItemsCompanion(
          id: const Value('audio-1'),
          name: const Value('Test Audio'),
          audioPath: const Value('test.mp3'),
          addedDate: Value(now),
          updatedAt: Value(now),
        ),
      );

      await db.savedWordDao.saveWord(
        word: 'world',
        audioItemId: 'audio-1',
        sentenceIndex: 5,
        sentenceText: 'Hello world!',
        sentenceStartMs: 1500,
        sentenceEndMs: 3200,
      );

      final words = await db.savedWordDao.getAll();
      expect(words.length, 1);
      expect(words.first.word, 'world');
      expect(words.first.audioItemId, 'audio-1');
      expect(words.first.sentenceIndex, 5);
      expect(words.first.sentenceText, 'Hello world!');
      expect(words.first.sentenceStartMs, 1500);
      expect(words.first.sentenceEndMs, 3200);
    });

    test('saveWord 重复单词更新来源信息', () async {
      final now = DateTime.now();
      await db.audioItemDao.upsert(
        AudioItemsCompanion(
          id: const Value('audio-1'),
          name: const Value('Audio 1'),
          audioPath: const Value('1.mp3'),
          addedDate: Value(now),
          updatedAt: Value(now),
        ),
      );

      // 首次收藏
      await db.savedWordDao.saveWord(
        word: 'test',
        audioItemId: 'audio-1',
        sentenceIndex: 1,
        sentenceText: 'First sentence',
      );

      // 再次收藏同一单词，更新来源
      await db.savedWordDao.saveWord(
        word: 'test',
        sentenceIndex: 10,
        sentenceText: 'Updated sentence',
      );

      final words = await db.savedWordDao.getAll();
      expect(words.length, 1);
      expect(words.first.sentenceText, 'Updated sentence');
      expect(words.first.sentenceIndex, 10);
    });

    test('removeWord 删除单词', () async {
      await db.savedWordDao.saveWord(word: 'remove_me');
      expect((await db.savedWordDao.getAll()).length, 1);

      await db.savedWordDao.removeWord('remove_me');
      expect((await db.savedWordDao.getAll()).length, 0);
    });

    test('isWordSaved 返回正确状态', () async {
      expect(await db.savedWordDao.isWordSaved('hello'), false);

      await db.savedWordDao.saveWord(word: 'hello');
      expect(await db.savedWordDao.isWordSaved('hello'), true);

      await db.savedWordDao.removeWord('hello');
      expect(await db.savedWordDao.isWordSaved('hello'), false);
    });

    test('getAll 按时间倒序', () async {
      // 直接插入带明确时间戳的记录，避免时间精度问题
      final earlier = DateTime(2026, 1, 1);
      final later = DateTime(2026, 1, 2);

      await db.into(db.savedWords).insert(
        SavedWordsCompanion(
          word: const Value('alpha'),
          createdAt: Value(earlier),
          updatedAt: Value(earlier),
        ),
      );
      await db.into(db.savedWords).insert(
        SavedWordsCompanion(
          word: const Value('beta'),
          createdAt: Value(later),
          updatedAt: Value(later),
        ),
      );

      final words = await db.savedWordDao.getAll();
      expect(words.length, 2);
      expect(words.first.word, 'beta'); // 最新的在前
      expect(words.last.word, 'alpha');
    });

    test('watchIsWordSaved 流式更新', () async {
      final stream = db.savedWordDao.watchIsWordSaved('hello');

      // 初始为 false
      expect(await stream.first, false);

      // 收藏后变为 true
      await db.savedWordDao.saveWord(word: 'hello');
      expect(await stream.first, true);
    });

    test('clearContextForAudio 清除上下文但保留单词', () async {
      final now = DateTime.now();
      await db.audioItemDao.upsert(
        AudioItemsCompanion(
          id: const Value('audio-1'),
          name: const Value('Audio 1'),
          audioPath: const Value('1.mp3'),
          addedDate: Value(now),
          updatedAt: Value(now),
        ),
      );
      await db.audioItemDao.upsert(
        AudioItemsCompanion(
          id: const Value('audio-2'),
          name: const Value('Audio 2'),
          audioPath: const Value('2.mp3'),
          addedDate: Value(now),
          updatedAt: Value(now),
        ),
      );

      // 两个不同音频的单词
      await db.savedWordDao.saveWord(
        word: 'apple',
        audioItemId: 'audio-1',
        sentenceIndex: 3,
        sentenceText: 'An apple a day',
      );
      await db.savedWordDao.saveWord(
        word: 'banana',
        audioItemId: 'audio-2',
        sentenceIndex: 7,
        sentenceText: 'I like bananas',
      );

      // 清除 audio-1 的上下文
      await db.savedWordDao.clearContextForAudio('audio-1');

      final words = await db.savedWordDao.getAll();
      expect(words.length, 2);

      final apple = words.firstWhere((w) => w.word == 'apple');
      expect(apple.audioItemId, 'audio-1'); // audioItemId 不变（由 FK 处理）
      expect(apple.sentenceIndex, isNull); // 上下文已清除
      expect(apple.sentenceText, isNull);

      final banana = words.firstWhere((w) => w.word == 'banana');
      expect(banana.audioItemId, 'audio-2'); // 其他音频不受影响
      expect(banana.sentenceIndex, 7);
      expect(banana.sentenceText, 'I like bananas');
    });

    test('clearContextForAudio 保留 sentenceStartMs/sentenceEndMs', () async {
      final now = DateTime.now();
      await db.audioItemDao.upsert(
        AudioItemsCompanion(
          id: const Value('audio-1'),
          name: const Value('Audio 1'),
          audioPath: const Value('1.mp3'),
          addedDate: Value(now),
          updatedAt: Value(now),
        ),
      );

      await db.savedWordDao.saveWord(
        word: 'test',
        audioItemId: 'audio-1',
        sentenceIndex: 3,
        sentenceText: 'Test sentence',
        sentenceStartMs: 1000,
        sentenceEndMs: 2500,
      );

      await db.savedWordDao.clearContextForAudio('audio-1');

      final words = await db.savedWordDao.getAll();
      final word = words.first;
      expect(word.sentenceIndex, isNull); // 索引已清除
      expect(word.sentenceText, isNull); // 文本已清除
      // 时间信息保留（删除字幕后仍可播放）
      expect(word.sentenceStartMs, 1000);
      expect(word.sentenceEndMs, 2500);
    });

    test('getDeletedWords 返回已软删除的单词', () async {
      await db.savedWordDao.saveWord(word: 'apple');
      await db.savedWordDao.saveWord(word: 'banana');
      await db.savedWordDao.saveWord(word: 'cherry');

      await db.savedWordDao.removeWord('apple');
      await db.savedWordDao.removeWord('cherry');

      final deleted = await db.savedWordDao.getDeletedWords(
        sortMode: RecycleBinSortMode.alphaAsc,
      );
      expect(deleted.length, 2);
      expect(deleted.first.word, 'apple');
      expect(deleted.last.word, 'cherry');

      // 活跃列表只剩 banana
      final active = await db.savedWordDao.getAll();
      expect(active.length, 1);
      expect(active.first.word, 'banana');
    });

    test('restoreWord 恢复已软删除的单词', () async {
      await db.savedWordDao.saveWord(word: 'hello');
      await db.savedWordDao.removeWord('hello');
      expect(await db.savedWordDao.isWordSaved('hello'), false);

      await db.savedWordDao.restoreWord('hello');
      expect(await db.savedWordDao.isWordSaved('hello'), true);
    });

    test('permanentlyDeleteWord 物理删除单词', () async {
      await db.savedWordDao.saveWord(word: 'hello');
      await db.savedWordDao.removeWord('hello');
      await db.savedWordDao.permanentlyDeleteWord('hello');

      await db.savedWordDao.restoreWord('hello');
      expect(await db.savedWordDao.isWordSaved('hello'), false);
    });

    test('permanentlyDeleteAllDeleted 清空回收站但不影响活跃单词', () async {
      await db.savedWordDao.saveWord(word: 'apple');
      await db.savedWordDao.saveWord(word: 'banana');

      await db.savedWordDao.removeWord('apple');
      await db.savedWordDao.permanentlyDeleteAllDeleted();

      final deleted = await db.savedWordDao.getDeletedWords(
        sortMode: RecycleBinSortMode.timeDesc,
      );
      expect(deleted, isEmpty);

      final active = await db.savedWordDao.getAll();
      expect(active.length, 1);
      expect(active.first.word, 'banana');
    });

    test('删除音频时 audioItemId 置空', () async {
      final now = DateTime.now();
      await db.audioItemDao.upsert(
        AudioItemsCompanion(
          id: const Value('audio-1'),
          name: const Value('Audio 1'),
          audioPath: const Value('1.mp3'),
          addedDate: Value(now),
          updatedAt: Value(now),
        ),
      );

      await db.savedWordDao.saveWord(
        word: 'test',
        audioItemId: 'audio-1',
        sentenceIndex: 1,
        sentenceText: 'Test sentence',
      );

      // 删除音频
      await db.audioItemDao.hardDelete('audio-1');

      // 单词保留，audioItemId 置空
      final words = await db.savedWordDao.getAll();
      expect(words.length, 1);
      expect(words.first.word, 'test');
      expect(words.first.audioItemId, isNull);
      // sentenceText 保留（冗余存储）
      expect(words.first.sentenceText, 'Test sentence');
    });
  });
}
