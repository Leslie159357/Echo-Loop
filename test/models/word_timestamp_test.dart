/// WordTimestamp 模型单元测试
///
/// 验证词级时间戳的 JSON 序列化/反序列化和时间转换逻辑。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:fluency/models/word_timestamp.dart';

void main() {
  group('WordTimestamp', () {
    test('fromJson 正确解析秒为 Duration', () {
      final json = {
        'word': 'hello',
        'startTime': 1.5,
        'endTime': 2.0,
        'confidence': 0.95,
      };
      final wt = WordTimestamp.fromJson(json);

      expect(wt.word, 'hello');
      expect(wt.startTime, const Duration(milliseconds: 1500));
      expect(wt.endTime, const Duration(milliseconds: 2000));
      expect(wt.confidence, 0.95);
    });

    test('fromJson 处理整数时间值', () {
      final json = {
        'word': 'world',
        'startTime': 3,
        'endTime': 4,
        'confidence': 1,
      };
      final wt = WordTimestamp.fromJson(json);

      expect(wt.startTime, const Duration(milliseconds: 3000));
      expect(wt.endTime, const Duration(milliseconds: 4000));
      expect(wt.confidence, 1.0);
    });

    test('fromJson 处理零值时间', () {
      final json = {
        'word': 'start',
        'startTime': 0.0,
        'endTime': 0.5,
        'confidence': 0.8,
      };
      final wt = WordTimestamp.fromJson(json);

      expect(wt.startTime, Duration.zero);
      expect(wt.endTime, const Duration(milliseconds: 500));
    });

    test('toJson 正确将 Duration 转换回秒', () {
      const wt = WordTimestamp(
        word: 'test',
        startTime: Duration(milliseconds: 1500),
        endTime: Duration(milliseconds: 2500),
        confidence: 0.99,
      );
      final json = wt.toJson();

      expect(json['word'], 'test');
      expect(json['startTime'], 1.5);
      expect(json['endTime'], 2.5);
      expect(json['confidence'], 0.99);
    });

    test('fromJson / toJson 往返一致', () {
      final original = {
        'word': 'round-trip',
        'startTime': 5.123,
        'endTime': 5.678,
        'confidence': 0.87,
      };
      final wt = WordTimestamp.fromJson(original);
      final restored = wt.toJson();

      // Duration 精度为毫秒，允许舍入误差
      expect(restored['word'], original['word']);
      expect(
        (restored['startTime'] as double),
        closeTo(original['startTime'] as double, 0.001),
      );
      expect(
        (restored['endTime'] as double),
        closeTo(original['endTime'] as double, 0.001),
      );
      expect(restored['confidence'], original['confidence']);
    });

    test('fromJson 缺少字段时抛出异常', () {
      final json = <String, dynamic>{'word': 'missing'};
      expect(
        () => WordTimestamp.fromJson(json),
        throwsA(isA<TypeError>()),
      );
    });

    test('const 构造函数支持编译时常量', () {
      const wt = WordTimestamp(
        word: 'const',
        startTime: Duration(milliseconds: 100),
        endTime: Duration(milliseconds: 200),
        confidence: 1.0,
      );
      expect(wt.word, 'const');
    });
  });
}
