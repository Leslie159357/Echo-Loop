/// 微软 Edge 在线 TTS 精选德语 Neural 音色目录。
///
/// 仅收录**实测可出声**的音色（2026-11 逐个验证）：Elke / Bernd / Christoph
/// 已从微软服务端下线，请求返回 "No audio was received"；AT/CH 音色虽可用，
/// 但奥地利/瑞士腔对标准德语学习是干扰，故不收录。
///
/// 德语版：原上游是美音 / 英音各 4 个，本版整体替换为 de-DE 音色。
/// [TtsAccent.us] 复用为「德语女声组」，[TtsAccent.uk] 复用为「德语男声组」，
/// 仅为复用既有分组 UI 与 SP 结构，语义见 UI 文案（德语女声 / 德语男声）。
/// [EdgeVoice.id] 即 Edge 的 ShortName，既用于合成请求，也作为缓存键的 voiceId。
library;

import 'tts_engine.dart';

/// 单个 Edge 音色。
class EdgeVoice {
  /// Edge 音色 ShortName（如 `de-DE-KatjaNeural`），同时作为缓存 voiceId。
  final String id;

  /// 展示名（如 `Katja`）。
  final String displayName;

  /// 分组（us = 女声组，uk = 男声组）。
  final TtsAccent accent;

  /// 是否女声。
  final bool isFemale;

  const EdgeVoice({
    required this.id,
    required this.displayName,
    required this.accent,
    required this.isFemale,
  });

  /// 合成请求使用的语言标签（德语版固定 `de-DE`）。
  String get languageTag => 'de-DE';
}

/// 默认德语女声（与复盘里的教材腔一致）。
const edgeDefaultVoiceUs = 'de-DE-KatjaNeural';

/// 默认德语男声。
const edgeDefaultVoiceUk = 'de-DE-ConradNeural';

/// 全部精选 Edge 音色（女声组在前，组内按推荐度排序）。
const List<EdgeVoice> edgeVoices = [
  // 女声组
  EdgeVoice(
    id: 'de-DE-KatjaNeural',
    displayName: 'Katja',
    accent: TtsAccent.us,
    isFemale: true,
  ),
  EdgeVoice(
    id: 'de-DE-AmalaNeural',
    displayName: 'Amala',
    accent: TtsAccent.us,
    isFemale: true,
  ),
  EdgeVoice(
    id: 'de-DE-SeraphinaMultilingualNeural',
    displayName: 'Seraphina',
    accent: TtsAccent.us,
    isFemale: true,
  ),
  // 男声组
  EdgeVoice(
    id: 'de-DE-ConradNeural',
    displayName: 'Conrad',
    accent: TtsAccent.uk,
    isFemale: false,
  ),
  EdgeVoice(
    id: 'de-DE-KillianNeural',
    displayName: 'Killian',
    accent: TtsAccent.uk,
    isFemale: false,
  ),
];

/// 返回指定分组下的全部 Edge 音色（us = 德语女声组，uk = 德语男声组）。
List<EdgeVoice> edgeVoicesForAccent(TtsAccent accent) =>
    edgeVoices.where((v) => v.accent == accent).toList(growable: false);

/// 按 id 查找 Edge 音色；未知 id 返回 null。
EdgeVoice? edgeVoiceById(String id) {
  for (final v in edgeVoices) {
    if (v.id == id) return v;
  }
  return null;
}

/// 指定分组的默认 Edge 音色。
EdgeVoice edgeDefaultVoice(TtsAccent accent) => edgeVoiceById(
  accent == TtsAccent.uk ? edgeDefaultVoiceUk : edgeDefaultVoiceUs,
)!;
