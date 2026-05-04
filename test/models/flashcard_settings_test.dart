/// FlashcardSettings 模型测试
///
/// 覆盖 copyWith / toJson / fromJson / 边界值 / 智能算法 / controlMode。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/models/flashcard_settings.dart';
import 'package:echo_loop/models/intensive_listen_settings.dart'
    show ShadowingControlMode;

void main() {
  group('FlashcardSettings', () {
    test('默认值正确', () {
      const settings = FlashcardSettings();
      expect(settings.controlMode, ShadowingControlMode.auto);
      expect(settings.timerMode, FlashcardTimerMode.smart);
      expect(settings.fixedTimerSeconds, 5);
      expect(settings.fixedTimerBackSeconds, 10);
      expect(settings.sortMode, FlashcardSortMode.smart);
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
      expect(settings.sortMode, FlashcardSortMode.smart);
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
      expect(settings.sortMode, FlashcardSortMode.smart);
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
      expect(settings.sortMode, FlashcardSortMode.smart);
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

  group('calculateSmartScore — 遗忘曲线', () {
    test('新词（未练习）固定返回 2.0', () {
      final score = FlashcardSettings.calculateSmartScore(
        practiceCount: 0,
        lastPracticedAt: null,
      );
      expect(score, 2.0);
    });

    test('刚练完的词分数接近 0', () {
      final score = FlashcardSettings.calculateSmartScore(
        practiceCount: 1,
        lastPracticedAt: DateTime.now(),
      );
      expect(score, closeTo(0.0, 0.1));
    });

    test('超期比例随时间增长', () {
      // 练 1 次，间隔 120min，过了 360min → overdue = 3.0
      final score = FlashcardSettings.calculateSmartScore(
        practiceCount: 1,
        lastPracticedAt: DateTime.now().subtract(const Duration(minutes: 360)),
      );
      expect(score, closeTo(3.0, 0.1));
    });

    test('练习次数越多间隔越长，同样时间超期比例越低', () {
      final lastPracticed =
          DateTime.now().subtract(const Duration(hours: 12));
      // 练 1 次：interval=120min, 720/120=6.0
      final score1 = FlashcardSettings.calculateSmartScore(
        practiceCount: 1,
        lastPracticedAt: lastPracticed,
      );
      // 练 5 次：interval=1920min, 720/1920=0.375
      final score5 = FlashcardSettings.calculateSmartScore(
        practiceCount: 5,
        lastPracticedAt: lastPracticed,
      );
      expect(score1, greaterThan(score5));
    });

    test('超期比例上限 clamp 到 10', () {
      // 练 1 次，间隔 120min，过了 7 天 = 10080min → 84 → clamp 10
      final score = FlashcardSettings.calculateSmartScore(
        practiceCount: 1,
        lastPracticedAt:
            DateTime.now().subtract(const Duration(days: 7)),
      );
      expect(score, 10.0);
    });
  });

  // ========== 智能排序集成 ==========

  group('smart 排序 — 多词排序验证', () {
    /// 辅助：按 smart score 降序排列 displayText
    List<String> sortBySmartScore(
      List<({String name, int practice, DateTime? lastPracticed})> items,
    ) {
      final scored = items.map((e) {
        final score = FlashcardSettings.calculateSmartScore(
          practiceCount: e.practice,
          lastPracticedAt: e.lastPracticed,
        );
        return (name: e.name, score: score);
      }).toList()
        ..sort((a, b) => b.score.compareTo(a.score));
      return scored.map((e) => e.name).toList();
    }

    test('严重超期的词排在新词前面', () {
      final now = DateTime.now();
      final result = sortBySmartScore([
        (name: 'new', practice: 0, lastPracticed: null),
        (name: 'overdue', practice: 1, lastPracticed: now.subtract(const Duration(days: 1))),
      ]);
      // overdue score=10(clamp), new score=2.0
      expect(result, ['overdue', 'new']);
    });

    test('新词排在刚练完的词前面', () {
      final now = DateTime.now();
      final result = sortBySmartScore([
        (name: 'justDone', practice: 3, lastPracticed: now),
        (name: 'new', practice: 0, lastPracticed: null),
      ]);
      expect(result, ['new', 'justDone']);
    });

    test('练习多次的熟词即使很久没碰也不会排到最前', () {
      final now = DateTime.now();
      final result = sortBySmartScore([
        // 练 10 次，7 天没碰，interval=60*1024=61440min，overdue=10080/61440=0.16
        (name: 'master', practice: 10, lastPracticed: now.subtract(const Duration(days: 7))),
        // 练 1 次，1 天没碰，interval=120min，overdue=1440/120=12→clamp10
        (name: 'beginner', practice: 1, lastPracticed: now.subtract(const Duration(days: 1))),
        // 新词 score=2.0
        (name: 'new', practice: 0, lastPracticed: null),
      ]);
      expect(result, ['beginner', 'new', 'master']);
    });

    test('相同 practiceCount 的词按超期时间排序', () {
      final now = DateTime.now();
      final result = sortBySmartScore([
        (name: 'recent', practice: 3, lastPracticed: now.subtract(const Duration(hours: 2))),
        (name: 'old', practice: 3, lastPracticed: now.subtract(const Duration(days: 2))),
      ]);
      expect(result, ['old', 'recent']);
    });
  });
}
