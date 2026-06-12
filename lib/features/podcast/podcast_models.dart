/// Podcast feature 数据模型
library;

/// Feed 元信息（从 RSS channel 或 iTunes lookup 提取）
class PodcastFeedMeta {
  final String title;
  final String? author;
  final String? description;
  final String? imageUrl;
  final String feedUrl;

  const PodcastFeedMeta({
    required this.title,
    required this.feedUrl,
    this.author,
    this.description,
    this.imageUrl,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'author': author,
    'description': description,
    'imageUrl': imageUrl,
    'feedUrl': feedUrl,
  };

  factory PodcastFeedMeta.fromJson(Map<String, dynamic> json) =>
      PodcastFeedMeta(
        title: json['title'] as String,
        feedUrl: json['feedUrl'] as String,
        author: json['author'] as String?,
        description: json['description'] as String?,
        imageUrl: json['imageUrl'] as String?,
      );
}

/// RSS feed 解析结果
class PodcastFeedResult {
  final PodcastFeedMeta meta;
  final List<PodcastEpisode> episodes;

  const PodcastFeedResult({required this.meta, required this.episodes});
}

/// 单个 podcast episode
class PodcastEpisode {
  final String guid;
  final String title;
  final String enclosureUrl;
  final String enclosureType;
  final DateTime? pubDate;
  final int? durationSeconds;
  final String? description;
  final String? imageUrl;
  final String? link;

  const PodcastEpisode({
    required this.guid,
    required this.title,
    required this.enclosureUrl,
    required this.enclosureType,
    this.pubDate,
    this.durationSeconds,
    this.description,
    this.imageUrl,
    this.link,
  });
}
