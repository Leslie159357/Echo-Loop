import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:echo_loop/analytics/geo_interceptor.dart';

void main() {
  group('GeoInterceptor', () {
    late SharedPreferences prefs;
    late GeoInterceptor interceptor;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      interceptor = GeoInterceptor(prefs);
    });

    /// 构造一个带 set-cookie header 的 Response
    Response<dynamic> _makeResponse(List<String>? cookies) {
      final headers = Headers();
      if (cookies != null) {
        for (final cookie in cookies) {
          headers.add('set-cookie', cookie);
        }
      }
      return Response(
        requestOptions: RequestOptions(path: '/test'),
        statusCode: 200,
        headers: headers,
      );
    }

    test('从 set-cookie 中提取 x-geo-country 并缓存', () {
      final response = _makeResponse([
        'NEXT_LOCALE=en; Path=/; SameSite=lax',
        'x-geo-country=CN; Path=/; SameSite=lax',
      ]);

      // 手动调用 onResponse（模拟 Dio 拦截器链）
      interceptor.onResponse(
        response,
        ResponseInterceptorHandler(),
      );

      expect(prefs.getString(geoCountryKey), 'CN');
    });

    test('非 CN 的 country 也能正确缓存', () {
      final response = _makeResponse([
        'x-geo-country=US; Path=/; SameSite=lax',
      ]);

      interceptor.onResponse(response, ResponseInterceptorHandler());

      expect(prefs.getString(geoCountryKey), 'US');
    });

    test('无 x-geo-country cookie 时不修改缓存', () {
      final response = _makeResponse([
        'NEXT_LOCALE=en; Path=/; SameSite=lax',
      ]);

      interceptor.onResponse(response, ResponseInterceptorHandler());

      expect(prefs.getString(geoCountryKey), isNull);
    });

    test('无 set-cookie header 时不修改缓存', () {
      final response = _makeResponse(null);

      interceptor.onResponse(response, ResponseInterceptorHandler());

      expect(prefs.getString(geoCountryKey), isNull);
    });

    test('空 country 值不缓存', () {
      final response = _makeResponse([
        'x-geo-country=; Path=/; SameSite=lax',
      ]);

      interceptor.onResponse(response, ResponseInterceptorHandler());

      expect(prefs.getString(geoCountryKey), isNull);
    });

    test('后续响应更新缓存', () {
      // 第一次：CN
      interceptor.onResponse(
        _makeResponse(['x-geo-country=CN; Path=/']),
        ResponseInterceptorHandler(),
      );
      expect(prefs.getString(geoCountryKey), 'CN');

      // 第二次：US（用户出国了）
      interceptor.onResponse(
        _makeResponse(['x-geo-country=US; Path=/']),
        ResponseInterceptorHandler(),
      );
      expect(prefs.getString(geoCountryKey), 'US');
    });
  });
}
