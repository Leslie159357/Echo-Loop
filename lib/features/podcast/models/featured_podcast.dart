/// Featured podcast 中用于发现页展示的单条精选 Podcast。
class FeaturedPodcast {
  final String id;
  final String applePodcastUrl;
  final String rssUrl;
  final String? imageUrl;
  final String title;
  final String? description;

  const FeaturedPodcast({
    required this.id,
    required this.applePodcastUrl,
    required this.rssUrl,
    required this.imageUrl,
    required this.title,
    required this.description,
  });

  factory FeaturedPodcast.fromJson(Map<String, dynamic> json) {
    return FeaturedPodcast(
      id: json['id'] as String,
      applePodcastUrl: json['applePodcastUrl'] as String? ?? '',
      rssUrl: json['rssUrl'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
    );
  }

  /// 订阅时优先使用 Apple Podcasts URL，缺失时回退到 RSS URL。
  String get subscriptionInputUrl {
    final appleUrl = applePodcastUrl.trim();
    return appleUrl.isNotEmpty ? appleUrl : rssUrl.trim();
  }
}

/// 精选 Podcast 的一个游标分页。
class FeaturedPodcastPage {
  final String? cursor;
  final List<FeaturedPodcast> podcasts;
  final String? nextCursor;
  final String contentHash;
  final DateTime fetchedAt;

  const FeaturedPodcastPage({
    required this.cursor,
    required this.podcasts,
    required this.nextCursor,
    required this.contentHash,
    required this.fetchedAt,
  });

  FeaturedPodcastPage withFetchedAt(DateTime value) => FeaturedPodcastPage(
    cursor: cursor,
    podcasts: podcasts,
    nextCursor: nextCursor,
    contentHash: contentHash,
    fetchedAt: value,
  );
}

/// Featured podcast 已加载分页的本地内存快照。
class FeaturedPodcastSnapshot {
  final List<FeaturedPodcast> podcasts;
  final String contentHash;
  final DateTime fetchedAt;
  final String? nextCursor;

  const FeaturedPodcastSnapshot({
    required this.podcasts,
    required this.contentHash,
    required this.fetchedAt,
    this.nextCursor,
  });
}
