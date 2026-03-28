/// AI 句子翻译/解析 API 客户端
///
/// 封装与后端 `/api/v1/ai/` 的通信，用于获取句子的翻译和语法解析。
/// 基于 Dio，receiveTimeout 设为 60 秒以适应 LLM 响应延迟。
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../analytics/geo_interceptor.dart';
import '../config/api_config.dart';
import '../models/sentence_ai_result.dart';
import '../models/sense_group_result.dart';
import '../models/word_analysis.dart';

part 'sentence_ai_api_client.g.dart';

/// AI 句子翻译/解析 API 客户端
class SentenceAiApiClient {
  final Dio _dio;

  SentenceAiApiClient({required String baseUrl})
    : _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 60),
        ),
      ) {
    // 异步添加 GeoInterceptor（SharedPreferences 在 main() 中已初始化，几乎同步返回）
    SharedPreferences.getInstance().then(
      (prefs) => _dio.interceptors.add(GeoInterceptor(prefs)),
    );
    _dio.interceptors.add(
      LogInterceptor(
        requestBody: false,
        responseBody: false,
        logPrint: (obj) => print('[AI-API] $obj'),
      ),
    );
  }

  /// 用于测试的构造函数，允许注入 Dio 实例
  SentenceAiApiClient.withDio(this._dio);

  /// 翻译句子
  ///
  /// 调用后端 AI 翻译接口，返回中文翻译结果。
  Future<SentenceTranslation> translate(
    String text, {
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/ai/translate',
      data: {'text': text},
      cancelToken: cancelToken,
    );
    return SentenceTranslation.fromJson(response.data!);
  }

  /// 解析句子
  ///
  /// 调用后端 AI 解析接口，返回语法、词汇和用法分析。
  Future<SentenceAnalysis> analyze(
    String text, {
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/ai/analyze',
      data: {'text': text},
      cancelToken: cancelToken,
    );
    return SentenceAnalysis.fromJson(response.data!);
  }

  /// 解析单词
  ///
  /// 调用后端 AI 单词解析接口，返回语境释义、搭配、用法和词族分析。
  /// [sentence] 为可选上下文句子，帮助 AI 确定语境含义。
  Future<WordAnalysis> analyzeWord(
    String word, {
    String? sentence,
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/ai/word-analyze',
      data: {'word': word, if (sentence != null) 'sentence': sentence},
      cancelToken: cancelToken,
    );
    return WordAnalysis.fromJson(response.data!);
  }

  /// 拆分意群
  ///
  /// 调用后端 AI 意群拆分接口，返回意群列表（含中文翻译）。
  Future<SenseGroupResult> splitSenseGroups(
    String text, {
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/ai/sense-groups',
      data: {'text': text},
      cancelToken: cancelToken,
    );
    return SenseGroupResult.fromJson(response.data!);
  }

  /// 释放资源
  void dispose() => _dio.close();
}

/// AI API 客户端单例 Provider
@Riverpod(keepAlive: true)
SentenceAiApiClient sentenceAiApiClient(Ref ref) {
  final client = SentenceAiApiClient(baseUrl: apiBaseUrl);
  ref.onDispose(client.dispose);
  return client;
}
