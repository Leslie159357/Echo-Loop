/// AI 句子翻译/解析 Provider
///
/// 三级缓存查找：L1 内存 → L2 SQLite → L3 API。
/// 支持并发请求去重，避免同一句子重复发起 API 调用。
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/daos/sentence_ai_cache_dao.dart';
import '../database/providers.dart';
import '../models/sense_group_result.dart';
import '../models/sentence_ai_result.dart';
import '../services/sentence_ai_api_client.dart';
import '../utils/text_normalize.dart';

/// AI 句子翻译/解析服务
///
/// 通过三级缓存（内存 → SQLite → API）获取句子的翻译和解析结果。
/// 使用 pending 请求 Map 实现并发去重。
class SentenceAiNotifier {
  final SentenceAiCacheDao _cacheDao;
  final SentenceAiApiClient _apiClient;

  /// L1 内存缓存
  final Map<String, SentenceTranslation> _translationCache = {};
  final Map<String, SentenceAnalysis> _analysisCache = {};
  final Map<String, SenseGroupResult> _senseGroupCache = {};

  /// 正在进行的请求（用于去重）
  final Map<String, Future<SentenceTranslation>> _pendingTranslations = {};
  final Map<String, Future<SentenceAnalysis>> _pendingAnalyses = {};
  final Map<String, Future<SenseGroupResult>> _pendingSenseGroups = {};

  SentenceAiNotifier({
    required SentenceAiCacheDao cacheDao,
    required SentenceAiApiClient apiClient,
  }) : _cacheDao = cacheDao,
       _apiClient = apiClient;

  /// 获取翻译（三级缓存查找）
  ///
  /// L1 内存 → L2 SQLite → L3 API。
  /// 并发请求同一句子会复用同一个 Future。
  Future<SentenceTranslation> getTranslation(
    String text, {
    CancelToken? cancelToken,
  }) async {
    final hash = hashText(text);

    // L1: 内存缓存
    final cached = _translationCache[hash];
    if (cached != null) return cached;

    // 去重：复用正在进行的请求
    if (_pendingTranslations.containsKey(hash)) {
      return _pendingTranslations[hash]!;
    }

    final future = _fetchTranslation(hash, text, cancelToken: cancelToken);
    _pendingTranslations[hash] = future;
    try {
      return await future;
    } finally {
      _pendingTranslations.remove(hash);
    }
  }

  /// 获取解析（三级缓存查找）
  Future<SentenceAnalysis> getAnalysis(
    String text, {
    CancelToken? cancelToken,
  }) async {
    final hash = hashText(text);

    // L1: 内存缓存
    final cached = _analysisCache[hash];
    if (cached != null) return cached;

    // 去重：复用正在进行的请求
    if (_pendingAnalyses.containsKey(hash)) {
      return _pendingAnalyses[hash]!;
    }

    final future = _fetchAnalysis(hash, text, cancelToken: cancelToken);
    _pendingAnalyses[hash] = future;
    try {
      return await future;
    } finally {
      _pendingAnalyses.remove(hash);
    }
  }

  /// 获取意群拆分（三级缓存查找）
  Future<SenseGroupResult> getSenseGroups(
    String text, {
    CancelToken? cancelToken,
  }) async {
    final hash = hashText(text);

    // L1: 内存缓存
    final cached = _senseGroupCache[hash];
    if (cached != null) return cached;

    // 去重：复用正在进行的请求
    if (_pendingSenseGroups.containsKey(hash)) {
      return _pendingSenseGroups[hash]!;
    }

    final future = _fetchSenseGroups(hash, text, cancelToken: cancelToken);
    _pendingSenseGroups[hash] = future;
    try {
      return await future;
    } finally {
      _pendingSenseGroups.remove(hash);
    }
  }

  /// 同步查找 L1 翻译缓存（仅内存）
  SentenceTranslation? getCachedTranslation(String text) {
    return _translationCache[hashText(text)];
  }

  /// 同步查找 L1 解析缓存（仅内存）
  SentenceAnalysis? getCachedAnalysis(String text) {
    return _analysisCache[hashText(text)];
  }

  /// 同步查找 L1 意群缓存（仅内存）
  SenseGroupResult? getCachedSenseGroups(String text) {
    return _senseGroupCache[hashText(text)];
  }

  /// 清除内存缓存
  void clearMemoryCache() {
    _translationCache.clear();
    _analysisCache.clear();
    _senseGroupCache.clear();
  }

  /// L2 + L3 翻译查找
  Future<SentenceTranslation> _fetchTranslation(
    String hash,
    String text, {
    CancelToken? cancelToken,
  }) async {
    // L2: SQLite 缓存（JSON 损坏时跳过，fallthrough 到 L3）
    final dbResult = await _cacheDao.getByHash(hash, 'translation');
    if (dbResult != null) {
      try {
        final translation = SentenceTranslation.fromJson(
          jsonDecode(dbResult) as Map<String, dynamic>,
        );
        _translationCache[hash] = translation;
        return translation;
      } catch (_) {
        // L2 数据损坏或结构变更，继续到 L3 API 调用
      }
    }

    // L3: API 调用
    final translation = await _apiClient.translate(
      text,
      cancelToken: cancelToken,
    );
    // 写入 L1 + L2
    _translationCache[hash] = translation;
    await _cacheDao.upsert(
      hash,
      'translation',
      jsonEncode({'translation': translation.translation}),
    );
    return translation;
  }

  /// L2 + L3 解析查找
  Future<SentenceAnalysis> _fetchAnalysis(
    String hash,
    String text, {
    CancelToken? cancelToken,
  }) async {
    // L2: SQLite 缓存（JSON 损坏时跳过，fallthrough 到 L3）
    final dbResult = await _cacheDao.getByHash(hash, 'analysis');
    if (dbResult != null) {
      try {
        final analysis = SentenceAnalysis.fromJson(
          jsonDecode(dbResult) as Map<String, dynamic>,
        );
        _analysisCache[hash] = analysis;
        return analysis;
      } catch (_) {
        // L2 数据损坏或结构变更，继续到 L3 API 调用
      }
    }

    // L3: API 调用
    final analysis = await _apiClient.analyze(
      text,
      cancelToken: cancelToken,
    );
    // 写入 L1 + L2
    _analysisCache[hash] = analysis;
    await _cacheDao.upsert(
      hash,
      'analysis',
      jsonEncode({
        'analysis': {
          'grammar': analysis.grammar,
          'vocabulary': analysis.vocabulary,
          'listening': analysis.listening,
        },
      }),
    );
    return analysis;
  }

  /// L2 + L3 意群查找
  Future<SenseGroupResult> _fetchSenseGroups(
    String hash,
    String text, {
    CancelToken? cancelToken,
  }) async {
    // L2: SQLite 缓存
    final dbResult = await _cacheDao.getByHash(hash, 'sense_groups');
    if (dbResult != null) {
      final result = SenseGroupResult.fromJson(
        jsonDecode(dbResult) as Map<String, dynamic>,
      );
      _senseGroupCache[hash] = result;
      return result;
    }

    // L3: API 调用
    final result = await _apiClient.splitSenseGroups(
      text,
      cancelToken: cancelToken,
    );
    // 写入 L1 + L2
    _senseGroupCache[hash] = result;
    await _cacheDao.upsert(
      hash,
      'sense_groups',
      jsonEncode({
        'groups': result.groups.map((g) => g.toJson()).toList(),
      }),
    );
    return result;
  }
}

/// SentenceAiNotifier Provider
final sentenceAiNotifierProvider = Provider<SentenceAiNotifier>((ref) {
  return SentenceAiNotifier(
    cacheDao: ref.watch(sentenceAiCacheDaoProvider),
    apiClient: ref.watch(sentenceAiApiClientProvider),
  );
});
