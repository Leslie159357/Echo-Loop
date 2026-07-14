/// OpenAI 兼容 API 调用服务
///
/// 使用 `POST /v1/chat/completions` 实现翻译、解析、意群拆分、查词等 AI 功能。
/// 支持流式（SSE）和非流式响应。完全离线兼容——只需指向任意 OpenAI 兼容 API。
library;

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/dictionary/dictionary_entry.dart';
import '../models/sense_group_result.dart';
import '../models/sentence_ai_result.dart';
import '../features/custom_api/custom_api_config.dart';
import 'sentence_ai_api_client.dart';
import 'app_logger.dart';

/// 自定义 AI 服务：通过 OpenAI 兼容 API 提供所有 AI 功能。
class CustomAiService {
  final CustomApiConfig _config;
  final Dio _dio;

  CustomAiService(this._config)
      : _dio = Dio(BaseOptions(
          baseUrl: _config.baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 60),
          headers: {
            'Content-Type': 'application/json',
            if (_config.apiKey.isNotEmpty)
              'Authorization': 'Bearer ${_config.apiKey}',
          },
        ));

  /// 刷新模型列表：调用 `GET /v1/models` 获取可用模型。
  Future<List<String>> refreshModels() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/models');
      final data = response.data;
      if (data == null) return [];
      final models = data['data'];
      if (models is! List) return [];
      return models
          .map((m) => m is Map ? m['id']?.toString() ?? '' : '')
          .where((id) => id.isNotEmpty)
          .toList()
        ..sort();
    } catch (e) {
      AppLogger.log('CustomAI', '刷新模型列表失败: $e');
      return [];
    }
  }

  /// 构建统一的 chat completion 请求体。
  Map<String, dynamic> _buildBody({
    required String systemPrompt,
    required String userMessage,
    bool stream = false,
  }) {
    return {
      'model': _config.model.isNotEmpty ? _config.model : 'gpt-4o-mini',
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userMessage},
      ],
      'temperature': 0.3,
      'stream': stream,
      if (!stream) ...{
        'max_tokens': 2048,
      },
    };
  }

  /// 从 SSE 流式响应中提取完整文本。
  Stream<String> _streamChat(String systemPrompt, String userMessage) async* {
    final body = _buildBody(
      systemPrompt: systemPrompt,
      userMessage: userMessage,
      stream: true,
    );

    final response = await _dio.post<ResponseBody>(
      '/chat/completions',
      data: body,
      options: Options(responseType: ResponseType.stream),
    );

    final responseBody = response.data;
    if (responseBody == null) return;

    await for (final chunk in responseBody.stream.transform(
      utf8.decoder.transform(const LineSplitter()),
    )) {
      final line = chunk.toString().trim();
      if (!line.startsWith('data: ')) continue;
      final jsonStr = line.substring(6).trim();
      if (jsonStr == '[DONE]') break;
      try {
        final json = jsonDecode(jsonStr) as Map<String, dynamic>;
        final choices = json['choices'] as List?;
        if (choices == null || choices.isEmpty) continue;
        final delta = choices[0] as Map<String, dynamic>?;
        if (delta == null) continue;
        final content = delta['delta'] is Map
            ? (delta['delta'] as Map)['content']?.toString() ?? ''
            : '';
        if (content.isNotEmpty) yield content;
      } catch (_) {
        // 跳过无法解析的帧
      }
    }
  }

  /// 非流式调用：返回完整响应文本。
  Future<String> _chat(String systemPrompt, String userMessage) async {
    final body = _buildBody(
      systemPrompt: systemPrompt,
      userMessage: userMessage,
      stream: false,
    );

    final response = await _dio.post<Map<String, dynamic>>(
      '/chat/completions',
      data: body,
    );

    final data = response.data;
    if (data == null) return '';

    final choices = data['choices'] as List?;
    if (choices == null || choices.isEmpty) return '';
    final choice = choices[0] as Map<String, dynamic>?;
    if (choice == null) return '';
    final message = choice['message'] as Map<String, dynamic>?;
    if (message == null) return '';
    return (message['content'] as String?)?.trim() ?? '';
  }

  // ─── 翻译 ───────────────────────────────────────────────

  /// 翻译句子（流式）。
  Stream<SentenceTranslationStreamFrame> translateStream(
    String text, {
    String? previousText,
    String? nextText,
    String? targetLanguage,
    CancelToken? cancelToken,
  }) async* {
    final lang = targetLanguage ?? 'zh-CN';
    final context = [
      if (previousText != null) '上文: $previousText',
      '目标句: $text',
      if (nextText != null) '下文: $nextText',
    ].join('\n');

    final systemPrompt = '你是一个英语学习助手。请将以下英文句子翻译成$lang。'
        '只输出翻译结果，不要解释。如果有上下文，结合上下文理解句意。';

    String fullTranslation = '';
    try {
      await for (final chunk in _streamChat(systemPrompt, context)) {
        fullTranslation += chunk;
        yield SentenceTranslationStreamFrame(
          translation: SentenceTranslation(translation: fullTranslation),
          isFinal: false,
        );
      }
    } catch (e) {
      AppLogger.log('CustomAI', '翻译流失败: $e');
      rethrow;
    }
    if (fullTranslation.isNotEmpty) {
      yield SentenceTranslationStreamFrame(
        translation: SentenceTranslation(translation: fullTranslation),
        isFinal: true,
      );
    }
  }

  // ─── 句子解析 ─────────────────────────────────────────────

  /// 解析句子（流式）：返回语法/词汇/听力要点。
  Stream<SentenceAnalysisStreamFrame> analyzeStream(
    String text, {
    String? targetLanguage,
    CancelToken? cancelToken,
  }) async* {
    final lang = targetLanguage ?? 'zh-CN';
    final systemPrompt = '你是一个英语语法和词汇分析助手。请用$lang分析以下英文句子。\n\n'
        '按以下 JSON 格式输出（只输出 JSON，不要额外文字）：\n'
        '{\n'
        '  "grammar": [{"point": "语法点", "detail": "详细解释"}],\n'
        '  "vocabulary": [{"word": "单词", "partOfSpeech": "词性", "definition": "释义", "example": "例句"}],\n'
        '  "listening": [{"tip": "听力技巧", "detail": "说明"}]\n'
        '}\n\n'
        '如果某类没有内容，用空数组 []。';

    String fullContent = '';
    try {
      await for (final chunk in _streamChat(systemPrompt, text)) {
        fullContent += chunk;
        // 尝试解析当前累积的 JSON
        try {
          final json = jsonDecode(fullContent) as Map<String, dynamic>;
          final analysis = SentenceAnalysis.fromJson(json);
          yield SentenceAnalysisStreamFrame(
            analysis: analysis,
            isFinal: false,
          );
        } catch (_) {
          // JSON 尚未完整，继续累积
        }
      }
    } catch (e) {
      AppLogger.log('CustomAI', '解析流失败: $e');
      rethrow;
    }

    // 最终完整结果
    if (fullContent.isNotEmpty) {
      try {
        final json = jsonDecode(fullContent) as Map<String, dynamic>;
        final analysis = SentenceAnalysis.fromJson(json);
        yield SentenceAnalysisStreamFrame(
          analysis: analysis,
          isFinal: true,
        );
      } catch (e) {
        AppLogger.log('CustomAI', '解析最终 JSON 失败: $e');
        // 返回空结果避免挂起
        yield SentenceAnalysisStreamFrame(
          analysis: const SentenceAnalysis(),
          isFinal: true,
        );
      }
    }
  }

  // ─── 意群拆分 ─────────────────────────────────────────────

  /// 意群拆分（流式）。
  Stream<SenseGroupsStreamFrame> senseGroupsStream(
    String text, {
    CancelToken? cancelToken,
  }) async* {
    final systemPrompt = '你是一个英语句子结构分析助手。请将以下英文句子按意群拆分。\n\n'
        '按以下 JSON 格式输出（只输出 JSON，不要额外文字）：\n'
        '{\n'
        '  "medium": ["中等粒度意群1", "中等粒度意群2", ...],\n'
        '  "fine": ["细粒度意群1", "细粒度意群2", ...]\n'
        '}\n\n'
        '中等粒度按自然口语节奏分割，细粒度让结构更清晰。'
        '各粒度下所有片段拼接起来必须能完整还原原句。';

    String fullContent = '';
    try {
      await for (final chunk in _streamChat(systemPrompt, text)) {
        fullContent += chunk;
        try {
          final json = jsonDecode(fullContent) as Map<String, dynamic>;
          final result = SenseGroupResult.fromJson(json);
          yield SenseGroupsStreamFrame(result: result, isFinal: false);
        } catch (_) {}
      }
    } catch (e) {
      AppLogger.log('CustomAI', '意群流失败: $e');
      rethrow;
    }

    if (fullContent.isNotEmpty) {
      try {
        final json = jsonDecode(fullContent) as Map<String, dynamic>;
        final result = SenseGroupResult.fromJson(json);
        yield SenseGroupsStreamFrame(result: result, isFinal: true);
      } catch (e) {
        AppLogger.log('CustomAI', '意群最终 JSON 失败: $e');
        yield SenseGroupsStreamFrame(
          result: SenseGroupResult(medium: [], fine: []),
          isFinal: true,
        );
      }
    }
  }

  // ─── AI 词典（查单词） ─────────────────────────────────────────────

  /// 查单词（流式）。
  Stream<AiDictionaryStreamFrame> lookupWordStream(
    String word, {
    String? targetLanguage,
    CancelToken? cancelToken,
  }) =>
      _lookupStream('word', word, targetLanguage: targetLanguage);

  /// 查词组/短语（流式）。
  Stream<AiDictionaryStreamFrame> lookupPhraseStream(
    String phrase, {
    String? targetLanguage,
    CancelToken? cancelToken,
  }) =>
      _lookupStream('phrase', phrase, targetLanguage: targetLanguage);

  Stream<AiDictionaryStreamFrame> _lookupStream(
    String type,
    String query, {
    String? targetLanguage,
  }) async* {
    final lang = targetLanguage ?? 'zh-CN';
    final systemPrompt = type == 'word'
        ? '你是一个英语词典助手。请用$lang解释以下英语单词。\n\n'
            '按以下 JSON 格式输出（只输出 JSON，不要额外文字）：\n'
            '{\n'
            '  "word": "单词",\n'
            '  "pronunciation": "音标",\n'
            '  "partOfSpeech": "词性",\n'
            '  "definitions": [{"definition": "释义", "example": "例句"}],\n'
            '  "synonyms": ["近义词1", "近义词2"],\n'
            '  "antonyms": ["反义词1"]\n'
            '}'
        : '你是一个英语词典助手。请用$lang解释以下英语短语。\n\n'
            '按以下 JSON 格式输出（只输出 JSON，不要额外文字）：\n'
            '{\n'
            '  "phrase": "短语",\n'
            '  "definitions": [{"definition": "释义", "example": "例句"}],\n'
            '  "usage": "用法说明"\n'
            '}';

    String fullContent = '';
    try {
      await for (final chunk in _streamChat(systemPrompt, query)) {
        fullContent += chunk;
        try {
          final json = jsonDecode(fullContent) as Map<String, dynamic>;
          final entry = type == 'word'
              ? DictionaryEntry.fromJson(json)
              : MultiWordDictionaryEntry.fromJson(json);
          yield AiDictionaryStreamFrame(entry: entry, isFinal: false);
        } catch (_) {}
      }
    } catch (e) {
      AppLogger.log('CustomAI', '词典流失败: $e');
      rethrow;
    }

    if (fullContent.isNotEmpty) {
      try {
        final json = jsonDecode(fullContent) as Map<String, dynamic>;
        final entry = type == 'word'
            ? DictionaryEntry.fromJson(json)
            : MultiWordDictionaryEntry.fromJson(json);
        yield AiDictionaryStreamFrame(entry: entry, isFinal: true);
      } catch (e) {
        AppLogger.log('CustomAI', '词典最终 JSON 失败: $e');
      }
    }
  }

  /// 释放资源。
  void dispose() => _dio.close();
}
