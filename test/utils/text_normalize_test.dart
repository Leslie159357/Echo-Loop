import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/utils/text_normalize.dart';

void main() {
  group('normalizeForCache', () {
    test('去除首尾空白', () {
      expect(normalizeForCache('  hello world  '), 'hello world');
    });

    test('转换为小写', () {
      expect(normalizeForCache('Hello World'), 'hello world');
    });

    test('合并连续空白', () {
      expect(normalizeForCache('hello   world'), 'hello world');
    });

    test('去除尾部标点', () {
      expect(normalizeForCache('hello world.'), 'hello world');
      expect(normalizeForCache('hello world!'), 'hello world');
      expect(normalizeForCache('hello world?'), 'hello world');
      expect(normalizeForCache('hello world;'), 'hello world');
      expect(normalizeForCache('hello world:'), 'hello world');
      expect(normalizeForCache('hello world...'), 'hello world');
    });

    test('不去除中间标点', () {
      expect(normalizeForCache('hello, world'), 'hello, world');
      expect(normalizeForCache("it's a test"), "it's a test");
    });

    test('综合归一化', () {
      expect(
        normalizeForCache('  Hello,  World!  '),
        'hello, world',
      );
    });

    test('空字符串', () {
      expect(normalizeForCache(''), '');
    });

    test('纯空白字符串', () {
      expect(normalizeForCache('   '), '');
    });
  });

  group('hashText', () {
    test('相同文本生成相同哈希', () {
      final hash1 = hashText('Hello World');
      final hash2 = hashText('Hello World');
      expect(hash1, hash2);
    });

    test('归一化后相同的文本生成相同哈希', () {
      final hash1 = hashText('Hello World.');
      final hash2 = hashText('  hello   world  ');
      expect(hash1, hash2);
    });

    test('不同文本生成不同哈希', () {
      final hash1 = hashText('Hello');
      final hash2 = hashText('World');
      expect(hash1, isNot(hash2));
    });

    test('哈希值为 64 字符十六进制字符串', () {
      final hash = hashText('test');
      expect(hash.length, 64);
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(hash), isTrue);
    });

    test('空字符串也能正常哈希', () {
      final hash = hashText('');
      expect(hash.length, 64);
    });
  });
}
