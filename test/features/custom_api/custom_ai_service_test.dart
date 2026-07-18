import 'package:dio/dio.dart';
import 'package:echo_loop/features/custom_api/custom_ai_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  test(
    'uses the configured model and requests JSON without sampling fields',
    () async {
      final dio = _MockDio();
      when(
        () => dio.post<Map<String, dynamic>>(
          'chat/completions',
          data: any(named: 'data'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: 'chat/completions'),
          data: {
            'choices': [
              {
                'message': {
                  'content': '{"translation":"你好"}',
                },
              },
            ],
          },
        ),
      );
      final service = CustomAiService.withDio(dio, model: 'gpt-5.6');

      final result = await service.translate(
        text: 'Hello',
        targetLanguage: 'zh-CN',
      );

      expect(result['translation'], '你好');
      final captured = verify(
        () => dio.post<Map<String, dynamic>>(
          'chat/completions',
          data: captureAny(named: 'data'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).captured.single;
      if (captured is! Map<String, dynamic>) {
        fail('Expected a JSON request map');
      }
      final request = captured;
      expect(request['model'], 'gpt-5.6');
      expect(request['response_format'], {'type': 'json_object'});
      expect(request, isNot(contains('temperature')));
    },
  );

  test(
    'accepts JSON wrapped in a markdown fence from compatible providers',
    () async {
      final dio = _MockDio();
      when(
        () => dio.post<Map<String, dynamic>>(
          'chat/completions',
          data: any(named: 'data'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: 'chat/completions'),
          data: {
            'choices': [
              {
                'message': {
                  'content':
                      '```json\n{"medium":["Hello"],"fine":["Hello"]}\n```',
                },
              },
            ],
          },
        ),
      );
      final service = CustomAiService.withDio(
        dio,
        model: 'compatible-model',
      );

      final result = await service.senseGroups(text: 'Hello');

      expect(result['medium'], ['Hello']);
    },
  );
}
