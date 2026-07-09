/// AI 句子翻译/解析 API 客户端
///
/// 封装与后端 `/api/v1/ai/` 的通信，用于获取句子的翻译和语法解析。
/// 基于 Dio，receiveTimeout 设为 60 秒以适应 LLM 响应延迟。
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../analytics/geo_interceptor.dart';
import '../config/api_config.dart';
import '../providers/package_info_provider.dart';
import 'api_log_interceptor.dart';
import 'app_logger.dart';
import 'client_info.dart';
import 'dictionary/dictionary_source.dart';
import 'ndjson_stream.dart';
import '../models/sentence_ai_result.dart';
import '../models/sense_group_result.dart';
import '../models/dictionary/dictionary_entry.dart';

part 'sentence_ai_api_client.g.dart';

/// AI 词典流式协议帧。
///
/// [isFinal] 只在后端完整成功末帧为 true；调用方只有收到 final 才能把最后
/// 一帧视为可缓存的完整结果。
class AiDictionaryStreamFrame {
  final AiDictionaryEntry entry;
  final bool isFinal;

  const AiDictionaryStreamFrame({required this.entry, required this.isFinal});
}

/// AI 句子翻译/解析 API 客户端
class SentenceAiApiClient {
  final Dio _dio;

  /// [appVersion] 随请求以 `x-app-version` 上报（版本灰度预留），可为 null。
  /// 平台标识 `x-app-platform` 恒定携带——后端据此按平台决定是否限额。
  SentenceAiApiClient({required String baseUrl, String? appVersion})
    : _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 60),
          headers: clientInfoHeaders(appVersion: appVersion),
        ),
      ) {
    // 异步添加 GeoInterceptor（SharedPreferences 在 main() 中已初始化，几乎同步返回）
    SharedPreferences.getInstance().then(
      (prefs) => _dio.interceptors.add(GeoInterceptor(prefs)),
    );
    _dio.interceptors.add(ApiLogInterceptor(tag: 'AI-API'));
  }

  /// 用于测试的构造函数，允许注入 Dio 实例
  SentenceAiApiClient.withDio(this._dio);

  /// 请求公共 headers（仅测试用，验证平台/版本标识已随请求携带）。
  @visibleForTesting
  Map<String, dynamic> get defaultHeaders => _dio.options.headers;

  /// 翻译句子
  ///
  /// 调用后端 AI 翻译接口，返回目标语言的翻译结果。
  /// [targetLanguage] 为 BCP 47 代码（如 'zh-CN'），不传则由后端决定默认值。
  Future<SentenceTranslation> translate(
    String text, {
    required String accessToken,
    String? targetLanguage,
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v2/ai/translate',
      data: {
        'text': text,
        if (targetLanguage != null) 'targetLanguage': targetLanguage,
      },
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      cancelToken: cancelToken,
    );
    return SentenceTranslation.fromJson(response.data!);
  }

  /// 解析句子
  ///
  /// 调用后端 AI 解析接口，返回语法、词汇和听力分析。
  /// [targetLanguage] 为 BCP 47 代码（如 'zh-CN'），不传则由后端决定默认值。
  Future<SentenceAnalysis> analyze(
    String text, {
    required String accessToken,
    String? targetLanguage,
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v2/ai/analyze',
      data: {
        'text': text,
        if (targetLanguage != null) 'targetLanguage': targetLanguage,
      },
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      cancelToken: cancelToken,
    );
    return SentenceAnalysis.fromJson(response.data!);
  }

  /// AI 词典释义（单词，流式）
  ///
  /// 调用后端 `POST /api/v1/stream/lookup-word`（需登录态），字段级增量流式
  /// （NDJSON，见 [_streamDictionaryFrames]）。仅用于单词（规范化后无空白）；
  /// 词组用 [lookupPhraseStream]。
  Stream<AiDictionaryEntry> lookupWordStream(
    String word, {
    required String accessToken,
    String? targetLanguage,
    CancelToken? cancelToken,
  }) => lookupWordStreamFrames(
    word,
    accessToken: accessToken,
    targetLanguage: targetLanguage,
    cancelToken: cancelToken,
  ).map((frame) => frame.entry);

  /// AI 词典释义（单词，带协议帧信息）。
  Stream<AiDictionaryStreamFrame> lookupWordStreamFrames(
    String word, {
    required String accessToken,
    String? targetLanguage,
    CancelToken? cancelToken,
  }) => _streamDictionaryFrames(
    '/api/v1/stream/lookup-word',
    word,
    accessToken: accessToken,
    targetLanguage: targetLanguage,
    cancelToken: cancelToken,
  );

  /// AI 词典释义（多词/短语，流式）
  ///
  /// 调用后端 `POST /api/v1/stream/lookup-phrase`（需登录态），字段级增量流式
  /// （NDJSON，见 [_streamDictionaryFrames]）。仅用于多词表达（规范化后含空白）；
  /// 单词用 [lookupWordStream]。
  Stream<AiDictionaryEntry> lookupPhraseStream(
    String phrase, {
    required String accessToken,
    String? targetLanguage,
    CancelToken? cancelToken,
  }) => lookupPhraseStreamFrames(
    phrase,
    accessToken: accessToken,
    targetLanguage: targetLanguage,
    cancelToken: cancelToken,
  ).map((frame) => frame.entry);

  /// AI 词典释义（多词/短语，带协议帧信息）。
  Stream<AiDictionaryStreamFrame> lookupPhraseStreamFrames(
    String phrase, {
    required String accessToken,
    String? targetLanguage,
    CancelToken? cancelToken,
  }) => _streamDictionaryFrames(
    '/api/v1/stream/lookup-phrase',
    phrase,
    accessToken: accessToken,
    targetLanguage: targetLanguage,
    cancelToken: cancelToken,
  );

  /// 流式查词通用实现：发起 `ResponseType.stream` 请求，逐帧解析 NDJSON。
  ///
  /// - 前置错误（非 200）：手动读小 JSON 错误体，映射为专用异常
  ///   （`phrase_too_long`/需登录）或带状态码的 [DioException]（如 402 由
  ///   controller 转额度态）。`validateStatus: (_) => true` 使 Dio 不在非 2xx
  ///   时提前抛出，让我们能读到错误体的 `code`。
  /// - 流内错误帧（`{"__error": ...}`）：抛 [DictionaryStreamException]。
  Stream<AiDictionaryStreamFrame> _streamDictionaryFrames(
    String path,
    String query, {
    required String accessToken,
    String? targetLanguage,
    CancelToken? cancelToken,
  }) async* {
    final response = await _dio.post<ResponseBody>(
      path,
      data: {
        'query': query,
        if (targetLanguage != null) 'targetLanguage': targetLanguage,
      },
      options: Options(
        responseType: ResponseType.stream,
        validateStatus: (_) => true,
        headers: {'Authorization': 'Bearer $accessToken'},
      ),
      cancelToken: cancelToken,
    );

    final body = response.data;
    final status = response.statusCode ?? 0;
    if (body == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
      );
    }

    if (status != 200) {
      final errorMap = await _decodeErrorBody(body);
      if (status == 400 && errorMap?['code'] == 'phrase_too_long') {
        throw const DictionaryPhraseTooLongException();
      }
      if (status == 401) {
        throw const DictionaryAuthRequiredException();
      }
      // 402（额度）等：抛带状态码的 DioException，沿用 controller 现有分支处理
      throw DioException(
        requestOptions: response.requestOptions,
        response: Response(
          requestOptions: response.requestOptions,
          statusCode: status,
          data: errorMap,
        ),
        type: DioExceptionType.badResponse,
      );
    }

    // 字段级增量累积：逐事件写入 acc，整体 fromJson 后 yield 完整帧。
    // 协议见后端 stream/_shared.ts：
    //   {"q":..} 元信息 / {"ops":[{"p":[...],"v":..},...]} 增量批 / {"done":true} / {"__error":..}
    final acc = <String, dynamic>{};
    try {
      await for (final ev in decodeNdjson(body.stream)) {
        // 调试：打印每个下发行原样，核对是否每 ≥500ms 一批、无重发。验证后删。
        AppLogger.log('DictStream', jsonEncode(ev));
        if (ev.containsKey('__error')) {
          throw const DictionaryStreamException();
        }
        if (ev['done'] == true) {
          yield AiDictionaryStreamFrame(
            entry: AiDictionaryEntry.fromJson(acc),
            isFinal: true,
          );
          break;
        }
        final q = ev['q'];
        if (q is String) {
          acc['queryType'] = q;
          continue; // 元信息不单独渲染
        }
        final ops = ev['ops'];
        if (ops is! List) {
          continue; // 未知事件，忽略
        }
        // 一行内可能含多个叶子（一次 flush 的批量），全部应用后只 yield 一帧
        for (final op in ops) {
          if (op is Map && op['p'] is List) {
            _setPath(acc, op['p'] as List<dynamic>, op['v']);
          }
        }
        yield AiDictionaryStreamFrame(
          entry: AiDictionaryEntry.fromJson(acc),
          isFinal: false,
        );
      }
    } on FormatException {
      throw const DictionaryStreamException();
    }
  }

  /// 按路径写入累积对象：沿 [path] 逐段下行，按**下一段类型**自动建容器
  /// （下一段是 int → 当前应为 `List` 并扩容到该下标；是 String → 应为 `Map`），
  /// 末段直接赋值。生成顺序保证下标从 0 递增无空洞。
  static void _setPath(
    Map<String, dynamic> root,
    List<dynamic> path,
    Object? value,
  ) {
    if (path.isEmpty) return;
    dynamic cur = root;
    for (var i = 0; i < path.length - 1; i++) {
      final seg = path[i];
      final next = path[i + 1];
      final child = _childAt(cur, seg);
      if (next is int) {
        if (child is! List) {
          _assign(cur, seg, <dynamic>[]);
        }
      } else if (child is! Map<String, dynamic>) {
        _assign(cur, seg, <String, dynamic>{});
      }
      cur = _childAt(cur, seg);
    }
    _assign(cur, path.last, value);
  }

  /// 读取容器 [cur] 在段 [seg]（int 下标 / String 键）处的子节点，越界/缺失回 null。
  static dynamic _childAt(dynamic cur, dynamic seg) {
    if (seg is int && cur is List) {
      return (seg >= 0 && seg < cur.length) ? cur[seg] : null;
    }
    if (seg is String && cur is Map) {
      return cur[seg];
    }
    return null;
  }

  /// 向容器 [cur] 的段 [seg] 赋值：List 按需用 null 扩容到 [seg]，Map 直接置键。
  static void _assign(dynamic cur, dynamic seg, Object? value) {
    if (seg is int && cur is List) {
      while (cur.length <= seg) {
        cur.add(null);
      }
      cur[seg] = value;
    } else if (seg is String && cur is Map) {
      cur[seg] = value;
    }
  }

  /// 读取非 200 响应的错误体（小 JSON），解析为 Map；失败返回 null。
  Future<Map<String, dynamic>?> _decodeErrorBody(ResponseBody body) async {
    try {
      final text = await utf8.decodeStream(body.stream);
      final decoded = jsonDecode(text);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// 拆分意群
  ///
  /// 调用后端 AI 意群拆分接口，返回意群列表（含中文翻译）。
  Future<SenseGroupResult> splitSenseGroups(
    String text, {
    required String accessToken,
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v2/ai/sense-groups',
      data: {'text': text},
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
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
  final client = SentenceAiApiClient(
    baseUrl: apiBaseUrl,
    appVersion: _readAppVersion(ref),
  );
  ref.onDispose(client.dispose);
  return client;
}

/// 读取 app 版本号；packageInfoProvider 未 override（如部分测试环境）时降级为
/// null（省略版本 header），不让辅助信息阻断客户端构建（同 §7.18 惰性降级原则）。
String? _readAppVersion(Ref ref) {
  try {
    return ref.read(packageInfoProvider).version;
  } catch (_) {
    return null;
  }
}
