import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/models/sentence_ai_result.dart';

void main() {
  group('SentenceTranslation', () {
    test('fromJson 正确解析翻译字段', () {
      final json = {'translation': '这是一个测试句子。'};
      final result = SentenceTranslation.fromJson(json);
      expect(result.translation, '这是一个测试句子。');
    });

    test('fromJson 处理空翻译', () {
      final json = {'translation': ''};
      final result = SentenceTranslation.fromJson(json);
      expect(result.translation, '');
    });

    test('fromJson 缺少 translation 字段时抛出异常', () {
      final json = <String, dynamic>{'other': 'value'};
      expect(
        () => SentenceTranslation.fromJson(json),
        throwsA(isA<TypeError>()),
      );
    });

    test('const 构造函数支持相等比较', () {
      const a = SentenceTranslation(translation: 'hello');
      const b = SentenceTranslation(translation: 'hello');
      // const 对象是同一实例
      expect(identical(a, b), isTrue);
    });
  });

  group('SentenceAnalysis', () {
    test('fromJson 正确解析嵌套 analysis 字段', () {
      final json = {
        'analysis': {
          'grammar': '主语 + 谓语 + 宾语',
          'vocabulary': 'test: 测试',
          'listening': '常用于正式场合',
        },
      };
      final result = SentenceAnalysis.fromJson(json);
      expect(result.grammar, '主语 + 谓语 + 宾语');
      expect(result.vocabulary, 'test: 测试');
      expect(result.listening, '常用于正式场合');
    });

    test('fromJson 处理空字段值', () {
      final json = {
        'analysis': {'grammar': '', 'vocabulary': '', 'listening': ''},
      };
      final result = SentenceAnalysis.fromJson(json);
      expect(result.grammar, '');
      expect(result.vocabulary, '');
      expect(result.listening, '');
    });

    test('fromJson 缺少 analysis 外层字段时抛出异常', () {
      final json = <String, dynamic>{
        'grammar': '直接放在顶层',
      };
      expect(
        () => SentenceAnalysis.fromJson(json),
        throwsA(isA<TypeError>()),
      );
    });

    test('fromJson 缺少 analysis 内部字段时抛出异常', () {
      final json = {
        'analysis': <String, dynamic>{'grammar': '有语法'},
      };
      expect(
        () => SentenceAnalysis.fromJson(json),
        throwsA(isA<TypeError>()),
      );
    });

    test('const 构造函数正常工作', () {
      const result = SentenceAnalysis(
        grammar: 'g',
        vocabulary: 'v',
        listening: 'u',
      );
      expect(result.grammar, 'g');
      expect(result.vocabulary, 'v');
      expect(result.listening, 'u');
    });
  });
}
