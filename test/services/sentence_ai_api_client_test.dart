import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:echo_loop/models/dictionary/dictionary_entry.dart';
import 'package:echo_loop/services/dictionary/dictionary_source.dart';
import 'package:echo_loop/services/sentence_ai_api_client.dart';

class MockDio extends Mock implements Dio {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockDio mockDio;
  late SentenceAiApiClient client;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockDio = MockDio();
    client = SentenceAiApiClient.withDio(mockDio);
  });

  group('translate', () {
    test('正常响应返回 SentenceTranslation', () async {
      when(
        () => mockDio.post<Map<String, dynamic>>(
          '/api/v2/ai/translate',
          data: {'text': 'Hello world'},
          options: any(
            named: 'options',
            that: isA<Options>().having(
              (o) => o.headers?['Authorization'],
              'Authorization',
              'Bearer access-token',
            ),
          ),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer(
        (_) async => Response(
          data: {'translation': '你好世界'},
          statusCode: 200,
          requestOptions: RequestOptions(),
        ),
      );

      final result = await client.translate(
        'Hello world',
        accessToken: 'access-token',
      );
      expect(result.translation, '你好世界');
    });

    test('服务器错误抛出 DioException', () async {
      when(
        () => mockDio.post<Map<String, dynamic>>(
          '/api/v2/ai/translate',
          data: {'text': 'test'},
          options: any(named: 'options'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenThrow(
        DioException(
          type: DioExceptionType.badResponse,
          requestOptions: RequestOptions(),
          response: Response(statusCode: 500, requestOptions: RequestOptions()),
        ),
      );

      expect(
        () => client.translate('test', accessToken: 'access-token'),
        throwsA(isA<DioException>()),
      );
    });

    test('支持 CancelToken', () async {
      final cancelToken = CancelToken();

      when(
        () => mockDio.post<Map<String, dynamic>>(
          '/api/v2/ai/translate',
          data: {'text': 'test'},
          options: any(named: 'options'),
          cancelToken: cancelToken,
        ),
      ).thenThrow(
        DioException(
          type: DioExceptionType.cancel,
          requestOptions: RequestOptions(),
        ),
      );

      expect(
        () => client.translate(
          'test',
          accessToken: 'access-token',
          cancelToken: cancelToken,
        ),
        throwsA(
          isA<DioException>().having(
            (e) => e.type,
            'type',
            DioExceptionType.cancel,
          ),
        ),
      );
    });
  });

  group('analyze', () {
    test('正常响应返回 SentenceAnalysis', () async {
      when(
        () => mockDio.post<Map<String, dynamic>>(
          '/api/v2/ai/analyze',
          data: {'text': 'She has been studying.'},
          options: any(
            named: 'options',
            that: isA<Options>().having(
              (o) => o.headers?['Authorization'],
              'Authorization',
              'Bearer access-token',
            ),
          ),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer(
        (_) async => Response(
          data: {
            'analysis': {
              'grammar': '现在完成进行时',
              'vocabulary': 'study: 学习',
              'listening': '表示持续进行的动作',
            },
          },
          statusCode: 200,
          requestOptions: RequestOptions(),
        ),
      );

      final result = await client.analyze(
        'She has been studying.',
        accessToken: 'access-token',
      );
      expect(result.grammar, '现在完成进行时');
      expect(result.vocabulary, 'study: 学习');
      expect(result.listening, '表示持续进行的动作');
    });

    test('服务器错误抛出 DioException', () async {
      when(
        () => mockDio.post<Map<String, dynamic>>(
          '/api/v2/ai/analyze',
          data: {'text': 'test'},
          options: any(named: 'options'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenThrow(
        DioException(
          type: DioExceptionType.connectionTimeout,
          requestOptions: RequestOptions(),
        ),
      );

      expect(
        () => client.analyze('test', accessToken: 'access-token'),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('splitSenseGroups', () {
    test('调用 v2 认证接口并发送 Bearer token', () async {
      when(
        () => mockDio.post<Map<String, dynamic>>(
          '/api/v2/ai/sense-groups',
          data: {'text': 'Hello world'},
          options: any(
            named: 'options',
            that: isA<Options>().having(
              (o) => o.headers?['Authorization'],
              'Authorization',
              'Bearer access-token',
            ),
          ),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer(
        (_) async => Response(
          data: {
            'medium': ['Hello world'],
            'fine': ['Hello', 'world'],
          },
          statusCode: 200,
          requestOptions: RequestOptions(),
        ),
      );

      final result = await client.splitSenseGroups(
        'Hello world',
        accessToken: 'access-token',
      );

      expect(result.medium, ['Hello world']);
      expect(result.fine, ['Hello', 'world']);
    });
  });

  group('流式查词', () {
    /// 构造一个 NDJSON 字节流响应
    Response<ResponseBody> ndjsonResponse(String ndjson, {int status = 200}) {
      final bytes = Uint8List.fromList(utf8.encode(ndjson));
      return Response(
        data: ResponseBody(Stream<Uint8List>.fromIterable([bytes]), status),
        statusCode: status,
        requestOptions: RequestOptions(),
      );
    }

    /// 构造一个 ops 增量批行：{"ops":[{p,v},...]}
    String opsLine(List<Map<String, dynamic>> ops) =>
        '${jsonEncode({'ops': ops})}\n';

    test(
      'lookupWordStream 打到 /api/v1/stream/lookup-word，ops 批逐帧 yield',
      () async {
        when(
          () => mockDio.post<ResponseBody>(
            '/api/v1/stream/lookup-word',
            data: any(named: 'data'),
            options: any(named: 'options'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer(
          (_) async => ndjsonResponse(
            '${jsonEncode({'q': 'single_word'})}\n'
            '${opsLine([
              {
                'p': ['headword'],
                'v': 'run',
              },
            ])}'
            '${opsLine([
              {
                'p': ['etymology'],
                'v': 'x',
              },
            ])}',
          ),
        );

        final frames = await client
            .lookupWordStream('run', accessToken: 'tok')
            .toList();

        // 元信息帧不 yield；两个 ops 批各 yield 一帧
        expect(frames.length, 2);
        expect(frames.first.headword, 'run');
        expect(frames.last.headword, 'run');
      },
    );

    test('单个 ops 批含多个叶子 → 只 yield 一帧且全部生效', () async {
      when(
        () => mockDio.post<ResponseBody>(
          '/api/v1/stream/lookup-word',
          data: any(named: 'data'),
          options: any(named: 'options'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer(
        (_) async => ndjsonResponse(
          '${jsonEncode({'q': 'single_word'})}\n'
          '${opsLine([
            {
              'p': ['headword'],
              'v': 'run',
            },
            {
              'p': ['etymology'],
              'v': 'x',
            },
          ])}'
          '${jsonEncode({'done': true})}\n',
        ),
      );

      final frames = await client
          .lookupWordStreamFrames('run', accessToken: 'tok')
          .toList();

      // 一个多叶子 ops 批 → 1 帧；+ done 帧 = 2
      expect(frames.length, 2);
      final entry = frames.last.entry as DictionaryEntry;
      expect(entry.headword, 'run');
      expect(entry.etymology, 'x');
    });

    test('lookupWordStreamFrames：done 帧标记 isFinal，累积后 entry 无协议字段', () async {
      when(
        () => mockDio.post<ResponseBody>(
          '/api/v1/stream/lookup-word',
          data: any(named: 'data'),
          options: any(named: 'options'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer(
        (_) async => ndjsonResponse(
          '${jsonEncode({'q': 'single_word'})}\n'
          '${opsLine([
            {
              'p': ['headword'],
              'v': 'run',
            },
          ])}'
          '${opsLine([
            {
              'p': ['etymology'],
              'v': 'x',
            },
          ])}'
          '${jsonEncode({'done': true})}\n',
        ),
      );

      final frames = await client
          .lookupWordStreamFrames('run', accessToken: 'tok')
          .toList();

      // 两个 ops 批帧（isFinal=false）+ done 帧（isFinal=true）
      expect(frames.length, 3);
      expect(frames.first.isFinal, isFalse);
      expect(frames.last.isFinal, isTrue);
      final json = frames.last.entry.toJson();
      expect(json, isNot(contains('__final')));
      expect(json, isNot(contains('ops')));
      expect(json, isNot(contains('done')));
      expect(frames.last.entry.headword, 'run');
    });

    test('lookupPhraseStream 打到 /api/v1/stream/lookup-phrase', () async {
      when(
        () => mockDio.post<ResponseBody>(
          '/api/v1/stream/lookup-phrase',
          data: any(named: 'data'),
          options: any(named: 'options'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer(
        (_) async => ndjsonResponse(
          '${jsonEncode({'q': 'multi_word'})}\n'
          '${opsLine([
            {
              'p': ['originalExpression'],
              'v': 'break a leg',
            },
          ])}',
        ),
      );

      final frames = await client
          .lookupPhraseStream('break a leg', accessToken: 'tok')
          .toList();

      expect(frames.length, 1);
      expect(frames.first.headword, 'break a leg');
    });

    test('嵌套叶子路径累积成正确的嵌套结构', () async {
      when(
        () => mockDio.post<ResponseBody>(
          '/api/v1/stream/lookup-word',
          data: any(named: 'data'),
          options: any(named: 'options'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer(
        (_) async => ndjsonResponse(
          '${jsonEncode({'q': 'single_word'})}\n'
          '${opsLine([
            {
              'p': ['headword'],
              'v': 'run',
            },
            {
              'p': ['meanings', 0, 'definition'],
              'v': '奔跑',
            },
          ])}'
          '${opsLine([
            {
              'p': ['meanings', 0, 'examples', 0, 'sentence'],
              'v': 'I run.',
            },
            {
              'p': ['meanings', 0, 'examples', 0, 'translation'],
              'v': '我跑。',
            },
          ])}'
          '${jsonEncode({'done': true})}\n',
        ),
      );

      final frames = await client
          .lookupWordStreamFrames('run', accessToken: 'tok')
          .toList();

      final entry = frames.last.entry as DictionaryEntry;
      expect(entry.headword, 'run');
      expect(entry.meanings.single.definition, '奔跑');
      expect(entry.meanings.single.examples.single.sentence, 'I run.');
      expect(entry.meanings.single.examples.single.translation, '我跑。');
    });

    test('流内 __error 帧 → 抛 DictionaryStreamException', () async {
      when(
        () => mockDio.post<ResponseBody>(
          '/api/v1/stream/lookup-word',
          data: any(named: 'data'),
          options: any(named: 'options'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer(
        (_) async => ndjsonResponse(
          '${jsonEncode({'headword': 'run', 'queryType': 'single_word'})}\n'
          '${jsonEncode({'__error': 'unavailable'})}\n',
        ),
      );

      await expectLater(
        client.lookupWordStream('run', accessToken: 'tok').toList(),
        throwsA(isA<DictionaryStreamException>()),
      );
    });

    test('损坏 NDJSON → 抛 DictionaryStreamException', () async {
      when(
        () => mockDio.post<ResponseBody>(
          '/api/v1/stream/lookup-word',
          data: any(named: 'data'),
          options: any(named: 'options'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) async => ndjsonResponse('{"headword":\n'));

      await expectLater(
        client.lookupWordStream('run', accessToken: 'tok').toList(),
        throwsA(isA<DictionaryStreamException>()),
      );
    });

    test(
      '400 + code=phrase_too_long → DictionaryPhraseTooLongException',
      () async {
        when(
          () => mockDio.post<ResponseBody>(
            '/api/v1/stream/lookup-phrase',
            data: any(named: 'data'),
            options: any(named: 'options'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer(
          (_) async => ndjsonResponse(
            jsonEncode({'error': 'too long', 'code': 'phrase_too_long'}),
            status: 400,
          ),
        );

        await expectLater(
          client.lookupPhraseStream('a b c', accessToken: 'tok').toList(),
          throwsA(isA<DictionaryPhraseTooLongException>()),
        );
      },
    );

    test('401 → DictionaryAuthRequiredException', () async {
      when(
        () => mockDio.post<ResponseBody>(
          '/api/v1/stream/lookup-word',
          data: any(named: 'data'),
          options: any(named: 'options'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer(
        (_) async =>
            ndjsonResponse(jsonEncode({'error': 'unauthorized'}), status: 401),
      );

      await expectLater(
        client.lookupWordStream('run', accessToken: 'tok').toList(),
        throwsA(isA<DictionaryAuthRequiredException>()),
      );
    });

    test('402 → 带状态码的 DioException（供 controller 转额度态）', () async {
      when(
        () => mockDio.post<ResponseBody>(
          '/api/v1/stream/lookup-word',
          data: any(named: 'data'),
          options: any(named: 'options'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer(
        (_) async => ndjsonResponse(
          jsonEncode({'error': 'quota', 'code': 'quota_exceeded'}),
          status: 402,
        ),
      );

      await expectLater(
        client.lookupWordStream('run', accessToken: 'tok').toList(),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'statusCode',
            402,
          ),
        ),
      );
    });
  });

  group('构造与销毁', () {
    test('普通构造函数创建实例', () {
      final c = SentenceAiApiClient(baseUrl: 'https://test.com');
      expect(c, isNotNull);
      c.dispose();
    });

    test('withDio 构造函数接受自定义 Dio', () {
      final dio = Dio(BaseOptions(baseUrl: 'https://mock.com'));
      final c = SentenceAiApiClient.withDio(dio);
      expect(c, isNotNull);
    });

    test('dispose 调用 Dio.close', () {
      when(
        () => mockDio.close(force: any(named: 'force')),
      ).thenAnswer((_) async {});
      client.dispose();
      verify(() => mockDio.close(force: false)).called(1);
    });
  });
}
