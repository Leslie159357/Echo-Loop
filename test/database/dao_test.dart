import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echo_loop/database/app_database.dart';
import 'package:echo_loop/database/daos/bookmark_dao.dart';

/// 创建内存数据库用于测试（启用外键约束）
AppDatabase createTestDatabase() {
  return AppDatabase(
    NativeDatabase.memory(
      setup: (db) {
        db.execute('PRAGMA foreign_keys = ON');
      },
    ),
  );
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = createTestDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  group('AudioItemDao', () {
    test('插入并查询音频项', () async {
      final now = DateTime.now();
      await db.audioItemDao.upsert(
        AudioItemsCompanion(
          id: Value('audio-1'),
          name: Value('Test Audio'),
          audioPath: Value('audios/test.mp3'),
          transcriptPath: Value('transcripts/test.srt'),
          addedDate: Value(now),
          totalDuration: Value(120),
          updatedAt: Value(now),
        ),
      );

      final items = await db.audioItemDao.getAllActive();
      expect(items.length, 1);
      expect(items.first.id, 'audio-1');
      expect(items.first.name, 'Test Audio');
      expect(items.first.audioPath, 'audios/test.mp3');
      expect(items.first.totalDuration, 120);
    });

    test('getById 返回正确的音频项', () async {
      final now = DateTime.now();
      await db.audioItemDao.upsert(
        AudioItemsCompanion(
          id: Value('audio-1'),
          name: Value('Audio 1'),
          audioPath: Value('audios/1.mp3'),
          addedDate: Value(now),
          updatedAt: Value(now),
        ),
      );

      final item = await db.audioItemDao.getById('audio-1');
      expect(item, isNotNull);
      expect(item!.name, 'Audio 1');

      final missing = await db.audioItemDao.getById('nonexistent');
      expect(missing, isNull);
    });

    test('upsert 更新已存在的音频项', () async {
      final now = DateTime.now();
      await db.audioItemDao.upsert(
        AudioItemsCompanion(
          id: Value('audio-1'),
          name: Value('Original'),
          audioPath: Value('audios/1.mp3'),
          addedDate: Value(now),
          updatedAt: Value(now),
        ),
      );

      await db.audioItemDao.upsert(
        AudioItemsCompanion(
          id: Value('audio-1'),
          name: Value('Updated'),
          audioPath: Value('audios/1.mp3'),
          addedDate: Value(now),
          updatedAt: Value(now),
        ),
      );

      final items = await db.audioItemDao.getAllActive();
      expect(items.length, 1);
      expect(items.first.name, 'Updated');
    });

    test('softDelete 设置 deletedAt，从 getAllActive 中排除', () async {
      final now = DateTime.now();
      await db.audioItemDao.upsert(
        AudioItemsCompanion(
          id: Value('audio-1'),
          name: Value('To Delete'),
          audioPath: Value('audios/1.mp3'),
          addedDate: Value(now),
          updatedAt: Value(now),
        ),
      );

      await db.audioItemDao.softDelete('audio-1');

      final active = await db.audioItemDao.getAllActive();
      expect(active, isEmpty);

      // 但仍然可以通过 getById 找到
      final item = await db.audioItemDao.getById('audio-1');
      expect(item, isNotNull);
      expect(item!.deletedAt, isNotNull);
    });

    test('batchInsert 批量插入', () async {
      final now = DateTime.now();
      final entries = List.generate(
        5,
        (i) => AudioItemsCompanion(
          id: Value('audio-$i'),
          name: Value('Audio $i'),
          audioPath: Value('audios/$i.mp3'),
          addedDate: Value(now),
          updatedAt: Value(now),
        ),
      );

      await db.audioItemDao.batchInsert(entries);

      final items = await db.audioItemDao.getAllActive();
      expect(items.length, 5);
    });

    test('watchAllActive 响应数据变化', () async {
      final now = DateTime.now();
      final stream = db.audioItemDao.watchAllActive();

      // 初始为空
      expect(await stream.first, isEmpty);

      // 添加一个
      await db.audioItemDao.upsert(
        AudioItemsCompanion(
          id: Value('audio-1'),
          name: Value('Audio 1'),
          audioPath: Value('audios/1.mp3'),
          addedDate: Value(now),
          updatedAt: Value(now),
        ),
      );

      final items = await stream.first;
      expect(items.length, 1);
    });
  });

  group('CollectionDao', () {
    test('插入并查询合集', () async {
      final now = DateTime.now();
      await db.collectionDao.upsert(
        CollectionsCompanion(
          id: Value('col-1'),
          name: Value('Test Collection'),
          createdDate: Value(now),
          updatedAt: Value(now),
        ),
      );

      final collections = await db.collectionDao.getAllActive();
      expect(collections.length, 1);
      expect(collections.first.name, 'Test Collection');
    });

    test('addAudio 和 getAudioIds', () async {
      final now = DateTime.now();
      // 先插入音频项和合集
      await db.audioItemDao.upsert(
        AudioItemsCompanion(
          id: Value('audio-1'),
          name: Value('Audio 1'),
          audioPath: Value('audios/1.mp3'),
          addedDate: Value(now),
          updatedAt: Value(now),
        ),
      );
      await db.audioItemDao.upsert(
        AudioItemsCompanion(
          id: Value('audio-2'),
          name: Value('Audio 2'),
          audioPath: Value('audios/2.mp3'),
          addedDate: Value(now),
          updatedAt: Value(now),
        ),
      );
      await db.collectionDao.upsert(
        CollectionsCompanion(
          id: Value('col-1'),
          name: Value('Collection 1'),
          createdDate: Value(now),
          updatedAt: Value(now),
        ),
      );

      await db.collectionDao.addAudio('col-1', 'audio-1');
      await db.collectionDao.addAudio('col-1', 'audio-2');

      final audioIds = await db.collectionDao.getAudioIds('col-1');
      expect(audioIds.length, 2);
      expect(audioIds, contains('audio-1'));
      expect(audioIds, contains('audio-2'));
    });

    test('removeAudio 从合集移除音频', () async {
      final now = DateTime.now();
      await db.audioItemDao.upsert(
        AudioItemsCompanion(
          id: Value('audio-1'),
          name: Value('Audio 1'),
          audioPath: Value('audios/1.mp3'),
          addedDate: Value(now),
          updatedAt: Value(now),
        ),
      );
      await db.collectionDao.upsert(
        CollectionsCompanion(
          id: Value('col-1'),
          name: Value('Collection 1'),
          createdDate: Value(now),
          updatedAt: Value(now),
        ),
      );

      await db.collectionDao.addAudio('col-1', 'audio-1');
      await db.collectionDao.removeAudio('col-1', 'audio-1');

      final audioIds = await db.collectionDao.getAudioIds('col-1');
      expect(audioIds, isEmpty);
    });

    test('removeAudioFromAll 从所有合集移除', () async {
      final now = DateTime.now();
      await db.audioItemDao.upsert(
        AudioItemsCompanion(
          id: Value('audio-1'),
          name: Value('Audio 1'),
          audioPath: Value('audios/1.mp3'),
          addedDate: Value(now),
          updatedAt: Value(now),
        ),
      );

      for (int i = 1; i <= 3; i++) {
        await db.collectionDao.upsert(
          CollectionsCompanion(
            id: Value('col-$i'),
            name: Value('Collection $i'),
            createdDate: Value(now),
            updatedAt: Value(now),
          ),
        );
        await db.collectionDao.addAudio('col-$i', 'audio-1');
      }

      await db.collectionDao.removeAudioFromAll('audio-1');

      for (int i = 1; i <= 3; i++) {
        final ids = await db.collectionDao.getAudioIds('col-$i');
        expect(ids, isEmpty, reason: 'col-$i should be empty');
      }
    });

    test('getAudioCount 返回正确数量', () async {
      final now = DateTime.now();
      await db.collectionDao.upsert(
        CollectionsCompanion(
          id: Value('col-1'),
          name: Value('Collection 1'),
          createdDate: Value(now),
          updatedAt: Value(now),
        ),
      );

      for (int i = 0; i < 3; i++) {
        await db.audioItemDao.upsert(
          AudioItemsCompanion(
            id: Value('audio-$i'),
            name: Value('Audio $i'),
            audioPath: Value('audios/$i.mp3'),
            addedDate: Value(now),
            updatedAt: Value(now),
          ),
        );
        await db.collectionDao.addAudio('col-1', 'audio-$i');
      }

      final count = await db.collectionDao.getAudioCount('col-1');
      expect(count, 3);
    });

    test('CASCADE 删除：音频删除后 junction 自动清理', () async {
      final now = DateTime.now();
      await db.audioItemDao.upsert(
        AudioItemsCompanion(
          id: Value('audio-1'),
          name: Value('Audio 1'),
          audioPath: Value('audios/1.mp3'),
          addedDate: Value(now),
          updatedAt: Value(now),
        ),
      );
      await db.collectionDao.upsert(
        CollectionsCompanion(
          id: Value('col-1'),
          name: Value('Collection 1'),
          createdDate: Value(now),
          updatedAt: Value(now),
        ),
      );
      await db.collectionDao.addAudio('col-1', 'audio-1');

      // 硬删除音频
      await db.audioItemDao.hardDelete('audio-1');

      final ids = await db.collectionDao.getAudioIds('col-1');
      expect(ids, isEmpty);
    });
  });

  group('BookmarkDao', () {
    setUp(() async {
      // 先插入音频项
      final now = DateTime.now();
      await db.audioItemDao.upsert(
        AudioItemsCompanion(
          id: Value('audio-1'),
          name: Value('Audio 1'),
          audioPath: Value('audios/1.mp3'),
          addedDate: Value(now),
          updatedAt: Value(now),
        ),
      );
    });

    test('添加并查询书签', () async {
      final now = DateTime.now();
      await db.bookmarkDao.addBookmark(
        BookmarksCompanion(
          audioItemId: Value('audio-1'),
          sentenceIndex: Value(5),
          sentenceText: Value('Hello world'),
          startTime: Value(10.5),
          endTime: Value(12.3),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      final bookmarks = await db.bookmarkDao.getByAudioId('audio-1');
      expect(bookmarks.length, 1);
      expect(bookmarks.first.sentenceIndex, 5);
      expect(bookmarks.first.sentenceText, 'Hello world');
      expect(bookmarks.first.startTime, closeTo(10.5, 0.01));
    });

    test('getBookmarkedIndices 返回索引集合', () async {
      final now = DateTime.now();
      for (int i in [2, 5, 8]) {
        await db.bookmarkDao.addBookmark(
          BookmarksCompanion(
            audioItemId: Value('audio-1'),
            sentenceIndex: Value(i),
            sentenceText: Value('Sentence $i'),
            startTime: Value(i * 1.0),
            endTime: Value(i * 1.0 + 1.0),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
      }

      final indices = await db.bookmarkDao.getBookmarkedIndices('audio-1');
      expect(indices, {2, 5, 8});
    });

    test('removeBookmark 移除单个书签', () async {
      final now = DateTime.now();
      await db.bookmarkDao.addBookmark(
        BookmarksCompanion(
          audioItemId: Value('audio-1'),
          sentenceIndex: Value(3),
          sentenceText: Value('Test'),
          startTime: Value(1.0),
          endTime: Value(2.0),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      await db.bookmarkDao.removeBookmark('audio-1', 3);

      final indices = await db.bookmarkDao.getBookmarkedIndices('audio-1');
      expect(indices, isEmpty);
    });

    test('removeBookmarks 批量移除', () async {
      final now = DateTime.now();
      for (int i = 0; i < 5; i++) {
        await db.bookmarkDao.addBookmark(
          BookmarksCompanion(
            audioItemId: Value('audio-1'),
            sentenceIndex: Value(i),
            sentenceText: Value('Sentence $i'),
            startTime: Value(i * 1.0),
            endTime: Value(i * 1.0 + 1.0),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
      }

      await db.bookmarkDao.removeBookmarks('audio-1', {1, 3});

      final indices = await db.bookmarkDao.getBookmarkedIndices('audio-1');
      expect(indices, {0, 2, 4});
    });

    test('addBookmark 相同 audioItemId+sentenceIndex 执行 upsert', () async {
      final now = DateTime.now();
      // 第一次插入
      await db.bookmarkDao.addBookmark(
        BookmarksCompanion(
          audioItemId: Value('audio-1'),
          sentenceIndex: Value(5),
          sentenceText: Value('Hello'),
          startTime: Value(10.0),
          endTime: Value(12.0),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      // 相同 key，不同 text
      await db.bookmarkDao.addBookmark(
        BookmarksCompanion(
          audioItemId: Value('audio-1'),
          sentenceIndex: Value(5),
          sentenceText: Value('Updated'),
          startTime: Value(10.0),
          endTime: Value(12.0),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      final bookmarks = await db.bookmarkDao.getByAudioId('audio-1');
      expect(bookmarks.length, 1);
      expect(bookmarks.first.sentenceText, 'Updated');
    });

    test('getDeletedBookmarks 返回已软删除的书签', () async {
      final now = DateTime.now();
      // 添加 3 个书签
      for (int i = 0; i < 3; i++) {
        await db.bookmarkDao.addBookmark(
          BookmarksCompanion(
            audioItemId: Value('audio-1'),
            sentenceIndex: Value(i),
            sentenceText: Value('Sentence $i'),
            startTime: Value(i * 1.0),
            endTime: Value(i * 1.0 + 1.0),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
      }

      // 软删除其中 2 个
      await db.bookmarkDao.removeBookmark('audio-1', 0);
      await db.bookmarkDao.removeBookmark('audio-1', 2);

      final deleted = await db.bookmarkDao.getDeletedBookmarks(
        sortMode: RecycleBinSortMode.timeDesc,
      );
      expect(deleted.length, 2);
      expect(deleted.map((d) => d.bookmark.sentenceIndex).toSet(), {0, 2});
      expect(deleted.first.audioName, 'Audio 1');
    });

    test('restoreBookmark 恢复已软删除的书签', () async {
      final now = DateTime.now();
      await db.bookmarkDao.addBookmark(
        BookmarksCompanion(
          audioItemId: Value('audio-1'),
          sentenceIndex: Value(0),
          sentenceText: Value('Test'),
          startTime: Value(0.0),
          endTime: Value(1.0),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      await db.bookmarkDao.removeBookmark('audio-1', 0);
      expect(await db.bookmarkDao.getBookmarkedIndices('audio-1'), isEmpty);

      await db.bookmarkDao.restoreBookmark('audio-1', 0);
      expect(await db.bookmarkDao.getBookmarkedIndices('audio-1'), {0});
    });

    test('permanentlyDeleteBookmark 物理删除书签', () async {
      final now = DateTime.now();
      await db.bookmarkDao.addBookmark(
        BookmarksCompanion(
          audioItemId: Value('audio-1'),
          sentenceIndex: Value(0),
          sentenceText: Value('Test'),
          startTime: Value(0.0),
          endTime: Value(1.0),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      await db.bookmarkDao.removeBookmark('audio-1', 0);
      await db.bookmarkDao.permanentlyDeleteBookmark('audio-1', 0);

      // 恢复后也查不到了（已物理删除）
      await db.bookmarkDao.restoreBookmark('audio-1', 0);
      expect(await db.bookmarkDao.getBookmarkedIndices('audio-1'), isEmpty);
    });

    test('permanentlyDeleteAllDeleted 清空回收站', () async {
      final now = DateTime.now();
      for (int i = 0; i < 3; i++) {
        await db.bookmarkDao.addBookmark(
          BookmarksCompanion(
            audioItemId: Value('audio-1'),
            sentenceIndex: Value(i),
            sentenceText: Value('Sentence $i'),
            startTime: Value(i * 1.0),
            endTime: Value(i * 1.0 + 1.0),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
      }

      // 软删除 2 个，保留 1 个
      await db.bookmarkDao.removeBookmark('audio-1', 0);
      await db.bookmarkDao.removeBookmark('audio-1', 2);

      await db.bookmarkDao.permanentlyDeleteAllDeleted();

      // 回收站为空
      final deleted = await db.bookmarkDao.getDeletedBookmarks(
        sortMode: RecycleBinSortMode.timeDesc,
      );
      expect(deleted, isEmpty);

      // 未删除的书签仍在
      expect(await db.bookmarkDao.getBookmarkedIndices('audio-1'), {1});
    });

    test('CASCADE 删除：音频删除后书签自动清理', () async {
      final now = DateTime.now();
      await db.bookmarkDao.addBookmark(
        BookmarksCompanion(
          audioItemId: Value('audio-1'),
          sentenceIndex: Value(0),
          sentenceText: Value('Test'),
          startTime: Value(0.0),
          endTime: Value(1.0),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      await db.audioItemDao.hardDelete('audio-1');

      final bookmarks = await db.bookmarkDao.getByAudioId('audio-1');
      expect(bookmarks, isEmpty);
    });
  });

  group('PlaybackStateDao', () {
    setUp(() async {
      final now = DateTime.now();
      await db.audioItemDao.upsert(
        AudioItemsCompanion(
          id: Value('audio-1'),
          name: Value('Audio 1'),
          audioPath: Value('audios/1.mp3'),
          addedDate: Value(now),
          updatedAt: Value(now),
        ),
      );
    });

    test('保存并查询播放状态', () async {
      await db.playbackStateDao.saveState(
        PlaybackStatesCompanion(
          audioItemId: Value('audio-1'),
          positionMs: Value(5000),
          playlistMode: Value(0),
          savedAt: Value(DateTime.now()),
        ),
      );

      final state = await db.playbackStateDao.getByAudioId('audio-1');
      expect(state, isNotNull);
      expect(state!.positionMs, 5000);
      expect(state.playlistMode, 0);
    });

    test('saveState 更新已存在的播放状态', () async {
      await db.playbackStateDao.saveState(
        PlaybackStatesCompanion(
          audioItemId: Value('audio-1'),
          positionMs: Value(1000),
          playlistMode: Value(0),
          savedAt: Value(DateTime.now()),
        ),
      );

      await db.playbackStateDao.saveState(
        PlaybackStatesCompanion(
          audioItemId: Value('audio-1'),
          positionMs: Value(9000),
          playlistMode: Value(1),
          savedAt: Value(DateTime.now()),
        ),
      );

      final state = await db.playbackStateDao.getByAudioId('audio-1');
      expect(state!.positionMs, 9000);
      expect(state.playlistMode, 1);
    });

    test('clearState 清除播放状态', () async {
      await db.playbackStateDao.saveState(
        PlaybackStatesCompanion(
          audioItemId: Value('audio-1'),
          positionMs: Value(5000),
          playlistMode: Value(0),
          savedAt: Value(DateTime.now()),
        ),
      );

      await db.playbackStateDao.clearState('audio-1');

      final state = await db.playbackStateDao.getByAudioId('audio-1');
      expect(state, isNull);
    });

    test('CASCADE 删除：音频删除后播放状态自动清理', () async {
      await db.playbackStateDao.saveState(
        PlaybackStatesCompanion(
          audioItemId: Value('audio-1'),
          positionMs: Value(5000),
          playlistMode: Value(0),
          savedAt: Value(DateTime.now()),
        ),
      );

      await db.audioItemDao.hardDelete('audio-1');

      final state = await db.playbackStateDao.getByAudioId('audio-1');
      expect(state, isNull);
    });
  });
}
