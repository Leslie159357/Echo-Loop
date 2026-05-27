/// App 版本更新检查服务
///
/// iOS 通过 App Store Lookup API（`itunes.apple.com/lookup`）查询当前
/// App Store 实际可下载的版本，确保审核期间不会误提示 iOS 用户更新。
/// 其他平台从远程静态 JSON（`version.json`）获取版本信息。
/// 使用独立 Dio 实例（不复用 AI API 的 Dio），失败时返回 null 并写日志。
library;

import 'dart:convert';
import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../config/api_config.dart';
import '../models/app_update_info.dart';
import 'app_logger.dart';

/// App Store Lookup API endpoint。
const _iosLookupBase = 'https://itunes.apple.com/lookup';

/// 日志 tag
const _logTag = 'AppUpdateChecker';

/// App 版本更新检查器
///
/// 版本检查 URL 基于 [apiBaseUrl]（通过 `--dart-define=API_BASE_URL` 配置），
/// 本地开发时访问 `http://localhost:3000/version.json`，
/// 生产环境访问 `https://www.echo-loop.top/version.json`。
///
/// iOS 单独走 App Store Lookup API，[bundleId] 必填。
class AppUpdateChecker {
  final Dio _dio;
  final String _url;
  final String? _bundleId;
  final bool _useIosLookup;

  /// 使用默认配置创建检查器
  ///
  /// [bundleId] 用于 iOS App Store Lookup（其他平台忽略此参数）。
  AppUpdateChecker({String? bundleId})
    : _dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
        ),
      ),
      _url = '$apiBaseUrl/version.json',
      _bundleId = bundleId,
      _useIosLookup = !kIsWeb && Platform.isIOS;

  /// 用于测试的构造函数，允许注入 Dio 实例和配置
  ///
  /// [useIosLookup] 强制走 iOS Lookup 路径（host 测试机 Platform.isIOS=false，
  /// 测试时需显式开启）。
  AppUpdateChecker.withDio(
    this._dio, {
    String url = '',
    String? bundleId,
    bool useIosLookup = false,
  }) : _url = url,
       _bundleId = bundleId,
       _useIosLookup = useIosLookup;

  /// 检查远程版本信息
  ///
  /// iOS：查 App Store Lookup API（返回 App Store 实际可下载版本）。
  /// 其他平台：拉取远程 version.json。
  /// 失败时返回 null（网络错误、JSON 解析失败等均静默处理）。
  /// [country] 指定 App Store 区域（如 `cn` / `us`），决定 Lookup API 返回
  /// 哪个区域的 releaseNotes 本地化文案。仅 iOS 路径使用，为 null 时不传。
  Future<AppUpdateInfo?> check({String? country}) async {
    if (_useIosLookup) {
      return _checkIosLookup(country: country);
    }
    return _checkVersionJson();
  }

  /// iOS：从 App Store Lookup API 解析版本信息
  ///
  /// Lookup API 返回的 `version` 字段总是 App Store 当前可下载的版本，
  /// 不会包含审核中的 build，因此天然解决"提示有但下载不到"的问题。
  /// Lookup API 不提供 minimumVersion，回退为 `0.0.0`（不触发强制更新）。
  Future<AppUpdateInfo?> _checkIosLookup({String? country}) async {
    final bundleId = _bundleId;
    if (bundleId == null || bundleId.isEmpty) {
      AppLogger.log(_logTag, 'iOS lookup skipped: empty bundleId');
      return null;
    }
    AppLogger.log(
      _logTag,
      'iOS lookup start: bundleId=$bundleId country=${country ?? "(default)"}',
    );
    try {
      // iTunes Lookup 返回 Content-Type: text/javascript，Dio 默认 JSON
      // transformer 不识别该 MIME，会把 body 当作 String 透传。这里强制
      // ResponseType.plain 后用 jsonDecode 自行解析，避免 String 被错误地
      // 当成 Map 触发类型转换异常 → 静默 catch → "检查失败"。
      final response = await _dio.get<String>(
        _iosLookupBase,
        queryParameters: {
          'bundleId': bundleId,
          if (country != null && country.isNotEmpty) 'country': country,
        },
        options: Options(responseType: ResponseType.plain),
      );
      final body = response.data;
      if (body == null || body.isEmpty) {
        AppLogger.log(_logTag, 'iOS lookup empty body');
        return null;
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        AppLogger.log(
          _logTag,
          'iOS lookup unexpected top-level: ${decoded.runtimeType}',
        );
        return null;
      }
      final results = decoded['results'];
      if (results is! List || results.isEmpty) {
        AppLogger.log(_logTag, 'iOS lookup empty results');
        return null;
      }
      final entry = results.first;
      if (entry is! Map) {
        AppLogger.log(
          _logTag,
          'iOS lookup unexpected entry: ${entry.runtimeType}',
        );
        return null;
      }
      final version = entry['version'];
      if (version is! String || version.isEmpty) {
        AppLogger.log(_logTag, 'iOS lookup missing/invalid version');
        return null;
      }
      final trackUrl = entry['trackViewUrl'];
      final releaseNotes = entry['releaseNotes'];
      final downloadUrl = trackUrl is String && trackUrl.isNotEmpty
          ? trackUrl
          : 'https://apps.apple.com/app/id6760324074';
      final notes = releaseNotes is String && releaseNotes.isNotEmpty
          ? {'en': releaseNotes, 'zh': releaseNotes}
          : <String, String>{};
      AppLogger.log(_logTag, 'iOS lookup done: version=$version');
      return AppUpdateInfo(
        latestVersion: version,
        minimumVersion: '0.0.0',
        releaseNotes: notes,
        downloadUrl: {'ios': downloadUrl, 'fallback': downloadUrl},
      );
    } catch (e) {
      AppLogger.log(_logTag, 'iOS lookup failed: $e');
      return null;
    }
  }

  /// 非 iOS 平台：拉取远程 version.json
  Future<AppUpdateInfo?> _checkVersionJson() async {
    AppLogger.log(_logTag, 'version.json start: url=$_url');
    try {
      final response = await _dio.get<Map<String, dynamic>>(_url);
      final data = response.data;
      if (data == null) {
        AppLogger.log(_logTag, 'version.json empty body');
        return null;
      }
      final info = AppUpdateInfo.fromJson(data);
      AppLogger.log(
        _logTag,
        'version.json done: latest=${info.latestVersion} min=${info.minimumVersion}',
      );
      return info;
    } catch (e) {
      AppLogger.log(_logTag, 'version.json failed: $e');
      return null;
    }
  }

  /// 释放资源
  void dispose() => _dio.close();
}
