import 'dart:io';

import 'package:dio/dio.dart';
import 'package:echo_loop/features/podcast/data/featured_podcast_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeDio extends Fake implements Dio {
  _FakeDio(this.bodies);

  final List<String> bodies;
  int callCount = 0;
  final List<String> paths = [];
  final List<Map<String, dynamic>?> queryParameters = [];

  @override
  Future<Response<T>> get<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    callCount++;
    paths.add(path);
    this.queryParameters.add(queryParameters);
    return Response<T>(
      data: bodies.removeAt(0) as T,
      statusCode: 200,
      requestOptions: RequestOptions(path: path),
    );
  }
}

const _firstBody = '''
{
  "items": [
    {
      "id": "podcast-1",
      "applePodcastUrl": "https://podcasts.apple.com/example",
      "rssUrl": "https://example.com/feed.xml",
      "imageUrl": null,
      "title": "Featured English",
      "description": "Short English lessons"
    }
  ],
  "nextCursor": "cursor-1"
}
''';

const _secondBody = '''
{
  "items": [
    {
      "id": "podcast-2",
      "applePodcastUrl": null,
      "rssUrl": "https://example.com/second.xml",
      "imageUrl": null,
      "title": "Second Featured Podcast",
      "description": null
    }
  ],
  "nextCursor": null
}
''';

const _legacyBody = '''
{
  "podcastCatalogs": [
    {
      "id": "podcast-legacy",
      "applePodcastUrl": null,
      "rssUrl": "https://example.com/legacy.xml",
      "imageUrl": null,
      "title": "Legacy Featured Podcast",
      "description": null
    }
  ]
}
''';

void main() {
  test('解析精选 Podcast 分页、写入缓存，并合并并发刷新请求', () async {
    final directory = await Directory.systemTemp.createTemp(
      'featured-podcasts-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final dio = _FakeDio([_firstBody]);
    final service = FeaturedPodcastService.withDio(
      dio: dio,
      resolveDir: () async => directory,
    );

    final outcomes = await Future.wait([
      service.refreshFirstPage(force: true),
      service.refreshFirstPage(force: true),
    ]);

    expect(outcomes, everyElement(isA<FeaturedPodcastUpdated>()));
    expect(service.cachedSnapshot?.podcasts.single.title, 'Featured English');
    expect(service.cachedSnapshot?.nextCursor, 'cursor-1');
    expect(
      service.cachedSnapshot?.podcasts.single.subscriptionInputUrl,
      'https://podcasts.apple.com/example',
    );
    expect(dio.callCount, 1);
    expect(dio.paths.single, '/api/v1/featured-podcasts');
    expect(dio.queryParameters.single, isNull);
    expect(await File('${directory.path}/catalog.json').exists(), isTrue);
    expect(dio.callCount, 1);
  });

  test('新 service 可以从本地缓存恢复精选 Podcast', () async {
    final directory = await Directory.systemTemp.createTemp(
      'featured-podcasts-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final writer = FeaturedPodcastService.withDio(
      dio: _FakeDio([_firstBody]),
      resolveDir: () async => directory,
    );
    await writer.refreshFirstPage(force: true);

    final readerDio = _FakeDio(['should not be requested']);
    final reader = FeaturedPodcastService.withDio(
      dio: readerDio,
      resolveDir: () async => directory,
    );

    final snapshot = await reader.loadCachedFirstPage();

    expect(snapshot?.podcasts.single.id, 'podcast-1');
    expect(readerDio.callCount, 0);
  });

  test('按 cursor 加载下一页并缓存各页数据', () async {
    final directory = await Directory.systemTemp.createTemp(
      'featured-podcasts-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final dio = _FakeDio([_firstBody, _secondBody]);
    final service = FeaturedPodcastService.withDio(
      dio: dio,
      resolveDir: () async => directory,
    );

    await service.refreshFirstPage(force: true);
    final cachedPage = await service.loadCachedPage(cursor: 'cursor-1');
    expect(cachedPage, isNull);
    final nextPage = await service.refreshPage(cursor: 'cursor-1', force: true);

    expect(nextPage, isA<FeaturedPodcastUpdated>());
    expect(service.cachedSnapshot?.podcasts.map((podcast) => podcast.id), [
      'podcast-1',
      'podcast-2',
    ]);
    expect(service.cachedSnapshot?.nextCursor, isNull);
    expect(dio.paths, [
      '/api/v1/featured-podcasts',
      '/api/v1/featured-podcasts',
    ]);
    expect(dio.queryParameters, [
      null,
      {'cursor': 'cursor-1'},
    ]);

    final reader = FeaturedPodcastService.withDio(
      dio: _FakeDio(['should not be requested']),
      resolveDir: () async => directory,
    );
    await reader.loadCachedFirstPage();
    final restoredPage = await reader.loadCachedPage(cursor: 'cursor-1');
    expect(restoredPage?.podcasts.single.id, 'podcast-2');
    expect(reader.cachedSnapshot?.podcasts.map((podcast) => podcast.id), [
      'podcast-1',
      'podcast-2',
    ]);
  });

  test('新 API 不接受旧 catalog 响应格式', () async {
    final directory = await Directory.systemTemp.createTemp(
      'featured-podcasts-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final dio = _FakeDio([_legacyBody]);
    final service = FeaturedPodcastService.withDio(
      dio: dio,
      resolveDir: () async => directory,
    );

    final outcome = await service.refreshFirstPage(force: true);

    expect(outcome, isA<FeaturedPodcastFailed>());
    expect(service.cachedSnapshot, isNull);
    expect(dio.paths, ['/api/v1/featured-podcasts']);
  });

  test('仍可从旧 catalog.json 缓存读取 podcastCatalogs', () async {
    final directory = await Directory.systemTemp.createTemp(
      'featured-podcasts-',
    );
    addTearDown(() => directory.delete(recursive: true));
    await File('${directory.path}/catalog.json').writeAsString(_legacyBody);
    await File('${directory.path}/catalog.meta.json').writeAsString(
      '{"contentHash":"legacy-hash","lastFetchedAt":"2026-10-01T00:00:00.000Z"}',
    );
    final service = FeaturedPodcastService.withDio(
      dio: _FakeDio(['should not be requested']),
      resolveDir: () async => directory,
    );

    final snapshot = await service.loadCachedFirstPage();

    expect(snapshot?.podcasts.single.id, 'podcast-legacy');
    expect(snapshot?.nextCursor, isNull);
  });
}
