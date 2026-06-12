/// Podcast Repository
///
/// 负责：创建 podcast 合集、刷新 Feed（10 分钟节流 + inflight 合并）、
/// guid 去重入库。不触发字幕 API，由用户手动触发。
library;

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../models/audio_item.dart';
import '../../models/collection.dart';
import '../../providers/audio_library_provider.dart';
import '../../providers/collection_provider.dart';
import 'podcast_feed_parser.dart';
import 'podcast_models.dart';
import 'podcast_url_resolver.dart';

part 'podcast_repository.g.dart';

/// 10 分钟节流阈值
const _refreshThrottleMinutes = 10;

@riverpod
PodcastRepository podcastRepository(Ref ref) {
  return PodcastRepository(ref);
}

class PodcastRepository {
  final Ref _ref;
  final Dio _dio;
  final PodcastUrlResolver _urlResolver;
  final PodcastFeedParser _feedParser;

  /// 进行中的刷新任务（collectionId → Future）；用于 inflight 合并
  final Map<String, Future<void>> _inflightRefresh = {};

  PodcastRepository(this._ref)
    : _dio = Dio(),
      _urlResolver = PodcastUrlResolver(),
      _feedParser = PodcastFeedParser();

  // ── 创建 Podcast 合集 ─────────────────────────────────────────────────

  /// 通过用户输入的 URL 创建 podcast 合集并完成首次 Feed 拉取。
  ///
  /// 成功后合集和音频条目（占位，未下载）已入库。
  Future<Collection> createAndFetch(String inputUrl) async {
    final feedUrl = await _urlResolver.resolve(inputUrl);
    final feedContent = await _fetchFeedContent(feedUrl);
    final result = _feedParser.parse(feedContent, feedUrl: feedUrl);

    final now = DateTime.now();
    final collection = Collection(
      id: const Uuid().v4(),
      name: result.meta.title,
      createdDate: now,
      source: CollectionSource.podcast,
      coverUrl: result.meta.imageUrl,
      description: result.meta.description,
      podcastInputUrl: inputUrl,
      podcastFeedUrl: feedUrl,
      podcastMetaJson: jsonEncode(result.meta.toJson()),
      podcastLastRefreshedAt: now,
    );

    // 先把合集写入状态（_upsertCollection 内部处理）
    await _ref
        .read(collectionListProvider.notifier)
        .createPodcastCollection(collection);

    // 把 episodes 入库（去重）
    await _importEpisodes(result.episodes, collectionId: collection.id);
    return collection;
  }

  // ── 刷新 ─────────────────────────────────────────────────────────────

  /// 刷新 podcast 合集的 Feed，写入新 episode。
  ///
  /// [force] = true 跳过 10 分钟节流。
  /// 同一合集若已有进行中的刷新，直接返回同一个 Future（inflight 合并）。
  Future<void> refresh(String collectionId, {bool force = false}) {
    final existing = _inflightRefresh[collectionId];
    if (existing != null) return existing;

    final future = _doRefresh(collectionId, force: force).whenComplete(() {
      _inflightRefresh.remove(collectionId);
    });
    _inflightRefresh[collectionId] = future;
    return future;
  }

  Future<void> _doRefresh(String collectionId, {required bool force}) async {
    final collections = _ref.read(collectionListProvider).rawCollections;
    final collection = collections
        .where((c) => c.id == collectionId)
        .firstOrNull;
    if (collection == null || !collection.isPodcast) return;

    if (!force) {
      final last = collection.podcastLastRefreshedAt;
      if (last != null &&
          DateTime.now().difference(last).inMinutes < _refreshThrottleMinutes) {
        return; // 节流：距上次刷新不足 10 分钟
      }
    }

    final feedUrl = collection.podcastFeedUrl;
    if (feedUrl == null) return;

    final feedContent = await _fetchFeedContent(feedUrl);
    final result = _feedParser.parse(feedContent, feedUrl: feedUrl);

    // 更新 feed 元信息 + 刷新时间
    final updated = collection.copyWith(
      podcastLastRefreshedAt: DateTime.now(),
      podcastMetaJson: jsonEncode(result.meta.toJson()),
      coverUrl: result.meta.imageUrl ?? collection.coverUrl,
    );
    await _ref
        .read(collectionListProvider.notifier)
        .updatePodcastCollection(updated);

    await _importEpisodes(result.episodes, collectionId: collectionId);
  }

  // ── 内部辅助 ─────────────────────────────────────────────────────────

  Future<String> _fetchFeedContent(String feedUrl) async {
    final response = await _dio.get<String>(
      feedUrl,
      options: Options(responseType: ResponseType.plain),
    );
    final content = response.data;
    if (content == null || content.isEmpty) {
      throw const PodcastParseException('Feed 内容为空');
    }
    return content;
  }

  /// 将 episodes 入库；只在同一合集内按 guid 去重。
  Future<void> _importEpisodes(
    List<PodcastEpisode> episodes, {
    required String collectionId,
  }) async {
    final audioLib = _ref.read(audioLibraryProvider.notifier);
    final collList = _ref.read(collectionListProvider.notifier);

    // 获取该合集已有的 guid 集合（避免重复）
    final existingItems = _ref.read(audioLibraryProvider).audioItems;
    final collectionAudioIds = _ref
        .read(collectionListProvider)
        .getAudioIds(collectionId)
        .toSet();
    final existingGuids = existingItems
        .where((item) => collectionAudioIds.contains(item.id))
        .map((item) => item.podcastEpisodeGuid)
        .whereType<String>()
        .toSet();

    for (final episode in episodes) {
      if (existingGuids.contains(episode.guid)) continue;

      final now = DateTime.now();
      final item = AudioItem(
        id: const Uuid().v4(),
        name: episode.title,
        addedDate: episode.pubDate ?? now,
        originalDate: episode.pubDate,
        totalDuration: episode.durationSeconds ?? 0,
        // audioPath = null：懒下载，用户点击后才下载
        podcastEpisodeGuid: episode.guid,
        podcastEnclosureUrl: episode.enclosureUrl,
        podcastEnclosureType: episode.enclosureType,
        podcastDescription: episode.description,
        podcastImageUrl: episode.imageUrl,
        podcastLink: episode.link,
      );

      await audioLib.addAudioItem(item);
      await collList.addAudioToCollection(collectionId, item.id);
    }
  }
}
