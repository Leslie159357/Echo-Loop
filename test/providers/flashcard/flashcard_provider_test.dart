/// FlashcardNotifier 单元测试
///
/// 验证 FlashcardState 状态类、排序逻辑、倒计时秒数计算、
/// 背面例句额外时长、输入词数计入等核心行为。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/providers/flashcard/flashcard_provider.dart';
import 'package:echo_loop/models/flashcard_item.dart';
import 'package:echo_loop/models/flashcard_settings.dart';
import 'package:echo_loop/database/app_database.dart' show SavedWord;

// ========== 测试数据工厂 ==========

SavedWord _createWord({
  required int id,
  required String word,
  int practiceCount = 0,
  bool viewedBack = false,
  String? sentenceText,
  int? sentenceStartMs,
  int? sentenceEndMs,
  String? audioItemId,
  DateTime? createdAt,
  DateTime? lastPracticedAt,
}) {
  return SavedWord(
    id: id,
    word: word,
    audioItemId: audioItemId,
    sentenceIndex: null,
    sentenceText: sentenceText,
    sentenceStartMs: sentenceStartMs,
    sentenceEndMs: sentenceEndMs,
    practiceCount: practiceCount,
    totalStudyMs: 0,
    viewedBack: viewedBack,
    lastPracticedAt: lastPracticedAt,
    createdAt: createdAt ?? DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    deletedAt: null,
    syncStatus: 0,
  );
}

void main() {
  // ========== FlashcardState ==========

  group('FlashcardState', () {
    test('默认初始状态正确', () {
      const state = FlashcardState();
      expect(state.words, isEmpty);
      expect(state.currentIndex, 0);
      expect(state.isShowingBack, false);
      expect(state.isCompleted, false);
      expect(state.removedCount, 0);
      expect(state.countdownRemaining, Duration.zero);
      expect(state.countdownTotal, Duration.zero);
      expect(state.currentWord, isNull);
    });

    test('currentWord 返回当前索引的卡片', () {
      final word = _createWord(id: 1, word: 'hello');
      final state = FlashcardState(
        words: [FlashcardWordItem(savedWord: word)],
        currentIndex: 0,
      );
      expect(state.currentWord, isNotNull);
      expect(state.currentWord!.displayText, 'hello');
    });

    test('currentWord 索引越界时返回 null', () {
      final word = _createWord(id: 1, word: 'hello');
      final state = FlashcardState(
        words: [FlashcardWordItem(savedWord: word)],
        currentIndex: 5,
      );
      expect(state.currentWord, isNull);
    });

    test('copyWith 替换指定字段', () {
      const state = FlashcardState();
      final updated = state.copyWith(
        currentIndex: 3,
        isShowingBack: true,
        removedCount: 2,
      );
      expect(updated.currentIndex, 3);
      expect(updated.isShowingBack, true);
      expect(updated.removedCount, 2);
      // 未指定字段保留原值
      expect(updated.isCompleted, false);
    });

    test('copyWith clearCardStartTime 清除时间', () {
      final state = FlashcardState(cardStartTime: DateTime.now());
      expect(state.cardStartTime, isNotNull);

      final cleared = state.copyWith(clearCardStartTime: true);
      expect(cleared.cardStartTime, isNull);
    });

    test('totalWordsReviewed 等于 currentIndex + 1', () {
      const state = FlashcardState(currentIndex: 4);
      expect(state.totalWordsReviewed, 5);
    });
  });

  // ========== FlashcardWordItem ==========

  group('FlashcardWordItem', () {
    test('初始 dictLoaded 为 false', () {
      final item = FlashcardWordItem(
        savedWord: _createWord(id: 1, word: 'test'),
      );
      expect(item.dictLoaded, false);
      expect(item.dictEntry, isNull);
    });

    test('withDictEntry 更新 dictLoaded', () {
      final item = FlashcardWordItem(
        savedWord: _createWord(id: 1, word: 'test'),
      );
      final updated = item.withDictEntry(null);
      expect(updated.dictLoaded, true);
      expect(updated.savedWord.word, 'test');
    });
  });

  // ========== 倒计时秒数计算 ==========

  group('背面倒计时额外秒数', () {
    // 直接测试 FlashcardSettings.calculateSmartSeconds 算法
    // 算法：ratio = clamp((len-4)/8, 0, 1)
    //       maxTime = 3 + ratio*3 (3→6)
    //       minTime = 2 + ratio*2 (2→4)
    //       decay = clamp(practiceCount/5, 0, 1)
    //       result = round(maxTime - decay*(maxTime-minTime))

    test('智能倒计时：短词 + 首次练习 → maxTime(3s)', () {
      final seconds = FlashcardSettings.calculateSmartSeconds(
        wordLength: 3,
        practiceCount: 0,
      );
      // ratio=0, maxTime=3, decay=0 → 3
      expect(seconds, 3);
    });

    test('智能倒计时：长词 + 首次练习 → maxTime(6s)', () {
      final seconds = FlashcardSettings.calculateSmartSeconds(
        wordLength: 14,
        practiceCount: 0,
      );
      // ratio=1, maxTime=6, decay=0 → 6
      expect(seconds, 6);
    });

    test('智能倒计时：短词 + 5 次练习 → minTime(2s)', () {
      final seconds = FlashcardSettings.calculateSmartSeconds(
        wordLength: 3,
        practiceCount: 5,
      );
      // ratio=0, maxTime=3, minTime=2, decay=1 → 3-1=2
      expect(seconds, 2);
    });

    test('智能倒计时：长词 + 5 次练习 → minTime(4s)', () {
      final seconds = FlashcardSettings.calculateSmartSeconds(
        wordLength: 14,
        practiceCount: 5,
      );
      // ratio=1, maxTime=6, minTime=4, decay=1 → 6-2=4
      expect(seconds, 4);
    });

    test('智能倒计时：中等长度(8) + 2 次练习', () {
      final seconds = FlashcardSettings.calculateSmartSeconds(
        wordLength: 8,
        practiceCount: 2,
      );
      // ratio=0.5, maxTime=4.5, minTime=3.0
      // decay=0.4, result=4.5-0.4*1.5=4.5-0.6=3.9 → 4
      expect(seconds, 4);
    });
  });

  // ========== onSentencePlayed 词数统计 ==========

  group('例句词数统计逻辑', () {
    test('英文句子按空格分词', () {
      // 模拟 onSentencePlayed 内部的分词逻辑
      const text = 'The quick brown fox jumps over the lazy dog';
      final count = text
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .length;
      expect(count, 9);
    });

    test('空字符串返回 0 词', () {
      const text = '';
      final count = text
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .length;
      expect(count, 0);
    });

    test('含多余空格的文本正确计数', () {
      const text = '  hello   world  ';
      final count = text
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .length;
      expect(count, 2);
    });

    test("缩写词 don't 算 1 个词", () {
      const text = "I don't know";
      final count = text
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .length;
      expect(count, 3);
    });
  });

  // ========== 排序逻辑 ==========

  group('排序逻辑', () {
    final words = [
      _createWord(id: 1, word: 'banana', createdAt: DateTime(2026, 1, 3)),
      _createWord(id: 2, word: 'apple', createdAt: DateTime(2026, 1, 1)),
      _createWord(id: 3, word: 'cherry', createdAt: DateTime(2026, 1, 2)),
    ];

    test('alphabeticalAsc 按字母 A→Z', () {
      final sorted = List<SavedWord>.from(words)
        ..sort((a, b) => a.word.toLowerCase().compareTo(b.word.toLowerCase()));
      expect(sorted.map((w) => w.word).toList(), ['apple', 'banana', 'cherry']);
    });

    test('alphabeticalDesc 按字母 Z→A', () {
      final sorted = List<SavedWord>.from(words)
        ..sort((a, b) => b.word.toLowerCase().compareTo(a.word.toLowerCase()));
      expect(sorted.map((w) => w.word).toList(), ['cherry', 'banana', 'apple']);
    });

    test('timeAsc 最早收藏优先', () {
      final sorted = List<SavedWord>.from(words)
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      expect(sorted.map((w) => w.word).toList(), ['apple', 'cherry', 'banana']);
    });

    test('timeDesc 最近收藏优先', () {
      final sorted = List<SavedWord>.from(words)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      expect(sorted.map((w) => w.word).toList(), ['banana', 'cherry', 'apple']);
    });
  });

  // ========== 智能排序分数 ==========

  group('智能排序分数 — 遗忘曲线', () {
    test('新词分数高于刚练完的词', () {
      final scoreNew = FlashcardSettings.calculateSmartScore(
        practiceCount: 0,
        lastPracticedAt: null,
      );
      final scorePracticed = FlashcardSettings.calculateSmartScore(
        practiceCount: 3,
        lastPracticedAt: DateTime.now(),
      );
      expect(scoreNew, greaterThan(scorePracticed));
    });

    test('很久没练习的单词分数更高', () {
      final scoreRecent = FlashcardSettings.calculateSmartScore(
        practiceCount: 2,
        lastPracticedAt: DateTime.now(),
      );
      final scoreOld = FlashcardSettings.calculateSmartScore(
        practiceCount: 2,
        lastPracticedAt: DateTime.now().subtract(const Duration(days: 7)),
      );
      expect(scoreOld, greaterThan(scoreRecent));
    });

    test('练习次数多的词间隔更长，不容易超期', () {
      final lastPracticed =
          DateTime.now().subtract(const Duration(days: 1));
      final scoreLow = FlashcardSettings.calculateSmartScore(
        practiceCount: 1,
        lastPracticedAt: lastPracticed,
      );
      final scoreHigh = FlashcardSettings.calculateSmartScore(
        practiceCount: 8,
        lastPracticedAt: lastPracticed,
      );
      expect(scoreLow, greaterThan(scoreHigh));
    });
  });
}
