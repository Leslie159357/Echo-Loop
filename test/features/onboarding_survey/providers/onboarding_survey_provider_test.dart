import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/features/onboarding_survey/data/onboarding_survey_storage.dart';
import 'package:echo_loop/features/onboarding_survey/models/onboarding_answers.dart';
import 'package:echo_loop/features/onboarding_survey/models/onboarding_question.dart';
import 'package:echo_loop/features/onboarding_survey/providers/onboarding_survey_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

ProviderContainer _makeContainer({
  required bool initialOnboardingCompleted,
  required SharedPreferences prefs,
}) {
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      initialOnboardingCompletedProvider.overrideWithValue(
        initialOnboardingCompleted,
      ),
    ],
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('shouldShowSurveyProvider', () {
    test('未完成 → true（无论老用户还是新用户都弹一次）', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = _makeContainer(
        initialOnboardingCompleted: false,
        prefs: prefs,
      );
      addTearDown(container.dispose);
      expect(container.read(shouldShowSurveyProvider), isTrue);
    });

    test('已完成 → false', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = _makeContainer(
        initialOnboardingCompleted: true,
        prefs: prefs,
      );
      addTearDown(container.dispose);
      expect(container.read(shouldShowSurveyProvider), isFalse);
    });

    test('完成后 shouldShowSurveyProvider 立即变 false', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = _makeContainer(
        initialOnboardingCompleted: false,
        prefs: prefs,
      );
      addTearDown(container.dispose);

      expect(container.read(shouldShowSurveyProvider), isTrue);
      container.read(onboardingCompletedProvider.notifier).markCompleted();
      expect(container.read(shouldShowSurveyProvider), isFalse);
    });
  });

  group('OnboardingAnswersNotifier', () {
    test('每次 setAnswer 累积答案', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = _makeContainer(
        initialOnboardingCompleted: false,
        prefs: prefs,
      );
      addTearDown(container.dispose);
      final notifier = container.read(onboardingAnswersProvider.notifier);

      notifier.setGoal(OnboardingGoal.work);
      expect(
        container.read(onboardingAnswersProvider),
        equals(const OnboardingAnswers(goal: OnboardingGoal.work)),
      );

      notifier.setDailyMinutes(OnboardingDailyMinutes.flexible);
      expect(
        container.read(onboardingAnswersProvider),
        equals(
          const OnboardingAnswers(
            goal: OnboardingGoal.work,
            dailyMinutes: OnboardingDailyMinutes.flexible,
          ),
        ),
      );
    });

    test('setGoal 切换分支时自动清掉旧分支副字段', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = _makeContainer(
        initialOnboardingCompleted: false,
        prefs: prefs,
      );
      addTearDown(container.dispose);
      final notifier = container.read(onboardingAnswersProvider.notifier);

      notifier.setGoal(OnboardingGoal.exam);
      notifier.setExamType(OnboardingExamType.ielts);
      expect(
        container.read(onboardingAnswersProvider).examType,
        equals(OnboardingExamType.ielts),
      );

      // 切到 daily：examType 应被清掉
      notifier.setGoal(OnboardingGoal.daily);
      expect(container.read(onboardingAnswersProvider).examType, isNull);

      // 切换普通分支：goalOtherText 历史字段应保持清空
      notifier.setGoal(OnboardingGoal.other);
      expect(container.read(onboardingAnswersProvider).goalOtherText, isNull);
      notifier.setGoal(OnboardingGoal.work);
      expect(
        container.read(onboardingAnswersProvider).goalOtherText,
        isNull,
      );
    });

    test('submit 写 SP + 翻转完成态', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = _makeContainer(
        initialOnboardingCompleted: false,
        prefs: prefs,
      );
      addTearDown(container.dispose);
      final notifier = container.read(onboardingAnswersProvider.notifier);
      notifier.setGoal(OnboardingGoal.exam);
      notifier.setExamType(OnboardingExamType.ielts);
      notifier.setDailyMinutes(OnboardingDailyMinutes.m20);

      await notifier.submit();

      expect(container.read(onboardingCompletedProvider), isTrue);

      final storage = OnboardingSurveyStorage(prefs);
      expect(storage.isCompleted, isTrue);
      expect(storage.loadAnswers()?.goal, equals(OnboardingGoal.exam));
      expect(
        storage.loadAnswers()?.examType,
        equals(OnboardingExamType.ielts),
      );
      expect(
        storage.loadAnswers()?.dailyMinutes,
        equals(OnboardingDailyMinutes.m20),
      );
    });

    test('未完成时 submit 抛 StateError', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = _makeContainer(
        initialOnboardingCompleted: false,
        prefs: prefs,
      );
      addTearDown(container.dispose);
      final notifier = container.read(onboardingAnswersProvider.notifier);
      notifier.setGoal(OnboardingGoal.daily);
      // 没设 dailyMinutes
      expect(notifier.submit, throwsStateError);
    });
  });

  group('OnboardingCompletedNotifier', () {
    test('初值来自 initialOnboardingCompletedProvider', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = _makeContainer(
        initialOnboardingCompleted: true,
        prefs: prefs,
      );
      addTearDown(container.dispose);
      expect(container.read(onboardingCompletedProvider), isTrue);
    });

    test('markCompleted 幂等', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = _makeContainer(
        initialOnboardingCompleted: false,
        prefs: prefs,
      );
      addTearDown(container.dispose);
      final notifier = container.read(onboardingCompletedProvider.notifier);
      notifier.markCompleted();
      notifier.markCompleted();
      notifier.markCompleted();
      expect(container.read(onboardingCompletedProvider), isTrue);
    });
  });
}
