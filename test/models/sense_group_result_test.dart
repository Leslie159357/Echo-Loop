/// SenseGroupResult / SenseGroup 模型单元测试
///
/// 验证意群拆分结果的 JSON 反序列化和序列化逻辑。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:fluency/models/sense_group_result.dart';

void main() {
  group('SenseGroup', () {
    test('fromJson 正确解析意群字段', () {
      final json = {'text': 'in the morning', 'translation': '在早上'};
      final sg = SenseGroup.fromJson(json);

      expect(sg.text, 'in the morning');
      expect(sg.translation, '在早上');
    });

    test('toJson 正确序列化', () {
      const sg = SenseGroup(text: 'at night', translation: '在晚上');
      final json = sg.toJson();

      expect(json, {'text': 'at night', 'translation': '在晚上'});
    });

    test('fromJson / toJson 往返一致', () {
      final original = {
        'text': 'have been working',
        'translation': '一直在工作',
      };
      final sg = SenseGroup.fromJson(original);
      final restored = sg.toJson();

      expect(restored, original);
    });

    test('fromJson 处理空字符串', () {
      final json = {'text': '', 'translation': ''};
      final sg = SenseGroup.fromJson(json);

      expect(sg.text, '');
      expect(sg.translation, '');
    });

    test('fromJson 缺少字段时抛出异常', () {
      final json = <String, dynamic>{'text': 'only text'};
      expect(
        () => SenseGroup.fromJson(json),
        throwsA(isA<TypeError>()),
      );
    });

    test('const 构造函数支持编译时常量', () {
      const sg = SenseGroup(text: 'hello', translation: '你好');
      expect(sg.text, 'hello');
      expect(sg.translation, '你好');
    });
  });

  group('SenseGroupResult', () {
    test('fromJson 正确解析典型 API 响应', () {
      final json = {
        'groups': [
          {'text': 'I have been', 'translation': '我一直'},
          {'text': 'working hard', 'translation': '努力工作'},
          {'text': 'since last month', 'translation': '自上个月以来'},
        ],
      };
      final result = SenseGroupResult.fromJson(json);

      expect(result.groups.length, 3);
      expect(result.groups[0].text, 'I have been');
      expect(result.groups[0].translation, '我一直');
      expect(result.groups[1].text, 'working hard');
      expect(result.groups[2].translation, '自上个月以来');
    });

    test('fromJson 处理空意群列表', () {
      final json = {'groups': <dynamic>[]};
      final result = SenseGroupResult.fromJson(json);

      expect(result.groups, isEmpty);
    });

    test('fromJson 处理单个意群', () {
      final json = {
        'groups': [
          {'text': 'Hello', 'translation': '你好'},
        ],
      };
      final result = SenseGroupResult.fromJson(json);

      expect(result.groups.length, 1);
      expect(result.groups[0].text, 'Hello');
    });

    test('fromJson 缺少 groups 字段时抛出异常', () {
      final json = <String, dynamic>{'other': 'value'};
      expect(
        () => SenseGroupResult.fromJson(json),
        throwsA(isA<TypeError>()),
      );
    });

    test('fromJson 解析含标点的意群文本', () {
      final json = {
        'groups': [
          {'text': 'Well,', 'translation': '嗯，'},
          {'text': 'I think so.', 'translation': '我觉得是的。'},
        ],
      };
      final result = SenseGroupResult.fromJson(json);

      expect(result.groups[0].text, 'Well,');
      expect(result.groups[1].text, 'I think so.');
    });
  });
}
