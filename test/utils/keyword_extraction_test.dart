import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/models/retell_settings.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/utils/keyword_extraction.dart';
import 'package:echo_loop/utils/stopwords.dart';

/// 辅助函数：创建带指定文本的句子列表
List<Sentence> _makeSentences(List<String> texts) {
  return texts
      .asMap()
      .entries
      .map(
        (e) => Sentence(
          index: e.key,
          text: e.value,
          startTime: Duration(seconds: e.key * 5),
          endTime: Duration(seconds: (e.key + 1) * 5),
        ),
      )
      .toList();
}

/// 辅助函数：统计关键词总数
int _totalKeywords(Map<int, Set<int>> result) {
  return result.values.fold<int>(0, (sum, s) => sum + s.length);
}

void main() {
  group('extractKeywords', () {
    test('空句子列表返回空映射', () {
      final result = extractKeywords([]);
      expect(result, isEmpty);
    });

    test('所有词长度 ≤ 2 返回空映射', () {
      final sentences = _makeSentences(['I am a', 'Go to']);
      final result = extractKeywords(sentences, random: Random(42));
      expect(result, isEmpty);
    });

    test('至少提取 1 个关键词（保底机制）', () {
      final sentences = _makeSentences([
        'The beautiful sunset illuminated the entire valley',
      ]);
      final result = extractKeywords(sentences, random: Random(42));
      expect(_totalKeywords(result), greaterThanOrEqualTo(1));
    });

    test('关键词索引在有效范围内', () {
      final sentences = _makeSentences([
        'Understanding complex algorithms requires practice',
        'Mathematical foundations provide essential knowledge',
      ]);
      final result = extractKeywords(sentences, random: Random(42));
      for (final entry in result.entries) {
        expect(entry.key, inInclusiveRange(0, 1), reason: '句子索引超出范围');
        for (final wordIdx in entry.value) {
          final words = tokenize(sentences[entry.key].text);
          expect(
            wordIdx,
            inInclusiveRange(0, words.length - 1),
            reason: '词索引超出范围',
          );
        }
      }
    });

    test('固定种子产生确定性结果', () {
      final sentences = _makeSentences([
        'Understanding complex algorithms requires extensive practice',
        'Mathematical foundations provide essential knowledge',
      ]);
      final result1 = extractKeywords(sentences, random: Random(123));
      final result2 = extractKeywords(sentences, random: Random(123));
      expect(result1.keys.toSet(), result2.keys.toSet());
      for (final key in result1.keys) {
        expect(result1[key], result2[key]);
      }
    });

    group('比例测试', () {
      // 构造全为非停用词的句子用于比例验证
      final sentences = _makeSentences([
        'absolutely beautiful certainly delightful especially fantastic generally hopefully',
        'incredibly joyfully knowledgeable lovingly meaningfully naturally obviously potentially',
        'remarkably significantly tremendously unfortunately wonderfully yesterday',
      ]);

      // 总词数 22，全部 > 2 字符且非停用词
      test('1/2 比例选出约 50% 关键词', () {
        final result = extractKeywords(
          sentences,
          ratio: KeywordRatio.half,
          random: Random(42),
        );
        final count = _totalKeywords(result);
        // 22 * 0.5 = 11
        expect(count, inInclusiveRange(8, 14));
      });

      test('1/3 比例选出约 33% 关键词', () {
        final result = extractKeywords(
          sentences,
          ratio: KeywordRatio.oneThird,
          random: Random(42),
        );
        final count = _totalKeywords(result);
        // 22 * 0.333 ≈ 7
        expect(count, inInclusiveRange(5, 10));
      });

      test('1/5 比例选出约 20% 关键词', () {
        final result = extractKeywords(
          sentences,
          ratio: KeywordRatio.oneFifth,
          random: Random(42),
        );
        final count = _totalKeywords(result);
        // 22 * 0.2 ≈ 4
        expect(count, inInclusiveRange(3, 7));
      });

      test('1/10 比例选出约 10% 关键词', () {
        final result = extractKeywords(
          sentences,
          ratio: KeywordRatio.oneTenth,
          random: Random(42),
        );
        final count = _totalKeywords(result);
        // 22 * 0.1 ≈ 2
        expect(count, inInclusiveRange(1, 5));
      });
    });

    group('停用词过滤', () {
      test('停用词不会被选为关键词', () {
        final sentences = _makeSentences([
          'The beautiful sunset was absolutely wonderful',
        ]);
        for (var seed = 0; seed < 100; seed++) {
          final result = extractKeywords(
            sentences,
            ratio: KeywordRatio.half,
            random: Random(seed),
          );
          if (result.containsKey(0)) {
            final words = tokenize(sentences[0].text);
            for (final idx in result[0]!) {
              expect(
                isStopword(words[idx]),
                isFalse,
                reason: '停用词 "${words[idx]}" 不应被选为关键词 (seed=$seed)',
              );
            }
          }
        }
      });

      test('仅含停用词的句子不产生关键词', () {
        final sentences = _makeSentences(['The and with from they were']);
        final result = extractKeywords(sentences, random: Random(42));
        expect(result, isEmpty);
      });

      test('带标点的停用词也能正确过滤', () {
        final sentences = _makeSentences(['The, beautiful through. wonderful']);
        for (var seed = 0; seed < 50; seed++) {
          final result = extractKeywords(
            sentences,
            ratio: KeywordRatio.half,
            random: Random(seed),
          );
          if (result.containsKey(0)) {
            final words = tokenize(sentences[0].text);
            for (final idx in result[0]!) {
              expect(
                isStopword(words[idx]),
                isFalse,
                reason: '停用词 "${words[idx]}" 不应被选中 (seed=$seed)',
              );
            }
          }
        }
      });

      test('targetCount 基于总词数，上限为候选词数量', () {
        // 11 个词，其中 5 个停用词 + 6 个内容词
        final sentences = _makeSentences([
          'The beautiful and wonderful but magnificent or spectacular yet incredible also extraordinary',
        ]);
        final result = extractKeywords(
          sentences,
          ratio: KeywordRatio.half,
          random: Random(42),
        );
        // 总词数 11，ratio 1/2 → targetCount = round(11 * 0.5) = 6
        // 候选词恰好 6 个，clamp 上限 6 → 选 6 个
        final count = _totalKeywords(result);
        expect(count, inInclusiveRange(5, 6));
      });
    });
  });

  group('tokenize', () {
    test('按空格分词，保留标点附着在单词上', () {
      expect(tokenize('Hello, world!'), ['Hello,', 'world!']);
      expect(tokenize("it's a beautiful day"), [
        "it's",
        'a',
        'beautiful',
        'day',
      ]);
      expect(tokenize('one-two—three'), ['one-two—three']);
    });

    test('撇号缩写和所有格不拆分', () {
      expect(tokenize("don't stop"), ["don't", 'stop']);
      expect(tokenize("library's book"), ["library's", 'book']);
    });

    test('标点符号保留在输出中', () {
      expect(tokenize('Yes, I can.'), ['Yes,', 'I', 'can.']);
      expect(tokenize('Wait... what?'), ['Wait...', 'what?']);
      expect(tokenize('Hello; goodbye'), ['Hello;', 'goodbye']);
    });

    test('空字符串返回空列表', () {
      expect(tokenize(''), isEmpty);
    });
  });
}
