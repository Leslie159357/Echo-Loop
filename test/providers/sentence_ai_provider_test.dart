import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fluency/database/daos/sentence_ai_cache_dao.dart';
import 'package:fluency/models/sentence_ai_result.dart';
import 'package:fluency/providers/sentence_ai_provider.dart';
import 'package:fluency/services/sentence_ai_api_client.dart';
import 'package:fluency/utils/text_normalize.dart';

class MockCacheDao extends Mock implements SentenceAiCacheDao {}

class MockApiClient extends Mock implements SentenceAiApiClient {}

void main() {
  late MockCacheDao mockDao;
  late MockApiClient mockApi;
  late SentenceAiNotifier notifier;

  setUp(() {
    mockDao = MockCacheDao();
    mockApi = MockApiClient();
    notifier = SentenceAiNotifier(cacheDao: mockDao, apiClient: mockApi);
  });

  group('getTranslation', () {
    const text = 'Hello world';

    test('L1 内存缓存命中', () async {
      // 预填充 L1
      when(
        () => mockDao.getByHash(any(), 'translation'),
      ).thenAnswer((_) async => null);
      when(
        () => mockApi.translate(text, cancelToken: any(named: 'cancelToken')),
      ).thenAnswer(
        (_) async => const SentenceTranslation(translation: '你好世界'),
      );
      when(
        () => mockDao.upsert(any(), 'translation', any()),
      ).thenAnswer((_) async {});

      // 第一次：API 调用
      await notifier.getTranslation(text);

      // 第二次：L1 命中，不再调 DAO 或 API
      final result = await notifier.getTranslation(text);
      expect(result.translation, '你好世界');

      // API 只调了一次
      verify(
        () => mockApi.translate(text, cancelToken: any(named: 'cancelToken')),
      ).called(1);
    });

    test('L2 SQLite 缓存命中', () async {
      when(
        () => mockDao.getByHash(any(), 'translation'),
      ).thenAnswer((_) async => '{"translation":"你好世界"}');

      final result = await notifier.getTranslation(text);
      expect(result.translation, '你好世界');

      // 不应调用 API
      verifyNever(
        () => mockApi.translate(any(), cancelToken: any(named: 'cancelToken')),
      );
    });

    test('L3 API 调用并写入缓存', () async {
      when(
        () => mockDao.getByHash(any(), 'translation'),
      ).thenAnswer((_) async => null);
      when(
        () => mockApi.translate(text, cancelToken: any(named: 'cancelToken')),
      ).thenAnswer(
        (_) async => const SentenceTranslation(translation: '你好世界'),
      );
      when(
        () => mockDao.upsert(any(), 'translation', any()),
      ).thenAnswer((_) async {});

      final result = await notifier.getTranslation(text);
      expect(result.translation, '你好世界');

      // 验证写入 SQLite
      verify(() => mockDao.upsert(any(), 'translation', any())).called(1);

      // 验证 L1 也已缓存
      expect(notifier.getCachedTranslation(text)?.translation, '你好世界');
    });

    test('并发请求去重', () async {
      final completer = Completer<SentenceTranslation>();

      when(
        () => mockDao.getByHash(any(), 'translation'),
      ).thenAnswer((_) async => null);
      when(
        () => mockApi.translate(text, cancelToken: any(named: 'cancelToken')),
      ).thenAnswer((_) => completer.future);
      when(
        () => mockDao.upsert(any(), 'translation', any()),
      ).thenAnswer((_) async {});

      // 同时发起两个请求
      final f1 = notifier.getTranslation(text);
      final f2 = notifier.getTranslation(text);

      completer.complete(const SentenceTranslation(translation: '你好'));

      final r1 = await f1;
      final r2 = await f2;

      expect(r1.translation, '你好');
      expect(r2.translation, '你好');

      // API 只被调了一次
      verify(
        () => mockApi.translate(text, cancelToken: any(named: 'cancelToken')),
      ).called(1);
    });
  });

  group('getAnalysis', () {
    const text = 'She has been studying.';

    test('L2 SQLite 缓存命中', () async {
      when(
        () => mockDao.getByHash(any(), 'analysis'),
      ).thenAnswer(
        (_) async =>
            '{"analysis":{"grammar":"现在完成进行时","vocabulary":"study","listening":"持续动作"}}',
      );

      final result = await notifier.getAnalysis(text);
      expect(result.grammar, '现在完成进行时');
      expect(result.vocabulary, 'study');
      expect(result.listening, '持续动作');
    });

    test('L3 API 调用', () async {
      when(
        () => mockDao.getByHash(any(), 'analysis'),
      ).thenAnswer((_) async => null);
      when(
        () => mockApi.analyze(text, cancelToken: any(named: 'cancelToken')),
      ).thenAnswer(
        (_) async => const SentenceAnalysis(
          grammar: 'g',
          vocabulary: 'v',
          listening: 'u',
        ),
      );
      when(
        () => mockDao.upsert(any(), 'analysis', any()),
      ).thenAnswer((_) async {});

      final result = await notifier.getAnalysis(text);
      expect(result.grammar, 'g');

      verify(() => mockDao.upsert(any(), 'analysis', any())).called(1);
    });
  });

  group('getCachedTranslation / getCachedAnalysis', () {
    test('无缓存时返回 null', () {
      expect(notifier.getCachedTranslation('test'), isNull);
      expect(notifier.getCachedAnalysis('test'), isNull);
    });
  });

  group('clearMemoryCache', () {
    test('清除后 getCachedTranslation 返回 null', () async {
      when(
        () => mockDao.getByHash(any(), 'translation'),
      ).thenAnswer((_) async => null);
      when(
        () => mockApi.translate(any(), cancelToken: any(named: 'cancelToken')),
      ).thenAnswer(
        (_) async => const SentenceTranslation(translation: 't'),
      );
      when(
        () => mockDao.upsert(any(), any(), any()),
      ).thenAnswer((_) async {});

      await notifier.getTranslation('test');
      expect(notifier.getCachedTranslation('test'), isNotNull);

      notifier.clearMemoryCache();
      expect(notifier.getCachedTranslation('test'), isNull);
    });
  });

  group('getAnalysis 对称性', () {
    const text = 'She has been studying.';

    test('L1 内存缓存命中直接返回', () async {
      // 预填充 L1：先走一次完整流程
      when(
        () => mockDao.getByHash(any(), 'analysis'),
      ).thenAnswer((_) async => null);
      when(
        () => mockApi.analyze(text, cancelToken: any(named: 'cancelToken')),
      ).thenAnswer(
        (_) async => const SentenceAnalysis(
          grammar: 'g',
          vocabulary: 'v',
          listening: 'u',
        ),
      );
      when(
        () => mockDao.upsert(any(), 'analysis', any()),
      ).thenAnswer((_) async {});

      // 第一次：API 调用写入 L1
      await notifier.getAnalysis(text);

      // 重置 mock 交互记录
      reset(mockDao);
      reset(mockApi);

      // 第二次：L1 命中，不查 DB 也不调 API
      final result = await notifier.getAnalysis(text);
      expect(result.grammar, 'g');

      verifyNever(() => mockDao.getByHash(any(), any()));
      verifyNever(
        () => mockApi.analyze(any(), cancelToken: any(named: 'cancelToken')),
      );
    });

    test('并发请求同一句子复用 Future', () async {
      final completer = Completer<SentenceAnalysis>();

      when(
        () => mockDao.getByHash(any(), 'analysis'),
      ).thenAnswer((_) async => null);
      when(
        () => mockApi.analyze(text, cancelToken: any(named: 'cancelToken')),
      ).thenAnswer((_) => completer.future);
      when(
        () => mockDao.upsert(any(), 'analysis', any()),
      ).thenAnswer((_) async {});

      // 同时发起两个请求
      final f1 = notifier.getAnalysis(text);
      final f2 = notifier.getAnalysis(text);

      completer.complete(const SentenceAnalysis(
        grammar: 'g',
        vocabulary: 'v',
        listening: 'u',
      ));

      final r1 = await f1;
      final r2 = await f2;

      expect(r1.grammar, 'g');
      expect(r2.grammar, 'g');

      // API 只被调了一次
      verify(
        () => mockApi.analyze(text, cancelToken: any(named: 'cancelToken')),
      ).called(1);
    });
  });

  group('失败处理', () {
    test('getTranslation API 失败时不写入缓存', () async {
      when(
        () => mockDao.getByHash(any(), 'translation'),
      ).thenAnswer((_) async => null);
      when(
        () => mockApi.translate(any(), cancelToken: any(named: 'cancelToken')),
      ).thenThrow(Exception('network error'));

      // API 抛异常
      expect(
        () => notifier.getTranslation('fail test'),
        throwsA(isA<Exception>()),
      );

      // 等待异步操作完成
      await Future<void>.delayed(Duration.zero);

      // L1 内存缓存应为空
      expect(notifier.getCachedTranslation('fail test'), isNull);
    });

    test('clearMemoryCache 同时清除 analysis 缓存', () async {
      // 写入 translation
      when(
        () => mockDao.getByHash(any(), 'translation'),
      ).thenAnswer((_) async => null);
      when(
        () => mockApi.translate(any(), cancelToken: any(named: 'cancelToken')),
      ).thenAnswer(
        (_) async => const SentenceTranslation(translation: 't'),
      );
      when(
        () => mockDao.upsert(any(), any(), any()),
      ).thenAnswer((_) async {});

      // 写入 analysis
      when(
        () => mockDao.getByHash(any(), 'analysis'),
      ).thenAnswer((_) async => null);
      when(
        () => mockApi.analyze(any(), cancelToken: any(named: 'cancelToken')),
      ).thenAnswer(
        (_) async => const SentenceAnalysis(
          grammar: 'g',
          vocabulary: 'v',
          listening: 'u',
        ),
      );

      await notifier.getTranslation('test');
      await notifier.getAnalysis('test');

      // 确认两者都有缓存
      expect(notifier.getCachedTranslation('test'), isNotNull);
      expect(notifier.getCachedAnalysis('test'), isNotNull);

      // 清除后两者都为 null
      notifier.clearMemoryCache();
      expect(notifier.getCachedTranslation('test'), isNull);
      expect(notifier.getCachedAnalysis('test'), isNull);
    });
  });

  group('hashText 一致性', () {
    test('归一化后相同的文本命中同一缓存', () async {
      when(
        () => mockDao.getByHash(any(), 'translation'),
      ).thenAnswer((_) async => null);
      when(
        () => mockApi.translate(any(), cancelToken: any(named: 'cancelToken')),
      ).thenAnswer(
        (_) async => const SentenceTranslation(translation: 'x'),
      );
      when(
        () => mockDao.upsert(any(), any(), any()),
      ).thenAnswer((_) async {});

      await notifier.getTranslation('Hello World.');

      // 归一化后与 "hello world." 和 "  HELLO   WORLD.  " 相同
      final hash1 = hashText('Hello World.');
      final hash2 = hashText('  HELLO   WORLD  ');
      expect(hash1, hash2);

      // L1 缓存应命中
      final cached = notifier.getCachedTranslation('  HELLO   WORLD  ');
      expect(cached?.translation, 'x');
    });
  });
}
