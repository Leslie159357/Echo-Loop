import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:echo_loop/database/app_database.dart';
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/providers/study_stats_provider.dart';
import 'package:echo_loop/services/study_time_service.dart';

AppDatabase _createTestDb() {
  return AppDatabase(
    NativeDatabase.memory(
      setup: (db) => db.execute('PRAGMA foreign_keys = ON'),
    ),
  );
}

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = _createTestDb();
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('StudyStatsNotifier 聚合已学习词形统计', () async {
    final now = DateTime.now();
    final service = StudyTimeService(db.dailyStudyRecordDao, db.dailyStageStudyRecordDao);
    await service.addStudyTime(1800, date: now);
    await service.addInputWords(42, date: now);
    await service.addOutputWords(21, date: now);
    await db.learnedWordFormDao.insertIfAbsentAll({
      'child': now,
      'children': now,
      'run': now.subtract(const Duration(days: 1)),
    });

    final stats = await container.read(studyStatsNotifierProvider.future);
    expect(stats.todaySeconds, 1800);
    expect(stats.todayInputWords, 42);
    expect(stats.todayOutputWords, 21);
    expect(stats.learnedWordFormCount, 3);
    expect(stats.todayNewWordForms, 2);
  });
}
