/// 配置驱动的网页型词典源
///
/// 网页词典（Cambridge / Oxford / Longman / Britannica / Merriam-Webster / Collins /
/// Vocabulary.com / Wiktionary / OZDIC / PlayPhrase / YouGlish / Forvo /
/// WordReference / Etymonline / 有道 / 欧路词典）本质相同——不抓取/解析 HTML，
/// 只按词构造 URL，交给内置 WebView 显示。差异仅在 URL 模板与品牌展示，故抽象为一份 [WebDictConfig]
/// 配置 + 一个通用 [WebDictionarySource]：新增一个网页词典只需往 [kWebDictConfigs]
/// 加一行配置。
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../models/dictionary/dictionary_lookup_result.dart';
import 'dictionary_source.dart';

/// 单个网页词典的配置（id / 展示 / URL 构造 / 可选页面注入）
@immutable
class WebDictConfig {
  /// 稳定唯一 id（持久化键/缓存前缀/切换标识，一经发布不可改）
  final String id;

  /// 切换器与设置页显示名（品牌名，不本地化）
  final String displayName;

  /// 列表图标
  final IconData icon;

  /// 品牌强调色（图标着色，便于区分各源）
  final Color color;

  /// 由「已 URL 编码的查询词」构造完整词条网页地址
  final String Function(String encodedWord) buildUrl;

  /// 可选：收敛页面 chrome（隐藏页眉/广告/cookie 横幅）的 CSS；
  /// 为 null 时视图使用通用默认注入。
  final String? tidyCss;

  /// 可选：自动接受 cookie 同意的 JS；为 null 时视图使用通用默认注入。
  final String? acceptCookieJs;

  const WebDictConfig({
    required this.id,
    required this.displayName,
    required this.icon,
    required this.color,
    required this.buildUrl,
    this.tidyCss,
    this.acceptCookieJs,
  });
}

/// 通用网页词典源：包装一份 [WebDictConfig]，[lookup] 只构造 URL。
class WebDictionarySource implements DictionarySource {
  /// 该源配置
  final WebDictConfig config;

  const WebDictionarySource(this.config);

  @override
  String get id => config.id;

  @override
  IconData get icon => config.icon;

  @override
  bool get canBeDisabled => true;

  @override
  bool get requiresNetwork => true;

  @override
  Future<DictionaryLookupResult?> lookup(
    DictionaryLookupRequest request, {
    CancelToken? cancelToken,
  }) async {
    // request.word 已由 controller 完成基础清洗（见 DictionaryLookupRequest.word 契约）
    final slug = Uri.encodeComponent(request.word);
    return WebDictResult(
      sourceId: config.id,
      url: Uri.parse(config.buildUrl(slug)),
      word: request.word,
    );
  }
}

// URL 模板（顶层函数，便于 const 配置引用）。`w` 为已 URL 编码的查询词。
String _dehelperUrl(String w) => 'https://dict.eudic.net/dicts/de/$w';
String _dudenUrl(String w) => 'https://www.duden.de/suchen/dudenonline/$w';
String _dwdsUrl(String w) => 'https://www.dwds.de/wb/$w';

/// 全部网页词典配置（顺序即切换器排列顺序）。
const List<WebDictConfig> kWebDictConfigs = [
  // 德语版：只保留能查德语词的源，按学习价值排序。
  // 英文专用站（Cambridge / Oxford / Longman / M-W / Collins / Britannica /
  // Vocabulary / OZDIC / PlayPhrase / Etymonline、Forvo #en、WordReference en）
  // 在德语版是纯噪音，已移除；对应 URL 函数一并删掉。
  WebDictConfig(
    id: 'dehelper',
    displayName: '德语助手',
    icon: Icons.menu_book_rounded,
    color: Color(0xFF2D6FA3),
    buildUrl: _dehelperUrl,
  ),
  WebDictConfig(
    id: 'duden',
    displayName: 'Duden',
    icon: Icons.menu_book_rounded,
    color: Color(0xFFD32F2F),
    buildUrl: _dudenUrl,
  ),
  WebDictConfig(
    id: 'dwds',
    displayName: 'DWDS',
    icon: Icons.library_books_rounded,
    color: Color(0xFF00897B),
    buildUrl: _dwdsUrl,
  ),
  WebDictConfig(
    id: 'eudic',
    displayName: '欧路德语',
    icon: Icons.menu_book_rounded,
    color: Color(0xFF1E6FB8),
    buildUrl: _eudicUrl,
  ),
  WebDictConfig(
    id: 'wiktionary',
    displayName: '德语维基词典',
    icon: Icons.public_rounded,
    color: Color(0xFF607D8B),
    buildUrl: _wiktionaryUrl,
  ),
  WebDictConfig(
    id: 'zhwiktionary',
    displayName: '中文维基词典',
    icon: Icons.public_rounded,
    color: Color(0xFF9E9E9E),
    buildUrl: _zhWiktionaryUrl,
  ),
];

// 德语版网页源 URL（dehelper/duden/dwds 已在文件上方定义）。
String _eudicUrl(String w) => 'https://dict.eudic.net/mdicts/de/$w';
String _wiktionaryUrl(String w) => 'https://de.m.wiktionary.org/wiki/$w';
String _zhWiktionaryUrl(String w) => 'https://zh.m.wiktionary.org/wiki/$w';
