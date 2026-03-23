import 'package:flutter_test/flutter_test.dart';
import 'package:fluency/analytics/models/event_names.dart';

void main() {
  group('Events 常量', () {
    test('所有事件名不为空', () {
      const events = [
        Events.appOpen,
        Events.appBackground,
        Events.screenView,
        Events.learningStart,
        Events.learningEnd,
        Events.blindListenStart,
        Events.blindListenComplete,
        Events.blindListenDifficultySet,
        Events.intensiveListenStart,
        Events.intensiveListenComplete,
        Events.listenRepeatStart,
        Events.listenRepeatComplete,
        Events.retellStart,
        Events.retellComplete,
        Events.difficultPracticeStart,
        Events.difficultPracticeComplete,
        Events.firstLearnComplete,
        Events.stageAdvance,
      ];

      for (final name in events) {
        expect(name, isNotEmpty, reason: '事件名不能为空');
      }
    });

    test('所有事件名不重复', () {
      const events = [
        Events.appOpen,
        Events.appBackground,
        Events.screenView,
        Events.learningStart,
        Events.learningEnd,
        Events.blindListenStart,
        Events.blindListenComplete,
        Events.blindListenDifficultySet,
        Events.intensiveListenStart,
        Events.intensiveListenComplete,
        Events.listenRepeatStart,
        Events.listenRepeatComplete,
        Events.retellStart,
        Events.retellComplete,
        Events.difficultPracticeStart,
        Events.difficultPracticeComplete,
        Events.firstLearnComplete,
        Events.stageAdvance,
      ];

      final unique = events.toSet();
      expect(unique.length, events.length, reason: '存在重复的事件名');
    });

    test('事件名符合命名规范（小写下划线连接）', () {
      const events = [
        Events.appOpen,
        Events.appBackground,
        Events.screenView,
        Events.learningStart,
        Events.learningEnd,
        Events.blindListenStart,
        Events.blindListenComplete,
        Events.blindListenDifficultySet,
        Events.intensiveListenStart,
        Events.intensiveListenComplete,
        Events.listenRepeatStart,
        Events.listenRepeatComplete,
        Events.retellStart,
        Events.retellComplete,
        Events.difficultPracticeStart,
        Events.difficultPracticeComplete,
        Events.firstLearnComplete,
        Events.stageAdvance,
      ];

      final pattern = RegExp(r'^[a-z][a-z0-9_]*$');
      for (final name in events) {
        expect(pattern.hasMatch(name), isTrue,
            reason: '"$name" 不符合小写下划线命名规范');
      }
    });
  });

  group('EventParams 常量', () {
    test('所有参数名不为空', () {
      const params = [
        EventParams.audioId,
        EventParams.stage,
        EventParams.durationMs,
        EventParams.completed,
        EventParams.isFirstLaunch,
        EventParams.launchType,
        EventParams.foregroundDurationMs,
        EventParams.screenName,
        EventParams.previousScreen,
        EventParams.isFreePractice,
        EventParams.difficulty,
        EventParams.passNumber,
        EventParams.totalSentences,
        EventParams.difficultCount,
        EventParams.avgRating,
        EventParams.totalParagraphs,
        EventParams.totalDurationMs,
        EventParams.fromStage,
        EventParams.toStage,
      ];

      for (final name in params) {
        expect(name, isNotEmpty, reason: '参数名不能为空');
      }
    });

    test('所有参数名不重复', () {
      const params = [
        EventParams.audioId,
        EventParams.stage,
        EventParams.durationMs,
        EventParams.completed,
        EventParams.isFirstLaunch,
        EventParams.launchType,
        EventParams.foregroundDurationMs,
        EventParams.screenName,
        EventParams.previousScreen,
        EventParams.isFreePractice,
        EventParams.difficulty,
        EventParams.passNumber,
        EventParams.totalSentences,
        EventParams.difficultCount,
        EventParams.avgRating,
        EventParams.totalParagraphs,
        EventParams.totalDurationMs,
        EventParams.fromStage,
        EventParams.toStage,
      ];

      final unique = params.toSet();
      expect(unique.length, params.length, reason: '存在重复的参数名');
    });
  });
}
