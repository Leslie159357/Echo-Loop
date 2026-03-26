import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:fluency/database/app_database.dart';
import 'package:fluency/database/providers.dart';
import 'package:fluency/l10n/app_localizations.dart';
import 'package:fluency/providers/monthly_study_records_provider.dart';
import 'package:fluency/providers/study_stats_provider.dart';
import 'package:fluency/screens/activity_calendar_screen.dart';
import 'package:fluency/services/study_time_service.dart';
import 'package:fluency/theme/app_theme.dart';

AppDatabase _createTestDb() {
  return AppDatabase(
    NativeDatabase.memory(
      setup: (db) => db.execute('PRAGMA foreign_keys = ON'),
    ),
  );
}

/// 创建包含日历页面的测试 App
Widget _createTestApp({
  required AppDatabase db,
  Map<int, MonthDayRecord>? records,
  StudyStats stats = const StudyStats(),
}) {
  final now = DateTime.now();
  final overrides = <Override>[
    appDatabaseProvider.overrideWithValue(db),
    studyStatsNotifierProvider.overrideWith(
      () => _TestStudyStatsNotifier(stats),
    ),
  ];

  // 如果提供了 records，覆盖 provider
  if (records != null) {
    overrides.add(
      monthlyStudyRecordsProvider(now.year, now.month).overrideWith(
        (ref) async => records,
      ),
    );
  }

  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('en'),
      supportedLocales: const [Locale('en'), Locale('zh')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const ActivityCalendarScreen(),
    ),
  );
}

/// 测试用 StudyStatsNotifier
class _TestStudyStatsNotifier extends StudyStatsNotifier {
  final StudyStats _stats;
  _TestStudyStatsNotifier(this._stats);

  @override
  Future<StudyStats> build() async => _stats;
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = _createTestDb();
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('日历页面正确渲染', (tester) async {
    await tester.pumpWidget(_createTestApp(
      db: db,
      records: const {},
    ));
    await tester.pumpAndSettle();

    // 页面标题
    expect(find.text('Activity Calendar'), findsOneWidget);

    // streak chip 显示 0d
    expect(find.text('0d streak'), findsOneWidget);
  });

  testWidgets('streak>0 时显示橙色 chip', (tester) async {
    await tester.pumpWidget(_createTestApp(
      db: db,
      records: const {},
      stats: const StudyStats(streak: 5),
    ));
    await tester.pumpAndSettle();

    expect(find.text('5d streak'), findsOneWidget);

    // 验证火焰图标存在
    expect(
      find.byIcon(Icons.local_fire_department_rounded),
      findsOneWidget,
    );
  });

  testWidgets('有活动的日期显示迷你条', (tester) async {
    final now = DateTime.now();
    await tester.pumpWidget(_createTestApp(
      db: db,
      records: {
        now.day: const MonthDayRecord(
          studyTimeSeconds: 1800,
          inputTimeSeconds: 900,
          outputTimeSeconds: 600,
        ),
      },
    ));
    await tester.pumpAndSettle();

    // 今天的日期数字应该存在
    expect(find.text('${now.day}'), findsWidgets);
  });

  testWidgets('月度摘要卡片显示正确标签', (tester) async {
    final now = DateTime.now();
    await tester.pumpWidget(_createTestApp(
      db: db,
      records: {
        now.day: const MonthDayRecord(
          studyTimeSeconds: 3600,
          inputTimeSeconds: 1800,
          outputTimeSeconds: 1200,
        ),
      },
    ));
    await tester.pumpAndSettle();

    // 摘要卡片标签
    expect(find.text('Total'), findsOneWidget);
    expect(find.text('Active days'), findsOneWidget);
    expect(find.text('Avg/day'), findsOneWidget);
    expect(find.text('Best streak'), findsOneWidget);
  });

  testWidgets('空月份显示提示文案（含 offstage）', (tester) async {
    // 增加窗口高度以确保日历下方内容可见
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_createTestApp(
      db: db,
      records: const {},
    ));
    await tester.pumpAndSettle();

    // 即使文本可能被滚动隐藏，也应该存在于 widget 树中
    expect(
      find.text('No learning activity this month', skipOffstage: false),
      findsOneWidget,
    );
  });
}
