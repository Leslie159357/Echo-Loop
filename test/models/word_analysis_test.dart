import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/models/word_analysis.dart';

void main() {
  group('WordAnalysis', () {
    test('fromJson 正确解析所有字段', () {
      final json = {
        'analysis': {
          'contextMeaning': '在这里表示"经营"而非"跑步"',
          'collocations': 'run a business | run errands | run out of',
          'usage': '注意与 operate 的区别：run 更口语化',
          'wordFamily': 'runner (n. 跑者) | running (adj. 运行中的)',
        },
      };
      final result = WordAnalysis.fromJson(json);
      expect(result.contextMeaning, '在这里表示"经营"而非"跑步"');
      expect(result.collocations, 'run a business | run errands | run out of');
      expect(result.usage, '注意与 operate 的区别：run 更口语化');
      expect(result.wordFamily, 'runner (n. 跑者) | running (adj. 运行中的)');
    });

    test('fromJson 正确处理 null 字段', () {
      final json = {
        'analysis': {
          'contextMeaning': '猫，家猫',
          'collocations': null,
          'usage': null,
          'wordFamily': null,
        },
      };
      final result = WordAnalysis.fromJson(json);
      expect(result.contextMeaning, '猫，家猫');
      expect(result.collocations, isNull);
      expect(result.usage, isNull);
      expect(result.wordFamily, isNull);
    });

    test('fromJson 所有字段为 null', () {
      final json = {
        'analysis': {
          'contextMeaning': null,
          'collocations': null,
          'usage': null,
          'wordFamily': null,
        },
      };
      final result = WordAnalysis.fromJson(json);
      expect(result.contextMeaning, isNull);
      expect(result.collocations, isNull);
      expect(result.usage, isNull);
      expect(result.wordFamily, isNull);
    });

    test('toJson 序列化一致性', () {
      const original = WordAnalysis(
        contextMeaning: '语境释义',
        collocations: '搭配1 | 搭配2',
        usage: '用法说明',
        wordFamily: '词族扩展',
      );
      final json = original.toJson();
      final restored = WordAnalysis.fromJson(json);
      expect(restored.contextMeaning, original.contextMeaning);
      expect(restored.collocations, original.collocations);
      expect(restored.usage, original.usage);
      expect(restored.wordFamily, original.wordFamily);
    });

    test('isEmpty 全 null 返回 true', () {
      const analysis = WordAnalysis();
      expect(analysis.isEmpty, isTrue);
    });

    test('isEmpty 有字段返回 false', () {
      const analysis = WordAnalysis(contextMeaning: '释义');
      expect(analysis.isEmpty, isFalse);
    });

    test('fromJson 缺少 analysis 外层字段时抛出异常', () {
      final json = <String, dynamic>{'contextMeaning': '直接放在顶层'};
      expect(() => WordAnalysis.fromJson(json), throwsA(isA<TypeError>()));
    });
  });
}
