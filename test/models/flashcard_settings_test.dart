/// FlashcardSettings 模型测试
///
/// 覆盖 copyWith / toJson / fromJson / 边界值 / 智能算法。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:fluency/models/flashcard_settings.dart';

void main() {
  group('FlashcardSettings', () {
    test('默认值正确', () {
      const settings = FlashcardSettings();
      expect(settings.timerMode, FlashcardTimerMode.fixed);
      expect(settings.fixedTimerSeconds, 8);
      expect(settings.sortMode, FlashcardSortMode.random);
      expect(settings.autoPlaySentence, true);
      expect(settings.autoPlayWord, true);
    });

    test('copyWith 替换指定字段', () {
      const settings = FlashcardSettings();
      final updated = settings.copyWith(
        timerMode: FlashcardTimerMode.smart,
        fixedTimerSeconds: 15,
        sortMode: FlashcardSortMode.alphabeticalAsc,
      );
      expect(updated.timerMode, FlashcardTimerMode.smart);
      expect(updated.fixedTimerSeconds, 15);
      expect(updated.sortMode, FlashcardSortMode.alphabeticalAsc);
    });

    test('copyWith 不传参保持原值', () {
      final settings = const FlashcardSettings(
        timerMode: FlashcardTimerMode.off,
        fixedTimerSeconds: 20,
        sortMode: FlashcardSortMode.smart,
      ).copyWith();
      expect(settings.timerMode, FlashcardTimerMode.off);
      expect(settings.fixedTimerSeconds, 20);
      expect(settings.sortMode, FlashcardSortMode.smart);
    });

    test('toJson → fromJson 往返一致', () {
      const original = FlashcardSettings(
        timerMode: FlashcardTimerMode.smart,
        fixedTimerSeconds: 10,
        sortMode: FlashcardSortMode.timeDesc,
        autoPlaySentence: false,
        autoPlayWord: false,
      );
      final json = original.toJson();
      final restored = FlashcardSettings.fromJson(json);
      expect(restored.timerMode, original.timerMode);
      expect(restored.fixedTimerSeconds, original.fixedTimerSeconds);
      expect(restored.sortMode, original.sortMode);
      expect(restored.autoPlaySentence, original.autoPlaySentence);
      expect(restored.autoPlayWord, original.autoPlayWord);
    });

    test('fromJson 空 Map 返回默认值', () {
      final settings = FlashcardSettings.fromJson({});
      expect(settings.timerMode, FlashcardTimerMode.fixed);
      expect(settings.fixedTimerSeconds, 8);
      expect(settings.sortMode, FlashcardSortMode.random);
      expect(settings.autoPlaySentence, true);
      expect(settings.autoPlayWord, true);
    });

    test('fromJson 非法值回退默认', () {
      final settings = FlashcardSettings.fromJson({
        'timerMode': 'invalid',
        'fixedTimerSeconds': 999,
        'sortMode': 42,
      });
      expect(settings.timerMode, FlashcardTimerMode.fixed);
      expect(settings.fixedTimerSeconds, 8);
      expect(settings.sortMode, FlashcardSortMode.random);
    });

    test('fromJson 类型错误回退默认', () {
      final settings = FlashcardSettings.fromJson({
        'timerMode': 123,
        'fixedTimerSeconds': 'abc',
        'sortMode': true,
      });
      expect(settings.timerMode, FlashcardTimerMode.fixed);
      expect(settings.fixedTimerSeconds, 8);
      expect(settings.sortMode, FlashcardSortMode.random);
    });
  });

  group('calculateSmartSeconds', () {
    test('短词首次学习 → 5s', () {
      final s = FlashcardSettings.calculateSmartSeconds(
        wordLength: 3,
        practiceCount: 0,
      );
      expect(s, 5);
    });

    test('长词首次学习 → 10s', () {
      final s = FlashcardSettings.calculateSmartSeconds(
        wordLength: 13,
        practiceCount: 0,
      );
      expect(s, 10);
    });

    test('短词练习 5 次 → 2s', () {
      final s = FlashcardSettings.calculateSmartSeconds(
        wordLength: 3,
        practiceCount: 5,
      );
      expect(s, 2);
    });

    test('长词练习 5 次 → 5s', () {
      final s = FlashcardSettings.calculateSmartSeconds(
        wordLength: 13,
        practiceCount: 5,
      );
      expect(s, 5);
    });

    test('中等词首次 → 约 8s', () {
      final s = FlashcardSettings.calculateSmartSeconds(
        wordLength: 8,
        practiceCount: 0,
      );
      // ratio = (8-4)/(12-4) = 0.5, maxTime = 7.5, minTime = 3.5
      // decay = 0, result = 7.5 → rounds to 8
      expect(s, 8);
    });

    test('中等词练习 5 次 → 约 4s', () {
      final s = FlashcardSettings.calculateSmartSeconds(
        wordLength: 8,
        practiceCount: 5,
      );
      // ratio = 0.5, maxTime = 7.5, minTime = 3.5
      // decay = 1.0, result = 7.5 - 1.0*(7.5-3.5) = 3.5 → rounds to 4
      expect(s, 4);
    });

    test('超短词 clamp 到 0 ratio', () {
      final s = FlashcardSettings.calculateSmartSeconds(
        wordLength: 1,
        practiceCount: 0,
      );
      expect(s, 5);
    });

    test('超长词 clamp 到 1 ratio', () {
      final s = FlashcardSettings.calculateSmartSeconds(
        wordLength: 20,
        practiceCount: 0,
      );
      expect(s, 10);
    });
  });

  group('calculateSmartScore', () {
    test('首次未练习得分最高', () {
      final score = FlashcardSettings.calculateSmartScore(
        practiceCount: 0,
        viewedBack: false,
        lastPracticedAt: null,
      );
      // 0 + 0 + 10080/60 = 168
      expect(score, closeTo(168.0, 0.1));
    });

    test('练习多次得分降低', () {
      final score = FlashcardSettings.calculateSmartScore(
        practiceCount: 5,
        viewedBack: true,
        lastPracticedAt: DateTime.now(),
      );
      // -50 -5 + 0/60 = -55
      expect(score, closeTo(-55.0, 0.1));
    });

    test('viewedBack 降低 5 分', () {
      final scoreNoView = FlashcardSettings.calculateSmartScore(
        practiceCount: 0,
        viewedBack: false,
        lastPracticedAt: DateTime.now(),
      );
      final scoreViewed = FlashcardSettings.calculateSmartScore(
        practiceCount: 0,
        viewedBack: true,
        lastPracticedAt: DateTime.now(),
      );
      expect(scoreNoView - scoreViewed, closeTo(5.0, 0.1));
    });
  });
}
