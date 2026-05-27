import 'dart:convert';

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

  group('AppUpdateChecker.check iOS Lookup API', () {
    late AppUpdateChecker iosChecker;

    setUp(() {
      iosChecker = AppUpdateChecker.withDio(
        mockDio,
        bundleId: 'top.echo-loop',
        useIosLookup: true,
      );
    });

    /// 桩 iTunes Lookup 响应：iOS 路径强制 ResponseType.plain，data 为字符串
    void stubLookup(Object data) {
      when(
        () => mockDio.get<String>(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<String>(
          requestOptions: RequestOptions(),
          data: jsonEncode(data),
        ),
      );
    }

    test('成功解析 Lookup API 响应', () async {
      stubLookup({
        'resultCount': 1,
        'results': [
          {
            'version': '1.0.12',
            'trackViewUrl': 'https://apps.apple.com/app/id6760324074',
            'releaseNotes': 'Bug fixes and improvements',
          },
        ],
      });

      final result = await iosChecker.check();

      expect(result, isNotNull);
      expect(result!.latestVersion, '1.0.12');
      // Lookup API 不提供 minimumVersion，回退为 0.0.0
      expect(result.minimumVersion, '0.0.0');
      // trackViewUrl 同时作为 ios 和 fallback
      expect(
        result.downloadUrl['ios'],
        'https://apps.apple.com/app/id6760324074',
      );
      expect(
        result.downloadUrl['fallback'],
        'https://apps.apple.com/app/id6760324074',
      );
      // releaseNotes 单语字符串同时映射给 en 和 zh
      expect(result.releaseNotes['en'], 'Bug fixes and improvements');
      expect(result.releaseNotes['zh'], 'Bug fixes and improvements');
    });

    test('results 为空数组返回 null', () async {
      stubLookup({'resultCount': 0, 'results': []});

      final result = await iosChecker.check();
      expect(result, isNull);
    });

    test('缺少 version 字段返回 null', () async {
      stubLookup({
        'results': [
          {'trackViewUrl': 'https://apps.apple.com/x'},
        ],
      });

      final result = await iosChecker.check();
      expect(result, isNull);
    });

    test('网络错误返回 null', () async {
      when(
        () => mockDio.get<String>(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      final result = await iosChecker.check();
      expect(result, isNull);
    });

    test('bundleId 为空返回 null', () async {
      final emptyChecker = AppUpdateChecker.withDio(
        mockDio,
        bundleId: '',
        useIosLookup: true,
      );

      final result = await emptyChecker.check();
      expect(result, isNull);
      verifyNever(
        () => mockDio.get<String>(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      );
    });

    test('releaseNotes 缺失时降级为空 Map', () async {
      stubLookup({
        'results': [
          {'version': '1.0.12', 'trackViewUrl': 'https://apps.apple.com/x'},
        ],
      });

      final result = await iosChecker.check();
      expect(result, isNotNull);
      expect(result!.releaseNotes, isEmpty);
    });

    test('trackViewUrl 缺失时使用默认 App Store 链接', () async {
      stubLookup({
        'results': [
          {'version': '1.0.12'},
        ],
      });

      final result = await iosChecker.check();
      expect(result, isNotNull);
      expect(result!.downloadUrl['ios'], contains('apps.apple.com'));
    });

    test('Content-Type 为 text/javascript 时也能解析（回归测试）', () async {
      // 真实环境 iTunes Lookup 返回 text/javascript，Dio 不会自动 JSON 解码
      // 这里模拟该场景：data 是裸 JSON 字符串而非 Map
      when(
        () => mockDio.get<String>(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<String>(
          requestOptions: RequestOptions(),
          data:
              '{"resultCount":1,"results":[{"version":"1.0.12","trackViewUrl":"https://apps.apple.com/app/id6760324074"}]}',
        ),
      );

      final result = await iosChecker.check();
      expect(result, isNotNull);
      expect(result!.latestVersion, '1.0.12');
    });

    test('响应不是合法 JSON 返回 null', () async {
      when(
        () => mockDio.get<String>(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<String>(
          requestOptions: RequestOptions(),
          data: 'not json at all',
        ),
      );

      final result = await iosChecker.check();
      expect(result, isNull);
    });

    test('version 不是 String 类型返回 null', () async {
      // 防御 Apple 改 schema：例如 version 变成数字
      stubLookup({
        'results': [
          {'version': 1.2, 'trackViewUrl': 'https://apps.apple.com/x'},
        ],
      });

      final result = await iosChecker.check();
      expect(result, isNull);
    });

    test('传入 country 时作为查询参数发出', () async {
      stubLookup({
        'results': [
          {'version': '1.0.12', 'trackViewUrl': 'https://apps.apple.com/x'},
        ],
      });

      await iosChecker.check(country: 'cn');

      final captured =
          verify(
                () => mockDio.get<String>(
                  any(),
                  queryParameters: captureAny(named: 'queryParameters'),
                  options: any(named: 'options'),
                ),
              ).captured.single
              as Map;
      expect(captured['country'], 'cn');
      expect(captured['bundleId'], 'top.echo-loop');
    });

    test('country 为 null 时不带 country 参数', () async {
      stubLookup({
        'results': [
          {'version': '1.0.12', 'trackViewUrl': 'https://apps.apple.com/x'},
        ],
      });

      await iosChecker.check();

      final captured =
          verify(
                () => mockDio.get<String>(
                  any(),
                  queryParameters: captureAny(named: 'queryParameters'),
                  options: any(named: 'options'),
                ),
              ).captured.single
              as Map;
      expect(captured.containsKey('country'), isFalse);
    });

    test('results[0] 不是 Map 返回 null', () async {
      // 防御上游数据脏：results 元素是字符串/数字而非对象
      stubLookup({
        'results': ['unexpected-string-entry'],
      });

      final result = await iosChecker.check();
      expect(result, isNull);
    });
  });
}
