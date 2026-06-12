/// Podcast RSS Feed 解析器
///
/// 解析 RSS/Atom XML，提取 feed 元信息与 episode 列表。
/// 只导入有 guid + enclosure 的 episode，无 guid 的跳过。
library;

import 'package:xml/xml.dart';

import 'podcast_models.dart';

class PodcastFeedParser {
  /// 解析 RSS XML 字符串，返回 [PodcastFeedResult]。
  PodcastFeedResult parse(String xmlContent, {required String feedUrl}) {
    final document = XmlDocument.parse(xmlContent);
    final channel = document.findAllElements('channel').firstOrNull;
    if (channel == null) {
      throw const PodcastParseException('无效的 RSS：缺少 channel 元素');
    }

    final meta = _parseMeta(channel, feedUrl: feedUrl);
    final episodes = _parseEpisodes(channel);
    return PodcastFeedResult(meta: meta, episodes: episodes);
  }

  PodcastFeedMeta _parseMeta(XmlElement channel, {required String feedUrl}) {
    final title = _text(channel, 'title') ?? '';
    final author =
        _text(channel, 'itunes:author') ?? _text(channel, 'managingEditor');
    final description = _text(channel, 'description');
    // RSS 2.0 image url 在 <image><url>；iTunes 在 <itunes:image href="...">
    final imageUrl =
        channel
            .findElements('image')
            .firstOrNull
            ?.findElements('url')
            .firstOrNull
            ?.innerText
            .trim() ??
        channel
            .findAllElements('itunes:image')
            .firstOrNull
            ?.getAttribute('href');
    return PodcastFeedMeta(
      title: title,
      feedUrl: feedUrl,
      author: author?.trim().isEmpty == true ? null : author?.trim(),
      description: description?.trim().isEmpty == true
          ? null
          : description?.trim(),
      imageUrl: imageUrl?.trim().isEmpty == true ? null : imageUrl?.trim(),
    );
  }

  List<PodcastEpisode> _parseEpisodes(XmlElement channel) {
    final episodes = <PodcastEpisode>[];
    for (final item in channel.findElements('item')) {
      final guid = _text(item, 'guid')?.trim();
      if (guid == null || guid.isEmpty) continue; // 无 guid 跳过

      final enclosure = item.findElements('enclosure').firstOrNull;
      final enclosureUrl = enclosure?.getAttribute('url') ?? '';
      final enclosureType = enclosure?.getAttribute('type') ?? 'audio/mpeg';
      if (enclosureUrl.isEmpty) continue; // 无音频 URL 跳过

      final title = _text(item, 'title') ?? guid;
      final pubDate = _parseDate(_text(item, 'pubDate'));
      final duration = _parseDuration(_text(item, 'itunes:duration'));

      episodes.add(
        PodcastEpisode(
          guid: guid,
          title: title.trim(),
          enclosureUrl: enclosureUrl,
          enclosureType: enclosureType,
          pubDate: pubDate,
          durationSeconds: duration,
          description: _cleanText(
            _text(item, 'description') ?? _text(item, 'itunes:summary'),
          ),
          imageUrl: item
              .findAllElements('itunes:image')
              .firstOrNull
              ?.getAttribute('href')
              ?.trim(),
          link: _cleanText(_text(item, 'link')),
        ),
      );
    }
    return episodes;
  }

  String? _text(XmlElement parent, String tag) {
    return parent.findElements(tag).firstOrNull?.innerText;
  }

  String? _cleanText(String? raw) {
    final text = raw?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  DateTime? _parseDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return DateTime.parse(raw);
    } catch (_) {
      // RFC 2822 格式（常见于 RSS）：尝试简单解析月份缩写
      return _parseRfc2822(raw);
    }
  }

  static final _months = {
    'Jan': 1,
    'Feb': 2,
    'Mar': 3,
    'Apr': 4,
    'May': 5,
    'Jun': 6,
    'Jul': 7,
    'Aug': 8,
    'Sep': 9,
    'Oct': 10,
    'Nov': 11,
    'Dec': 12,
  };

  DateTime? _parseRfc2822(String raw) {
    // e.g. "Mon, 02 Jan 2006 15:04:05 +0000"
    final parts = raw.trim().split(RegExp(r'[\s,]+'));
    try {
      final day = int.parse(parts[1]);
      final month = _months[parts[2]] ?? 1;
      final year = int.parse(parts[3]);
      return DateTime.utc(year, month, day);
    } catch (_) {
      return null;
    }
  }

  /// 解析 itunes:duration：支持 "HH:MM:SS"、"MM:SS"、纯秒数
  int? _parseDuration(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split(':');
    try {
      if (parts.length == 3) {
        return int.parse(parts[0]) * 3600 +
            int.parse(parts[1]) * 60 +
            int.parse(parts[2]);
      } else if (parts.length == 2) {
        return int.parse(parts[0]) * 60 + int.parse(parts[1]);
      } else {
        return int.parse(raw);
      }
    } catch (_) {
      return null;
    }
  }
}

class PodcastParseException implements Exception {
  final String message;
  const PodcastParseException(this.message);
  @override
  String toString() => 'PodcastParseException: $message';
}
