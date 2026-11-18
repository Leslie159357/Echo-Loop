/// 德语播客预设：App 不内置播客源，这里给几条实测可用的德语 RSS，
/// 在「从链接导入」里一键填进输入框（不自动提交，用户可改）。
///
/// 全部于 2026-11-18 实测：HTTP 200 且 feed 内带 `<enclosure>` 音频条目。
library;

class GermanPodcastPreset {
  /// 展示名（保持德语原名，方便对照播客客户端）
  final String name;

  /// RSS 地址
  final String url;

  const GermanPodcastPreset({required this.name, required this.url});
}

const List<GermanPodcastPreset> kGermanPodcastPresets = [
  GermanPodcastPreset(
    name: 'Slow German',
    url: 'https://slowgerman.com/feed/podcast/',
  ),
  GermanPodcastPreset(
    name: 'DW 慢速新闻',
    url: 'https://rss.dw.com/xml/DKpodcast_lgn_de',
  ),
  GermanPodcastPreset(
    name: 'DW Top-Thema',
    url: 'https://rss.dw.com/xml/DKpodcast_topthemamitvokabeln_de',
  ),
  GermanPodcastPreset(
    name: 'Betthupferl',
    url: 'https://feeds.br.de/betthupferl/feed.xml',
  ),
];
