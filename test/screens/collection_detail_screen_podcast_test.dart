import 'dart:convert';

import 'package:echo_loop/features/podcast/podcast_models.dart';
import 'package:echo_loop/models/audio_item.dart';
import 'package:echo_loop/models/collection.dart';
import 'package:echo_loop/providers/audio_library_provider.dart';
import 'package:echo_loop/providers/collection_provider.dart';
import 'package:echo_loop/screens/collection_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mock_providers.dart';
import '../helpers/test_app.dart';

void main() {
  testWidgets('podcast 合集详情头部紧凑展示 feed 元信息', (tester) async {
    const longDescription =
        'Short episodes for careful listening. Each episode is designed for '
        'slow practice with clear speech, focused vocabulary, and repeatable '
        'daily listening routines that help learners notice details. Learners '
        'can replay the same story several times, compare small pronunciation '
        'changes, and build confidence with a predictable listening rhythm. '
        'The archive also gives teachers enough material to choose topics for '
        'different levels without leaving the podcast collection.';
    final collection = Collection(
      id: 'podcast-1',
      name: 'Learning Podcast',
      createdDate: DateTime(2026, 6, 12),
      source: CollectionSource.podcast,
      podcastInputUrl: 'https://podcasts.apple.com/podcast/id123',
      podcastFeedUrl: 'https://example.com/feed.xml',
      podcastMetaJson: jsonEncode(
        const PodcastFeedMeta(
          title: 'Learning Podcast',
          author: 'Echo Studio',
          description: longDescription,
          feedUrl: 'https://example.com/feed.xml',
        ).toJson(),
      ),
      podcastLastRefreshedAt: DateTime(2026, 6, 12, 8, 30),
    );
    final item = AudioItem(
      id: 'episode-1',
      name: 'Episode One',
      audioPath: null,
      addedDate: DateTime(2026, 6, 12),
      podcastEpisodeGuid: 'guid-1',
      podcastEnclosureUrl: 'https://example.com/episode-1.mp3',
      podcastEnclosureType: 'audio/mpeg',
    );

    await tester.pumpWidget(
      createTestScreen(
        const CollectionDetailScreen(collectionId: 'podcast-1'),
        overrides: [
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: [item])),
          ),
          collectionListProvider.overrideWith(
            () => TestCollectionList(
              CollectionState(
                rawCollections: [collection],
                audioIdsMap: const {
                  'podcast-1': ['episode-1'],
                },
              ),
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // 标题由 AppBar 承载，header 不再重复展示；作者也不在 header
    expect(find.text('Learning Podcast'), findsWidgets);
    expect(find.text('Echo Studio'), findsNothing);
    // header 仅保留封面 + 简介预览 + 更多
    expect(find.text(longDescription), findsOneWidget);
    // 头部保持紧凑，不展示上次刷新时间
    expect(find.text('Last refreshed: 2026-06-12 08:30'), findsNothing);
    expect(find.byIcon(Icons.podcasts_rounded), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
    expect(find.byIcon(Icons.info_outline), findsNothing);
    expect(find.text('More'), findsOneWidget);

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();

    expect(find.text('Details'), findsOneWidget);
    // 作者移入详情弹窗
    expect(find.text('Echo Studio'), findsOneWidget);
    // 详情弹窗展示上次刷新时间
    expect(find.text('Last refreshed: 2026-06-12 08:30'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('RSS URL'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(find.text('RSS URL'), findsOneWidget);
    expect(find.text('https://example.com/feed.xml'), findsOneWidget);
  });
}
