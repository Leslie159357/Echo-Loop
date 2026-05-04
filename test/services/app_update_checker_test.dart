import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/services/app_update_checker.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio mockDio;
  late AppUpdateChecker checker;

  setUp(() {
    mockDio = MockDio();
    checker = AppUpdateChecker.withDio(mockDio);
  });

  group('AppUpdateChecker.check', () {
    test('成功解析有效 JSON', () async {
      when(() => mockDio.get<Map<String, dynamic>>(any())).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(),
          data: {
            'latestVersion': '1.1.0',
            'minimumVersion': '1.0.0',
            'releaseNotes': {'en': 'Bug fixes'},
            'downloadUrl': {'fallback': 'https://example.com'},
          },
        ),
      );

      final result = await checker.check();

      expect(result, isNotNull);
      expect(result!.latestVersion, '1.1.0');
      expect(result.minimumVersion, '1.0.0');
    });

    test('网络错误返回 null', () async {
      when(() => mockDio.get<Map<String, dynamic>>(any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      final result = await checker.check();
      expect(result, isNull);
    });

    test('响应数据为 null 返回 null', () async {
      when(() => mockDio.get<Map<String, dynamic>>(any())).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(),
          data: null,
        ),
      );

      final result = await checker.check();
      expect(result, isNull);
    });

    test('JSON 格式错误返回 null', () async {
      when(() => mockDio.get<Map<String, dynamic>>(any())).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(),
          data: <String, dynamic>{'invalid': true},
        ),
      );

      final result = await checker.check();
      expect(result, isNull);
    });

    test('DNS 解析失败返回 null', () async {
      when(() => mockDio.get<Map<String, dynamic>>(any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(),
          type: DioExceptionType.unknown,
          error: 'Failed host lookup',
        ),
      );

      final result = await checker.check();
      expect(result, isNull);
    });
  });
}
