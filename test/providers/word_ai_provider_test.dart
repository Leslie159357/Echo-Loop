import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:echo_loop/database/daos/sentence_ai_cache_dao.dart';
import 'package:echo_loop/models/word_analysis.dart';
import 'package:echo_loop/providers/word_ai_provider.dart';
import 'package:echo_loop/services/sentence_ai_api_client.dart';

class MockCacheDao extends Mock implements SentenceAiCacheDao {}

class MockApiClient extends Mock implements SentenceAiApiClient {}

void main() {
  late MockCacheDao mockDao;
  late MockApiClient mockApi;
  late WordAiNotifier notifier;

  setUp(() {
    mockDao = MockCacheDao();
    mockApi = MockApiClient();
    notifier = WordAiNotifier(cacheDao: mockDao, apiClient: mockApi);
  });

  group('getWordAnalysis', () {
    const word = 'run';

    test('L1 内存缓存命中', () async {
      // 预填充 L1：先走一次完整流程
      when(
        () => mockDao.getByHash(any(), 'word_analysis'),
      ).thenAnswer((_) async => null);
      when(
        () => mockApi.analyzeWord(
          word,
          sentence: any(named: 'sentence'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) async => const WordAnalysis(contextMeaning: '经营'));
      when(
        () => mockDao.upsert(any(), 'word_analysis', any()),
      ).thenAnswer((_) async {});

      // 第一次：API 调用
      await notifier.getWordAnalysis(word);

      // 第二次：L1 命中，不再调 DAO 或 API
      final result = await notifier.getWordAnalysis(word);
      expect(result.contextMeaning, '经营');

      // API 只调了一次
      verify(
        () => mockApi.analyzeWord(
          word,
          sentence: any(named: 'sentence'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).called(1);
    });

    test('L2 SQLite 缓存命中', () async {
      when(() => mockDao.getByHash(any(), 'word_analysis')).thenAnswer(
        (_) async =>
            '{"analysis":{"contextMeaning":"经营","collocations":null,"usage":null,"wordFamily":null}}',
      );

      final result = await notifier.getWordAnalysis(word);
      expect(result.contextMeaning, '经营');
      expect(result.collocations, isNull);

      // 不应调用 API
      verifyNever(
        () => mockApi.analyzeWord(
          any(),
          sentence: any(named: 'sentence'),
          cancelToken: any(named: 'cancelToken'),
        ),
      );
    });

    test('L3 API 调用并写入 L1 + L2', () async {
      when(
        () => mockDao.getByHash(any(), 'word_analysis'),
      ).thenAnswer((_) async => null);
      when(
        () => mockApi.analyzeWord(
          word,
          sentence: any(named: 'sentence'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer(
        (_) async => const WordAnalysis(
          contextMeaning: '经营',
          collocations: 'run a business',
        ),
      );
      when(
        () => mockDao.upsert(any(), 'word_analysis', any()),
      ).thenAnswer((_) async {});

      final result = await notifier.getWordAnalysis(word);
      expect(result.contextMeaning, '经营');
      expect(result.collocations, 'run a business');

      // 验证写入 SQLite
      verify(() => mockDao.upsert(any(), 'word_analysis', any())).called(1);

      // 验证 L1 也已缓存
      expect(notifier.getCachedWordAnalysis(word)?.contextMeaning, '经营');
    });

    test('并发请求去重', () async {
      final completer = Completer<WordAnalysis>();

      when(
        () => mockDao.getByHash(any(), 'word_analysis'),
      ).thenAnswer((_) async => null);
      when(
        () => mockApi.analyzeWord(
          word,
          sentence: any(named: 'sentence'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) => completer.future);
      when(
        () => mockDao.upsert(any(), 'word_analysis', any()),
      ).thenAnswer((_) async {});

      // 同时发起两个请求
      final f1 = notifier.getWordAnalysis(word);
      final f2 = notifier.getWordAnalysis(word);

      completer.complete(const WordAnalysis(contextMeaning: '经营'));

      final r1 = await f1;
      final r2 = await f2;

      expect(r1.contextMeaning, '经营');
      expect(r2.contextMeaning, '经营');

      // API 只被调了一次
      verify(
        () => mockApi.analyzeWord(
          word,
          sentence: any(named: 'sentence'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).called(1);
    });

    test('L2 数据损坏时 fallthrough 到 L3', () async {
      // L2 返回非法 JSON
      when(
        () => mockDao.getByHash(any(), 'word_analysis'),
      ).thenAnswer((_) async => '这不是合法的JSON');
      when(
        () => mockApi.analyzeWord(
          any(),
          sentence: any(named: 'sentence'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) async => const WordAnalysis(contextMeaning: '来自API'));
      when(
        () => mockDao.upsert(any(), 'word_analysis', any()),
      ).thenAnswer((_) async {});

      final result = await notifier.getWordAnalysis(word);
      expect(result.contextMeaning, '来自API');

      // 应该 fallthrough 到 API
      verify(
        () => mockApi.analyzeWord(
          word,
          sentence: any(named: 'sentence'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).called(1);
    });

    test('API 异常向上传播', () async {
      when(
        () => mockDao.getByHash(any(), 'word_analysis'),
      ).thenAnswer((_) async => null);
      when(
        () => mockApi.analyzeWord(
          any(),
          sentence: any(named: 'sentence'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenThrow(Exception('network error'));

      expect(() => notifier.getWordAnalysis('fail'), throwsA(isA<Exception>()));

      await Future<void>.delayed(Duration.zero);

      // L1 缓存应为空
      expect(notifier.getCachedWordAnalysis('fail'), isNull);
    });
  });

  group('getCachedWordAnalysis', () {
    test('L1 有缓存', () async {
      when(
        () => mockDao.getByHash(any(), 'word_analysis'),
      ).thenAnswer((_) async => null);
      when(
        () => mockApi.analyzeWord(
          any(),
          sentence: any(named: 'sentence'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) async => const WordAnalysis(contextMeaning: '测试'));
      when(
        () => mockDao.upsert(any(), 'word_analysis', any()),
      ).thenAnswer((_) async {});

      await notifier.getWordAnalysis('test');
      final cached = notifier.getCachedWordAnalysis('test');
      expect(cached?.contextMeaning, '测试');
    });

    test('L1 无缓存', () {
      expect(notifier.getCachedWordAnalysis('nonexistent'), isNull);
    });
  });
}
