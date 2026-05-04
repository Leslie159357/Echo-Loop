import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:echo_loop/features/onboarding_survey/data/onboarding_survey_storage.dart';
import 'package:echo_loop/features/onboarding_survey/models/onboarding_question.dart';
import 'package:echo_loop/features/onboarding_survey/providers/onboarding_survey_provider.dart';
import 'package:echo_loop/features/onboarding_survey/screens/onboarding_survey_screen.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/router/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/mock_providers.dart';

/// 创建一个最小化的可路由测试 App，承载 onboarding 页 + study 占位页。
Widget _wrap({
  required SharedPreferences prefs,
  bool initialOnboardingCompleted = false,
}) {
  final router = GoRouter(
    initialLocation: AppRoutes.onboardingSurvey,
    routes: [
      GoRoute(
        path: AppRoutes.onboardingSurvey,
        builder: (_, __) => const OnboardingSurveyScreen(),
      ),
      GoRoute(
        path: AppRoutes.study,
        builder: (_, __) => const Scaffold(body: Text('STUDY_PLACEHOLDER')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      initialOnboardingCompletedProvider.overrideWithValue(
        initialOnboardingCompleted,
      ),
      analyticsOverride(),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
      locale: const Locale('zh', 'CN'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('普通分支：选目标 → 自动跳时长 → 选时长 → 进入方法论页 → 点开始学习', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_wrap(prefs: prefs));
    await tester.pumpAndSettle();

    expect(find.text('你练习英语听说的主要目标是什么？'), findsOneWidget);

    // 选"工作沟通" → 等待自动前进
    await tester.tap(find.text('工作沟通'));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    // 已切到时长页
    expect(find.text('你计划每天练习多久？'), findsOneWidget);
    expect(find.text('约 20 分钟'), findsOneWidget);

    // 选"不固定" → 自动跳到方法论 summary 页
    await tester.tap(find.text('不固定'));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    // summary 页：headline + 4 要点 + 权限预告 + 开始学习 按钮，仍未提交
    expect(find.textContaining('提升英语听说'), findsOneWidget);
    expect(find.text('选择适合你水平的音频反复练习'), findsOneWidget);
    expect(find.text('通过复述练习口语，把听懂变成会说'), findsOneWidget);
    // 权限预告：纯展示 label，无交互
    expect(find.text('为了保证体验我们将请求以下权限'), findsOneWidget);
    expect(find.text('系统通知'), findsOneWidget);
    expect(find.text('录音'), findsOneWidget);
    expect(find.text('语音识别'), findsOneWidget);
    expect(find.text('开始学习'), findsOneWidget);
    expect(OnboardingSurveyStorage(prefs).isCompleted, isFalse);
    expect(find.text('STUDY_PLACEHOLDER'), findsNothing);

    // 点击"开始学习" → 提交并跳转
    await tester.tap(find.text('开始学习'));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    expect(find.text('STUDY_PLACEHOLDER'), findsOneWidget);

    final storage = OnboardingSurveyStorage(prefs);
    expect(storage.isCompleted, isTrue);
    final answers = storage.loadAnswers();
    expect(answers?.goal, equals(OnboardingGoal.work));
    expect(answers?.dailyMinutes, equals(OnboardingDailyMinutes.flexible));
  });

  testWidgets('考试分支：选应对考试 → 二级考试类型 → 选时长 → summary → 开始学习', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_wrap(prefs: prefs));
    await tester.pumpAndSettle();

    await tester.tap(find.text('应对考试'));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    expect(find.text('你当前在备考哪一类考试？'), findsOneWidget);
    expect(find.text('雅思 IELTS'), findsOneWidget);

    await tester.tap(find.text('雅思 IELTS'));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    expect(find.text('你计划每天练习多久？'), findsOneWidget);

    await tester.tap(find.text('约 20 分钟'));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    expect(find.text('开始学习'), findsOneWidget);
    await tester.tap(find.text('开始学习'));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    expect(find.text('STUDY_PLACEHOLDER'), findsOneWidget);
    final answers = OnboardingSurveyStorage(prefs).loadAnswers();
    expect(answers?.goal, equals(OnboardingGoal.exam));
    expect(answers?.examType, equals(OnboardingExamType.ielts));
    expect(answers?.dailyMinutes, equals(OnboardingDailyMinutes.m20));
  });

  testWidgets('其他分支：选其他 → 自动跳时长 → summary → 开始学习', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_wrap(prefs: prefs));
    await tester.pumpAndSettle();

    await tester.tap(find.text('其他'));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    expect(find.text('你计划每天练习多久？'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('继续'), findsNothing);

    await tester.tap(find.text('约 10 分钟'));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    await tester.tap(find.text('开始学习'));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    expect(find.text('STUDY_PLACEHOLDER'), findsOneWidget);
    final answers = OnboardingSurveyStorage(prefs).loadAnswers();
    expect(answers?.goal, equals(OnboardingGoal.other));
    expect(answers?.goalOtherText, isNull);
    expect(answers?.dailyMinutes, equals(OnboardingDailyMinutes.m10));
  });

  testWidgets('影视播客分支：选听懂影视播客 → 自动跳时长 → summary → 开始学习', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_wrap(prefs: prefs));
    await tester.pumpAndSettle();

    await tester.tap(find.text('听懂影视播客'));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    expect(find.text('你计划每天练习多久？'), findsOneWidget);

    await tester.tap(find.text('约 20 分钟'));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    await tester.tap(find.text('开始学习'));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    expect(find.text('STUDY_PLACEHOLDER'), findsOneWidget);
    final answers = OnboardingSurveyStorage(prefs).loadAnswers();
    expect(answers?.goal, equals(OnboardingGoal.content));
    expect(answers?.dailyMinutes, equals(OnboardingDailyMinutes.m20));
  });

  testWidgets('summary 页可通过"上一步"返回时长页修改答案', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_wrap(prefs: prefs));
    await tester.pumpAndSettle();

    await tester.tap(find.text('日常交流'));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    await tester.tap(find.text('约 10 分钟'));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    expect(find.text('开始学习'), findsOneWidget);
    expect(find.text('上一步'), findsOneWidget);

    await tester.tap(find.text('上一步'));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    expect(find.text('你计划每天练习多久？'), findsOneWidget);
    // 仍未写入完成态
    expect(OnboardingSurveyStorage(prefs).isCompleted, isFalse);
  });

  testWidgets('上一步：从时长页可以回到目标页', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_wrap(prefs: prefs));
    await tester.pumpAndSettle();

    // 第一题不显示上一步
    expect(find.text('上一步'), findsNothing);

    await tester.tap(find.text('日常交流'));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    expect(find.text('你计划每天练习多久？'), findsOneWidget);
    expect(find.text('上一步'), findsOneWidget);

    await tester.tap(find.text('上一步'));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    expect(find.text('你练习英语听说的主要目标是什么？'), findsOneWidget);
  });

  testWidgets('物理返回键被 PopScope 拦截', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_wrap(prefs: prefs));
    await tester.pumpAndSettle();

    // ignore: deprecated_member_use
    await ServicesBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/navigation',
      const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
      (_) {},
    );
    await tester.pumpAndSettle();

    expect(find.text('你练习英语听说的主要目标是什么？'), findsOneWidget);
  });

  testWidgets('无跳过按钮渲染', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_wrap(prefs: prefs));
    await tester.pumpAndSettle();
    expect(find.text('以后再说'), findsNothing);
    expect(find.text('Skip'), findsNothing);
    expect(find.text('Skip for now'), findsNothing);
  });
}
