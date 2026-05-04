import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/database/app_database.dart';
import 'package:echo_loop/database/daos/daily_study_record_dao.dart';

AppDatabase _createTestDb() {
  return AppDatabase(
    NativeDatabase.memory(
      setup: (db) => db.execute('PRAGMA foreign_keys = ON'),
    ),
  );
}

void main() {
  late AppDatabase db;
  late DailyStudyRecordDao dao;

  setUp(() {
    db = _createTestDb();
    dao = db.dailyStudyRecordDao;
  });

  tearDown(() async {
    await db.close();
  });

  group('DailyStudyRecordDao - upsertAdd', () {
    test('首次插入创建新行', () async {
      final date = DateTime(2026, 3, 10);
      await dao.upsertAdd(date, studyTime: 60);

      final record = await dao.getByDate(date);
      expect(record, isNotNull);
      expect(record!.studyTimeSeconds, 60);
      expect(record.inputWords, 0);
    });

    test('重复日期累加', () async {
      final date = DateTime(2026, 3, 10);
      await dao.upsertAdd(date, studyTime: 30);
      await dao.upsertAdd(date, studyTime: 45);

      final record = await dao.getByDate(date);
      expect(record!.studyTimeSeconds, 75);
    });

    test('多字段同时累加', () async {
      final date = DateTime(2026, 3, 10);
      await dao.upsertAdd(
        date,
        studyTime: 60,
        inputWords: 100,
        outputWords: 50,
        inputTime: 30,
        outputTime: 20,
      );
      await dao.upsertAdd(
        date,
        inputWords: 50,
        outputTime: 10,
      );

      final record = await dao.getByDate(date);
      expect(record!.studyTimeSeconds, 60);
      expect(record.inputWords, 150);
      expect(record.outputWords, 50);
      expect(record.inputTimeSeconds, 30);
      expect(record.outputTimeSeconds, 30);
    });

    test('不同日期互不干扰', () async {
      final day1 = DateTime(2026, 3, 10);
      final day2 = DateTime(2026, 3, 11);

      await dao.upsertAdd(day1, studyTime: 100);
      await dao.upsertAdd(day2, studyTime: 200);

      expect((await dao.getByDate(day1))!.studyTimeSeconds, 100);
      expect((await dao.getByDate(day2))!.studyTimeSeconds, 200);
    });
  });

  group('DailyStudyRecordDao - getByDate', () {
    test('不存在时返回 null', () async {
      final record = await dao.getByDate(DateTime(2026, 1, 1));
      expect(record, isNull);
    });
  });

  group('DailyStudyRecordDao - getBetween', () {
    test('返回范围内的记录', () async {
      await dao.upsertAdd(DateTime(2026, 3, 5), studyTime: 10);
      await dao.upsertAdd(DateTime(2026, 3, 6), studyTime: 20);
      await dao.upsertAdd(DateTime(2026, 3, 7), studyTime: 30);
      await dao.upsertAdd(DateTime(2026, 3, 8), studyTime: 40);

      final records = await dao.getBetween(
        DateTime(2026, 3, 6),
        DateTime(2026, 3, 7),
      );
      expect(records.length, 2);
      expect(records[0].studyTimeSeconds, 20);
      expect(records[1].studyTimeSeconds, 30);
    });

    test('范围外的记录不包含', () async {
      await dao.upsertAdd(DateTime(2026, 3, 1), studyTime: 999);
      await dao.upsertAdd(DateTime(2026, 3, 10), studyTime: 999);
      await dao.upsertAdd(DateTime(2026, 3, 5), studyTime: 42);

      final records = await dao.getBetween(
        DateTime(2026, 3, 4),
        DateTime(2026, 3, 6),
      );
      expect(records.length, 1);
      expect(records[0].studyTimeSeconds, 42);
    });

    test('按日期升序排列', () async {
      await dao.upsertAdd(DateTime(2026, 3, 8), studyTime: 80);
      await dao.upsertAdd(DateTime(2026, 3, 6), studyTime: 60);
      await dao.upsertAdd(DateTime(2026, 3, 7), studyTime: 70);

      final records = await dao.getBetween(
        DateTime(2026, 3, 6),
        DateTime(2026, 3, 8),
      );
      expect(records.map((r) => r.studyTimeSeconds).toList(), [60, 70, 80]);
    });
  });

  group('DailyStudyRecordDao - getStreak', () {
    test('无记录时返回 0', () async {
      expect(await dao.getStreak(now: DateTime(2026, 3, 8)), 0);
    });

    test('仅今天有记录返回 1', () async {
      await dao.upsertAdd(DateTime(2026, 3, 8), studyTime: 60);
      expect(await dao.getStreak(now: DateTime(2026, 3, 8)), 1);
    });

    test('连续 3 天返回 3', () async {
      await dao.upsertAdd(DateTime(2026, 3, 6), studyTime: 60);
      await dao.upsertAdd(DateTime(2026, 3, 7), studyTime: 60);
      await dao.upsertAdd(DateTime(2026, 3, 8), studyTime: 60);
      expect(await dao.getStreak(now: DateTime(2026, 3, 8)), 3);
    });

    test('中间断一天则中断', () async {
      await dao.upsertAdd(DateTime(2026, 3, 5), studyTime: 60);
      // 3月6日无记录
      await dao.upsertAdd(DateTime(2026, 3, 7), studyTime: 60);
      await dao.upsertAdd(DateTime(2026, 3, 8), studyTime: 60);
      expect(await dao.getStreak(now: DateTime(2026, 3, 8)), 2);
    });

    test('今天无记录但昨天有', () async {
      await dao.upsertAdd(DateTime(2026, 3, 6), studyTime: 60);
      await dao.upsertAdd(DateTime(2026, 3, 7), studyTime: 60);
      expect(await dao.getStreak(now: DateTime(2026, 3, 8)), 2);
    });

    test('studyTimeSeconds 为 0 不算有记录', () async {
      await dao.upsertAdd(DateTime(2026, 3, 7), inputWords: 100);
      await dao.upsertAdd(DateTime(2026, 3, 8), studyTime: 60);
      // 3月7日 studyTimeSeconds=0，streak 中断
      expect(await dao.getStreak(now: DateTime(2026, 3, 8)), 1);
    });
  });
}
