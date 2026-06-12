/// Podcast URL 解析器
///
/// - Apple Podcasts 链接（itunes.apple.com / podcasts.apple.com）：
///   提取 podcast ID → iTunes lookup API → 获取 feedUrl
/// - 其他 http/https URL：直接当作 RSS Feed URL 返回
library;

import 'dart:convert';

import 'package:dio/dio.dart';

/// Podcast URL 解析失败
class PodcastResolveException implements Exception {
  final String message;
  const PodcastResolveException(this.message);
  @override
  String toString() => 'PodcastResolveException: $message';
}

class PodcastUrlResolver {
  final Dio _dio;

  PodcastUrlResolver({Dio? dio}) : _dio = dio ?? Dio();

  /// 解析用户输入的 URL，返回 RSS Feed URL。
  Future<String> resolve(String inputUrl) async {
    final uri = Uri.tryParse(inputUrl.trim());
    if (uri == null || !uri.hasScheme) {
      throw const PodcastResolveException('无效 URL');
    }

    final podcastId = _extractApplePodcastId(uri);
    if (podcastId != null) return _lookupFeedUrl(podcastId);

    if ((uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty) {
      return uri.toString();
    }
    throw const PodcastResolveException('不支持的 URL 格式');
  }

  /// 从 Apple Podcasts URL 提取 podcast ID（id123456789）。
  String? _extractApplePodcastId(Uri uri) {
    final host = uri.host;
    if (!host.contains('podcasts.apple.com') &&
        !host.contains('itunes.apple.com')) {
      return null;
    }
    for (final seg in uri.pathSegments.reversed) {
      if (seg.startsWith('id') && seg.length > 2) {
        final id = seg.substring(2);
        if (int.tryParse(id) != null) return id;
      }
    }
    return null;
  }

  /// 调用 iTunes lookup API 获取 feedUrl。
  Future<String> _lookupFeedUrl(String podcastId) async {
    try {
      final response = await _dio.get<Object?>(
        'https://itunes.apple.com/lookup',
        queryParameters: {'id': podcastId, 'entity': 'podcast'},
      );
      return parseLookupFeedUrl(response.data);
    } on PodcastResolveException {
      rethrow;
    } catch (e) {
      throw PodcastResolveException('Apple Podcasts 解析失败：$e');
    }
  }

  /// 解析 iTunes lookup 响应。
  ///
  /// Dio 在不同平台/响应头下可能返回 JSON map，也可能返回原始字符串。
  static String parseLookupFeedUrl(Object? data) {
    final decoded = switch (data) {
      final Map<String, dynamic> map => map,
      final Map map => Map<String, dynamic>.from(map),
      final String text => jsonDecode(text) as Map<String, dynamic>,
      _ => throw const PodcastResolveException('iTunes lookup 响应格式无效'),
    };

    final results = decoded['results'] as List?;
    if (results == null || results.isEmpty) {
      throw const PodcastResolveException('iTunes lookup 未找到结果');
    }
    final first = results.first;
    if (first is! Map) {
      throw const PodcastResolveException('iTunes lookup 响应格式无效');
    }
    final feedUrl = first['feedUrl'] as String?;
    if (feedUrl == null || feedUrl.isEmpty) {
      throw const PodcastResolveException('iTunes lookup 未返回 feedUrl');
    }
    return feedUrl;
  }
}
