import 'package:echo_loop/models/dictionary/dictionary_lookup_result.dart';
import 'package:echo_loop/services/dictionary/dictionary_source.dart';
import 'package:echo_loop/services/dictionary/web_dictionary_source.dart';
import 'package:flutter_test/flutter_test.dart';

/// 配置驱动网页词典源的纯逻辑测试：
/// 遍历全部配置，校验 id 稳定、可禁用、URL 拼接与编码、结果 sourceId 一致。
void main() {
  test('配置表非空且 id 唯一', () {
    expect(kWebDictConfigs, isNotEmpty);
    final ids = kWebDictConfigs.map((c) => c.id).toList();
    expect(ids.toSet().length, ids.length, reason: 'id 必须唯一');
  });

  test('德语版只保留 6 个德语网页源，英文专用站与有道全部移除', () {
    final ids = kWebDictConfigs.map((c) => c.id).toList();
    expect(ids, [
      'dehelper',
      'duden',
      'dwds',
      'eudic',
      'wiktionary',
      'zhwiktionary',
    ]);
    // 顺序即底栏展示顺序：德语权威源在前
    expect(ids.take(3), ['dehelper', 'duden', 'dwds']);
    for (final removed in [
      'cambridge',
      'oxford',
      'longman',
      'merriamWebster',
      'collins',
      'britannica',
      'vocabulary',
      'ozdic',
      'playPhrase',
      'forvo',
      'wordReference',
      'youdao',
      'etymonline',
      'macmillan',
    ]) {
      expect(ids.contains(removed), isFalse, reason: '$removed 应已移除');
    }
  });

  test('德语源使用德语词条 URL 模板', () async {
    for (final entry in {
      'duden': 'https://www.duden.de/suchen/dudenonline/Haus',
      'dwds': 'https://www.dwds.de/wb/Haus',
      'wiktionary': 'https://de.m.wiktionary.org/wiki/Haus',
      'zhwiktionary': 'https://zh.m.wiktionary.org/wiki/Haus',
    }.entries) {
      final source = WebDictionarySource(
        kWebDictConfigs.singleWhere((config) => config.id == entry.key),
      );
      final result =
          await source.lookup(const DictionaryLookupRequest(word: 'Haus'))
              as WebDictResult;
      expect(result.url.toString(), entry.value, reason: entry.key);
    }
  });

  test('欧路德语使用德汉词条 URL 并编码词组空格', () async {
    final source = WebDictionarySource(
      kWebDictConfigs.singleWhere((config) => config.id == 'eudic'),
    );
    final result = await source.lookup(
      const DictionaryLookupRequest(word: 'ice cream'),
    );

    if (result case WebDictResult(:final sourceId, :final url)) {
      expect(sourceId, 'eudic');
      expect(url.toString(), 'https://dict.eudic.net/mdicts/de/ice%20cream');
    } else {
      fail('Expected an Eudic web dictionary result.');
    }
  });

  for (final config in kWebDictConfigs) {
    group('WebDictionarySource(${config.id})', () {
      final source = WebDictionarySource(config);

      test('源契约：id 稳定、可禁用、需联网', () {
        expect(source.id, config.id);
        expect(source.canBeDisabled, isTrue);
        expect(source.requiresNetwork, isTrue);
        expect(source.icon, config.icon);
      });

      test('lookup 返回 WebDictResult 且 sourceId 一致', () async {
        final result = await source.lookup(
          const DictionaryLookupRequest(word: 'nice'),
        );
        expect(result, isA<WebDictResult>());
        final web = result! as WebDictResult;
        expect(web.sourceId, config.id);
        expect(web.word, 'nice');
        expect(web.url.toString(), config.buildUrl('nice'));
      });

      test('对已归一化的查询词做 URL 编码（词内空格编码为 %20）', () async {
        // 归一化由 controller 统一完成，源只对 request.word 做 URL 编码
        final result =
            await source.lookup(
                  const DictionaryLookupRequest(word: 'a posteriori'),
                )
                as WebDictResult;
        expect(result.url.toString(), contains('a%20posteriori'));
        expect(result.url.toString(), isNot(contains(' ')));
      });
    });
  }
}
