import 'package:flutter_test/flutter_test.dart';
import 'package:fluency/models/sentence.dart';
import 'package:fluency/utils/paragraph_grouping.dart';

/// 辅助函数：创建指定时长的句子列表
List<Sentence> _makeSentences(List<int> durationsMs) {
  final sentences = <Sentence>[];
  var start = 0;
  for (var i = 0; i < durationsMs.length; i++) {
    sentences.add(Sentence(
      index: i,
      text: 'Sentence $i',
      startTime: Duration(milliseconds: start),
      endTime: Duration(milliseconds: start + durationsMs[i]),
    ));
    start += durationsMs[i];
  }
  return sentences;
}

/// 辅助函数：计算段落总时长（毫秒）
int _paragraphDurationMs(List<Sentence> paragraph) {
  if (paragraph.isEmpty) return 0;
  return paragraph.last.endTime.inMilliseconds -
      paragraph.first.startTime.inMilliseconds;
}

void main() {
  group('groupSentencesIntoParagraphs', () {
    test('空列表返回空', () {
      final result = groupSentencesIntoParagraphs([], const Duration(seconds: 30));
      expect(result, isEmpty);
    });

    test('单句返回单段', () {
      final sentences = _makeSentences([5000]);
      final result = groupSentencesIntoParagraphs(
        sentences,
        const Duration(seconds: 30),
      );
      expect(result, hasLength(1));
      expect(result[0], hasLength(1));
      expect(result[0][0].index, 0);
    });

    test('总时长小于目标时长 → 单段', () {
      final sentences = _makeSentences([5000, 5000, 5000]); // 15s < 30s
      final result = groupSentencesIntoParagraphs(
        sentences,
        const Duration(seconds: 30),
      );
      expect(result, hasLength(1));
      expect(result[0], hasLength(3));
    });

    test('正常分段：2分钟音频 target=30s → ~4 段', () {
      // 20 句 × 6s = 120s，target=30s → 约 4 段
      final sentences = _makeSentences(List.filled(20, 6000));
      final result = groupSentencesIntoParagraphs(
        sentences,
        const Duration(seconds: 30),
      );
      expect(result.length, inInclusiveRange(3, 5));
      // 所有句子都包含
      final allSentences = result.expand((g) => g).toList();
      expect(allSentences.length, 20);
    });

    test('均匀性：各段时长差距尽量小', () {
      // 12 句 × 10s = 120s，target=30s → 4 段（完美均分）
      final sentences = _makeSentences(List.filled(12, 10000));
      final result = groupSentencesIntoParagraphs(
        sentences,
        const Duration(seconds: 30),
      );
      expect(result.length, 4);
      // 每段应为 3 句 × 10s = 30s
      for (final group in result) {
        expect(group.length, 3);
        expect(_paragraphDurationMs(group), 30000);
      }
    });

    test('2:05 音频不产生极短末段', () {
      // 25 句 × 5s = 125s，target=30s
      final sentences = _makeSentences(List.filled(25, 5000));
      final result = groupSentencesIntoParagraphs(
        sentences,
        const Duration(seconds: 30),
      );
      // 不应有极短段（<10s）
      for (final group in result) {
        final durationMs = _paragraphDurationMs(group);
        expect(durationMs, greaterThanOrEqualTo(10000),
            reason: '段落时长 ${durationMs}ms 过短');
      }
    });

    test('单句超长 > target 独立成段', () {
      final sentences = _makeSentences([40000, 5000, 5000, 5000]);
      // 总时长 55s，target=30s
      final result = groupSentencesIntoParagraphs(
        sentences,
        const Duration(seconds: 30),
      );
      // 第一句 40s 应独立成段
      expect(result.first.length, 1);
      expect(result.first[0].index, 0);
    });

    test('不同 target 值产生不同分组数', () {
      // 30 句 × 5s = 150s
      final sentences = _makeSentences(List.filled(30, 5000));

      final result20 = groupSentencesIntoParagraphs(
        sentences,
        const Duration(seconds: 20),
      );
      final result60 = groupSentencesIntoParagraphs(
        sentences,
        const Duration(seconds: 60),
      );
      // target=20s 应比 target=60s 产生更多段落
      expect(result20.length, greaterThan(result60.length));
    });

    test('所有句子时长相同 → 完美均分', () {
      // 10 句 × 5s = 50s，target=25s → 2 段各 5 句
      final sentences = _makeSentences(List.filled(10, 5000));
      final result = groupSentencesIntoParagraphs(
        sentences,
        const Duration(seconds: 25),
      );
      expect(result.length, 2);
      expect(result[0].length, 5);
      expect(result[1].length, 5);
    });

    test('句子时长差异较大时仍能合理分组', () {
      // 混合时长：3s, 8s, 2s, 12s, 4s, 7s, 3s, 9s = 48s, target=20s
      final sentences = _makeSentences([3000, 8000, 2000, 12000, 4000, 7000, 3000, 9000]);
      final result = groupSentencesIntoParagraphs(
        sentences,
        const Duration(seconds: 20),
      );
      // 应分为 2-3 段
      expect(result.length, inInclusiveRange(2, 3));
      // 所有句子都保留
      final allCount = result.fold<int>(0, (sum, g) => sum + g.length);
      expect(allCount, 8);
    });

    test('保持句子顺序不变', () {
      final sentences = _makeSentences(List.filled(15, 4000)); // 60s, target=20s
      final result = groupSentencesIntoParagraphs(
        sentences,
        const Duration(seconds: 20),
      );
      // 验证索引单调递增
      var prevIndex = -1;
      for (final group in result) {
        for (final s in group) {
          expect(s.index, greaterThan(prevIndex));
          prevIndex = s.index;
        }
      }
    });

    test('两句刚好等于 target → 单段', () {
      final sentences = _makeSentences([15000, 15000]); // 30s = target
      final result = groupSentencesIntoParagraphs(
        sentences,
        const Duration(seconds: 30),
      );
      expect(result, hasLength(1));
      expect(result[0], hasLength(2));
    });

    test('target=90s 大时长分组', () {
      // 60 句 × 3s = 180s，target=90s → 2 段
      final sentences = _makeSentences(List.filled(60, 3000));
      final result = groupSentencesIntoParagraphs(
        sentences,
        const Duration(seconds: 90),
      );
      expect(result.length, 2);
    });
  });
}
