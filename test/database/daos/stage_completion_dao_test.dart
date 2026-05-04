import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echo_loop/database/app_database.dart';
import 'package:echo_loop/database/daos/stage_completion_dao.dart';

/// 创建内存数据库用于测试（启用外键约束）
AppDatabase _createTestDatabase() {
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
    db = _createTestDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  /// 插入测试用音频项
  Future<void> insertAudio(String id, String name) async {
    final now = DateTime.now();
    await db.audioItemDao.upsert(
      AudioItemsCompanion(
        id: Value(id),
        name: Value(name),
        audioPath: Value('audios/$id.mp3'),
        addedDate: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  /// 插入一条步骤完成记录
  Future<void> insertCompletion({
    required String audioId,
    required String stage,
    required String subStage,
    required DateTime completedAt,
    int durationMs = 1000,
  }) async {
    await db.stageCompletionDao.insertRecord(
      StageCompletionsCompanion(
        audioItemId: Value(audioId),
        stage: Value(stage),
        subStage: Value(subStage),
        completedAt: Value(completedAt),
        durationMs: Value(durationMs),
      ),
    );
  }

  group('StageCompletionDao — getRecentCompletions', () {
    test('返回 since 之后的完成记录（含音频名称）', () async {
      await insertAudio('a1', 'Audio One');
      final now = DateTime(2026, 3, 25, 12, 0);
      await insertCompletion(
        audioId: 'a1',
        stage: 'firstLearn',
        subStage: 'blindListen',
        completedAt: now.subtract(const Duration(hours: 2)),
      );

      final results = await db.stageCompletionDao.getRecentCompletions(
        now.subtract(const Duration(hours: 24)),
      );

      expect(results, hasLength(1));
      expect(results.first.audioName, 'Audio One');
      expect(results.first.stage, 'firstLearn');
      expect(results.first.subStage, 'blindListen');
    });

    test('不返回 since 之前的记录', () async {
      await insertAudio('a1', 'Audio One');
      final now = DateTime(2026, 3, 25, 12, 0);
      await insertCompletion(
        audioId: 'a1',
        stage: 'firstLearn',
        subStage: 'blindListen',
        completedAt: now.subtract(const Duration(hours: 25)),
      );

      final results = await db.stageCompletionDao.getRecentCompletions(
        now.subtract(const Duration(hours: 24)),
      );

      expect(results, isEmpty);
    });

    test('按完成时间倒序排列', () async {
      await insertAudio('a1', 'Audio One');
      await insertAudio('a2', 'Audio Two');
      final now = DateTime(2026, 3, 25, 12, 0);

      await insertCompletion(
        audioId: 'a1',
        stage: 'firstLearn',
        subStage: 'blindListen',
        completedAt: now.subtract(const Duration(hours: 3)),
      );
      await insertCompletion(
        audioId: 'a2',
        stage: 'review0',
        subStage: 'intensiveListen',
        completedAt: now.subtract(const Duration(hours: 1)),
      );

      final results = await db.stageCompletionDao.getRecentCompletions(
        now.subtract(const Duration(hours: 24)),
      );

      expect(results, hasLength(2));
      expect(results[0].audioName, 'Audio Two');
      expect(results[1].audioName, 'Audio One');
    });

    test('无记录时返回空列表', () async {
      final now = DateTime(2026, 3, 25, 12, 0);
      final results = await db.stageCompletionDao.getRecentCompletions(
        now.subtract(const Duration(hours: 24)),
      );

      expect(results, isEmpty);
    });

    test('多条记录含正确的 durationMs', () async {
      await insertAudio('a1', 'Audio One');
      final now = DateTime(2026, 3, 25, 12, 0);

      await insertCompletion(
        audioId: 'a1',
        stage: 'firstLearn',
        subStage: 'blindListen',
        completedAt: now.subtract(const Duration(hours: 1)),
        durationMs: 5000,
      );

      final results = await db.stageCompletionDao.getRecentCompletions(
        now.subtract(const Duration(hours: 24)),
      );

      expect(results.first.durationMs, 5000);
    });
  });
}
