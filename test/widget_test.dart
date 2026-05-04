/// App 冒烟测试
///
/// 验证 App 能正常启动并显示首页。
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:echo_loop/database/app_database.dart';
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/features/onboarding_survey/providers/onboarding_survey_provider.dart';
import 'package:echo_loop/main.dart';
import 'package:echo_loop/providers/new_user_guide_provider.dart';
import 'package:echo_loop/providers/settings_provider.dart';
import 'package:echo_loop/providers/audio_library_provider.dart';
import 'package:echo_loop/providers/collection_provider.dart';
import 'package:echo_loop/providers/tag_provider.dart';
import 'package:echo_loop/providers/listening_practice/listening_practice_provider.dart';
import 'package:echo_loop/providers/audio_engine/audio_engine_provider.dart';
import 'package:echo_loop/providers/learning_progress_provider.dart';
import 'package:echo_loop/providers/package_info_provider.dart';

import 'helpers/mock_providers.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    final packageInfo = PackageInfo(
      appName: 'Fluency',
      packageName: 'top.echo-loop',
      version: '1.0.0',
      buildNumber: '1',
    );

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isFirstLaunchProvider.overrideWithValue(false),
          sharedPreferencesProvider.overrideWithValue(prefs),
          initialOnboardingCompletedProvider.overrideWithValue(true),
          appSettingsProvider.overrideWith(() => TestAppSettings()),
          audioLibraryProvider.overrideWith(() => TestAudioLibrary()),
          collectionListProvider.overrideWith(() => TestCollectionList()),
          tagListProvider.overrideWith(() => TestTagList()),
          listeningPracticeProvider.overrideWith(() => TestListeningPractice()),
          audioEngineProvider.overrideWith(() => TestAudioEngine()),
          learningProgressNotifierProvider.overrideWith(
            () => TestLearningProgressNotifier(),
          ),
          packageInfoProvider.overrideWithValue(packageInfo),
          analyticsOverride(),
          appDatabaseProvider.overrideWithValue(
            AppDatabase(
              NativeDatabase.memory(
                setup: (db) => db.execute('PRAGMA foreign_keys = ON'),
              ),
            ),
          ),
        ],
        child: const FluencyApp(),
      ),
    );
    // pump 足够帧数让 UI 渲染完成
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 验证 App 正常加载 — 默认显示学习任务页空状态
    expect(find.text('No study tasks yet'), findsOneWidget);

    // 消耗冷启动保护定时器（5 秒），避免 pending timer 断言失败
    await tester.pump(const Duration(seconds: 6));
  });
}
