/// FlashcardSettings 模型测试
///
/// 覆盖 copyWith / toJson / fromJson / 边界值 / 智能算法 / controlMode。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:fluency/models/flashcard_settings.dart';
import 'package:fluency/models/intensive_listen_settings.dart'
    show ShadowingControlMode;

void main() {
  group('FlashcardSettings', () {
    test('默认值正确', () {
      const settings = FlashcardSettings();
      expect(settings.controlMode, ShadowingControlMode.auto);
      expect(settings.timerMode, FlashcardTimerMode.smart);
      expect(settings.fixedTimerSeconds, 5);
      expect(settings.fixedTimerBackSeconds, 10);
      expect(settings.sortMode, FlashcardSortMode.random);
      expect(settings.autoPlaySentence, true);
      expect(settings.autoPlayWord, true);
      expect(settings.isManualMode, false);
    });

    test('copyWith 替换指定字段', () {
      const settings = FlashcardSettings();
      final updated = settings.copyWith(
        controlMode: ShadowingControlMode.manual,
        timerMode: FlashcardTimerMode.fixed,
        fixedTimerSeconds: 15,
        fixedTimerBackSeconds: 10,
        sortMode: FlashcardSortMode.alphabeticalAsc,
      );
      expect(updated.controlMode, ShadowingControlMode.manual);
      expect(updated.timerMode, FlashcardTimerMode.fixed);
      expect(updated.fixedTimerSeconds, 15);
      expect(updated.fixedTimerBackSeconds, 10);
      expect(updated.sortMode, FlashcardSortMode.alphabeticalAsc);
      expect(updated.isManualMode, true);
    });

    test('copyWith 不传参保持原值', () {
      final settings = const FlashcardSettings(
        controlMode: ShadowingControlMode.manual,
        fixedTimerSeconds: 20,
        fixedTimerBackSeconds: 10,
        sortMode: FlashcardSortMode.smart,
      ).copyWith();
      expect(settings.controlMode, ShadowingControlMode.manual);
      expect(settings.isManualMode, true);
      expect(settings.fixedTimerSeconds, 20);
      expect(settings.fixedTimerBackSeconds, 10);
      expect(settings.sortMode, FlashcardSortMode.smart);
    });

    test('toJson → fromJson 往返一致', () {
      const original = FlashcardSettings(
        controlMode: ShadowingControlMode.manual,
        timerMode: FlashcardTimerMode.fixed,
        fixedTimerSeconds: 10,
        fixedTimerBackSeconds: 8,
        sortMode: FlashcardSortMode.timeDesc,
        autoPlaySentence: false,
        autoPlayWord: false,
      );
      final json = original.toJson();
      final restored = FlashcardSettings.fromJson(json);
      expect(restored.controlMode, original.controlMode);
      expect(restored.timerMode, original.timerMode);
      expect(restored.fixedTimerSeconds, original.fixedTimerSeconds);
      expect(restored.fixedTimerBackSeconds, original.fixedTimerBackSeconds);
      expect(restored.sortMode, original.sortMode);
      expect(restored.autoPlaySentence, original.autoPlaySentence);
      expect(restored.autoPlayWord, original.autoPlayWord);
    });

    test('fromJson 空 Map 返回默认值', () {
      final settings = FlashcardSettings.fromJson({});
      expect(settings.controlMode, ShadowingControlMode.auto);
      expect(settings.timerMode, FlashcardTimerMode.smart);
      expect(settings.fixedTimerSeconds, 5);
      expect(settings.fixedTimerBackSeconds, 10);
      expect(settings.sortMode, FlashcardSortMode.random);
      expect(settings.autoPlaySentence, true);
      expect(settings.autoPlayWord, true);
    });

    test('fromJson 非法值回退默认', () {
      final settings = FlashcardSettings.fromJson({
        'controlMode': 'invalid',
        'timerMode': 'invalid',
        'fixedTimerSeconds': 999,
        'fixedTimerBackSeconds': 999,
        'sortMode': 42,
      });
      expect(settings.controlMode, ShadowingControlMode.auto);
      expect(settings.timerMode, FlashcardTimerMode.smart);
      expect(settings.fixedTimerSeconds, 5);
      expect(settings.fixedTimerBackSeconds, 10);
      expect(settings.sortMode, FlashcardSortMode.random);
    });

    test('fromJson 类型错误回退默认', () {
      final settings = FlashcardSettings.fromJson({
        'controlMode': 123,
        'timerMode': 123,
        'fixedTimerSeconds': 'abc',
        'fixedTimerBackSeconds': true,
        'sortMode': true,
      });
      expect(settings.controlMode, ShadowingControlMode.auto);
      expect(settings.timerMode, FlashcardTimerMode.smart);
      expect(settings.fixedTimerSeconds, 5);
      expect(settings.fixedTimerBackSeconds, 10);
      expect(settings.sortMode, FlashcardSortMode.random);
    });

    test('fromJson 旧数据 timerMode=off 迁移为 controlMode=manual', () {
      final settings = FlashcardSettings.fromJson({
        'timerMode': 'off',
      });
      expect(settings.controlMode, ShadowingControlMode.manual);
      expect(settings.isManualMode, true);
      // timerMode 回退为 smart（'off' 不再是合法枚举值）
      expect(settings.timerMode, FlashcardTimerMode.smart);
    });

    test('fromJson 旧数据无 fixedTimerBackSeconds 回退默认 10', () {
      final settings = FlashcardSettings.fromJson({
        'timerMode': 'fixed',
        'fixedTimerSeconds': 10,
      });
      expect(settings.fixedTimerSeconds, 10);
      expect(settings.fixedTimerBackSeconds, 10);
    });

    test('isManualMode getter', () {
      expect(
        const FlashcardSettings(controlMode: ShadowingControlMode.auto)
            .isManualMode,
        false,
      );
      expect(
        const FlashcardSettings(controlMode: ShadowingControlMode.manual)
            .isManualMode,
        true,
      );
    });
  });

  group('calculateSmartSeconds', () {
    test('短词首次学习 → 4s', () {
      final s = FlashcardSettings.calculateSmartSeconds(
        wordLength: 3,
        practiceCount: 0,
      );
      expect(s, 4);
    });

    test('长词首次学习 → 8s', () {
      final s = FlashcardSettings.calculateSmartSeconds(
        wordLength: 13,
        practiceCount: 0,
      );
      expect(s, 8);
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

    test('中等词首次 → 约 6s', () {
      final s = FlashcardSettings.calculateSmartSeconds(
        wordLength: 8,
        practiceCount: 0,
      );
      // ratio = (8-4)/(12-4) = 0.5, maxTime = 6.0, minTime = 3.5
      // decay = 0, result = 6.0 → rounds to 6
      expect(s, 6);
    });

    test('中等词练习 5 次 → 约 4s', () {
      final s = FlashcardSettings.calculateSmartSeconds(
        wordLength: 8,
        practiceCount: 5,
      );
      // ratio = 0.5, maxTime = 6.0, minTime = 3.5
      // decay = 1.0, result = 6.0 - 1.0*(6.0-3.5) = 3.5 → rounds to 4
      expect(s, 4);
    });

    test('超短词 clamp 到 0 ratio', () {
      final s = FlashcardSettings.calculateSmartSeconds(
        wordLength: 1,
        practiceCount: 0,
      );
      expect(s, 4);
    });

    test('超长词 clamp 到 1 ratio', () {
      final s = FlashcardSettings.calculateSmartSeconds(
        wordLength: 20,
        practiceCount: 0,
      );
      expect(s, 8);
    });
  });

  group('calculateSmartScore', () {
    test('首次未练习得分最高', () {
      final score = FlashcardSettings.calculateSmartScore(
        practiceCount: 0,
        viewedBack: false,
        lastPracticedAt: null,
      );
      expect(score, closeTo(168.0, 0.1));
    });

    test('练习多次得分降低', () {
      final score = FlashcardSettings.calculateSmartScore(
        practiceCount: 5,
        viewedBack: true,
        lastPracticedAt: DateTime.now(),
      );
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
