import 'package:flutter_test/flutter_test.dart';

import 'package:echo_loop/features/community_collections/models/community_collection_models.dart';
import 'package:echo_loop/models/collection.dart';

void main() {
  test(
    'community collection catalog entry caches its optional author nickname',
    () {
      final catalogEntry = PublicCollectionCatalogEntry.fromJson({
        'id': 'collection-1',
        'name': 'Community English',
        'description': 'A description',
        'coverUrl': null,
        'authorNickname': 'Echo Studio',
        'fileCount': 3,
        'publishedAt': '2026-09-22T00:00:00.000Z',
      });

      expect(catalogEntry.authorNickname, 'Echo Studio');
      expect(catalogEntry.toJson()['authorNickname'], 'Echo Studio');

      final legacyCatalogEntry = PublicCollectionCatalogEntry.fromJson({
        'id': 'legacy-collection',
        'name': 'Legacy collection',
        'description': null,
        'coverUrl': null,
        'fileCount': 0,
        'publishedAt': '2026-09-22T00:00:00.000Z',
      });
      expect(legacyCatalogEntry.authorNickname, isNull);
      expect(legacyCatalogEntry.updatedAt, legacyCatalogEntry.publishedAt);
      expect(legacyCatalogEntry.coverUrlChina, isNull);
    },
  );

  test(
    'legacy collection source is read as community and stored canonically',
    () {
      expect(
        CollectionSource.fromString('official'),
        CollectionSource.community,
      );
      expect(CollectionSource.community.storageValue, 'community');
    },
  );

  test('subtitle DTO converts seconds to millisecond precision', () {
    final subtitle = CommunitySubtitle.fromJson({
      'fileId': 'file-1',
      'sentences': [
        {'text': 'A sentence', 'startTime': 1.125, 'endTime': 2.5},
      ],
      'words': [
        {'word': 'A', 'startTime': 1.125, 'endTime': 1.4},
      ],
    });

    expect(subtitle.sentences.single.startTime.inMilliseconds, 1125);
    expect(subtitle.sentences.single.endTime.inMilliseconds, 2500);
    expect(subtitle.words.single.endTime.inMilliseconds, 1400);
  });

  test('中国镜像 URL 可解析并保存在社区目录缓存格式中', () {
    final catalogEntry = PublicCollectionCatalogEntry.fromJson({
      'id': 'collection-1',
      'name': 'Community English',
      'description': null,
      'coverUrl': 'https://global.example/cover.jpg',
      'coverUrlChina': 'https://china.example/cover.jpg',
      'fileCount': 1,
      'publishedAt': '2026-09-22T00:00:00.000Z',
    });
    final file = CommunityCollectionFile.fromJson({
      'id': 'file-1',
      'title': 'Lesson 1',
      'description': null,
      'mediaType': 'audio',
      'durationSec': 42,
      'fileSizeBytes': null,
      'difficulty': null,
      'publishedAt': null,
      'sortOrder': 0,
      'mediaUrl': 'https://global.example/file.m4a',
      'mediaUrlChina': 'https://china.example/file.m4a',
    });

    expect(
      PublicCollectionCatalogEntry.fromJson(
        catalogEntry.toJson(),
      ).coverUrlChina,
      'https://china.example/cover.jpg',
    );
    expect(
      CommunityCollectionFile.fromJson(file.toJson()).mediaUrlChina,
      'https://china.example/file.m4a',
    );
  });
}
