/// Dio 拦截器：从 API 响应中自动更新 geo 缓存
///
/// 后端（Vercel）所有响应的 `set-cookie` 都带 `x-geo-country=CN`
/// （基于客户端 IP）。此拦截器从任意响应中提取 country 并缓存到
/// [SharedPreferences]，下次冷启动时用于选择分析通道。
///
/// 添加到现有 API 客户端的 Dio 实例中即可，零额外网络请求。
library;

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// geo 缓存的 SharedPreferences key
const geoCountryKey = 'geo_country';

/// 从 API 响应 set-cookie 中自动提取 x-geo-country 并缓存
class GeoInterceptor extends Interceptor {
  final SharedPreferences _prefs;

  GeoInterceptor(this._prefs);

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final cookies = response.headers['set-cookie'];
    if (cookies != null) {
      for (final cookie in cookies) {
        if (cookie.startsWith('x-geo-country=')) {
          final country = cookie.split('=')[1].split(';')[0].trim();
          if (country.isNotEmpty) {
            _prefs.setString(geoCountryKey, country);
          }
          break;
        }
      }
    }
    handler.next(response);
  }
}
