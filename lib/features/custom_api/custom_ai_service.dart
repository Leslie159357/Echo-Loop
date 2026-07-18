/// 自定义 OpenAI 兼容文本模型服务。
///
/// 使用 Chat Completions 保持第三方兼容性，并要求模型返回结构化 JSON。
library;

import 'dart:convert';

import 'package:dio/dio.dart';

import 'custom_api_config.dart';

class CustomAiService {
  final Dio _dio;
  final String model;

  CustomAiService({
    required String baseUrl,
    required String apiKey,
    required this.model,
  }) : _dio = Dio(
         BaseOptions(
           baseUrl: '${normalizeCustomApiBaseUrl(baseUrl)}/',
           connectTimeout: const Duration(seconds: 20),
           sendTimeout: const Duration(minutes: 2),
           receiveTimeout: const Duration(minutes: 5),
           headers: {'Authorization': 'Bearer $apiKey'},
         ),
       );

  CustomAiService.withDio(this._dio, {required this.model});

  Future<Map<String, dynamic>> translate({
    required String text,
    required String targetLanguage,
    String? previousText,
    String? nextText,
    CancelToken? cancelToken,
  }) => _completeJson(
    systemPrompt:
        'Translate only the target sentence into $targetLanguage. Use the '
        'neighboring sentences only as context. Return JSON exactly as '
        '{"translation":"natural translation"}.',
    userPrompt: [
      if (previousText != null) 'Previous context: $previousText',
      'Target sentence: $text',
      if (nextText != null) 'Next context: $nextText',
    ].join('\n'),
    cancelToken: cancelToken,
  );

  Future<Map<String, dynamic>> analyze({
    required String text,
    required String targetLanguage,
    CancelToken? cancelToken,
  }) => _completeJson(
    systemPrompt:
        'Analyze an English sentence for a language learner. Explanations must '
        'use $targetLanguage. Return only JSON with this shape: '
        '{"grammar":[{"point":"","note":""}],'
        '"vocabulary":[{"term":"","note":""}],'
        '"listening":[{"phrase":"","note":""}]}. Keep every list concise.',
    userPrompt: text,
    cancelToken: cancelToken,
  );

  Future<Map<String, dynamic>> senseGroups({
    required String text,
    CancelToken? cancelToken,
  }) => _completeJson(
    systemPrompt:
        'Split the exact input into natural English listening chunks. Return '
        'only JSON as {"medium":["..."],"fine":["..."]}. Concatenating '
        'each array must reproduce the input exactly, including spaces and '
        'punctuation. Medium chunks are broader than fine chunks.',
    userPrompt: text,
    cancelToken: cancelToken,
  );

  Future<Map<String, dynamic>> lookupWord({
    required String word,
    required String targetLanguage,
    CancelToken? cancelToken,
  }) => _completeJson(
    systemPrompt:
        'Create a concise learner dictionary entry for one English word. '
        'Translations and learner notes use $targetLanguage. Return only JSON '
        'with this shape: {"headword":"","pronunciation":{"uk":"",'
        '"us":""},"meanings":[{"partOfSpeech":"","translation":[], '
        '"definition":"","usageNote":"","examples":[{"sentence":"",'
        '"translation":""}],"synonyms":[],"antonyms":[]}],'
        '"commonExpressions":[{"expression":"","type":"","meaning":"",'
        '"example":{"sentence":"","translation":""}}],"wordFamily":[],'
        '"forms":[],"etymology":"","learnerTips":[]}. Use empty arrays '
        'for unavailable optional sections.',
    userPrompt: word,
    cancelToken: cancelToken,
  );

  Future<Map<String, dynamic>> lookupPhrase({
    required String phrase,
    required String targetLanguage,
    CancelToken? cancelToken,
  }) => _completeJson(
    systemPrompt:
        'Explain an English phrase for a learner in $targetLanguage. Return '
        'only JSON with this shape: {"originalExpression":"",'
        '"naturalness":"","category":"","pronunciationTips":[],'
        '"keyPoints":[{"point":"","sentence":"","translation":""}],'
        '"meanings":[{"translation":[],"examples":[{"sentence":"",'
        '"translation":""}]}],"similarExpressions":[{"expression":"",'
        '"difference":"","sentence":"","translation":""}],'
        '"background":""}. Use empty arrays for unavailable sections.',
    userPrompt: phrase,
    cancelToken: cancelToken,
  );

  Future<Map<String, dynamic>> _completeJson({
    required String systemPrompt,
    required String userPrompt,
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'chat/completions',
      data: {
        'model': model,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt},
        ],
        'response_format': {'type': 'json_object'},
      },
      cancelToken: cancelToken,
    );
    final content = _messageContent(response.data);
    final decoded = jsonDecode(_stripMarkdownFence(content));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('AI response is not a JSON object');
    }
    return decoded;
  }

  String _messageContent(Map<String, dynamic>? data) {
    final choices = data?['choices'];
    if (choices is! List || choices.isEmpty) {
      throw const FormatException('AI response has no choices');
    }
    final first = choices.first;
    if (first is! Map<String, dynamic>) {
      throw const FormatException('AI choice is invalid');
    }
    final message = first['message'];
    if (message is! Map<String, dynamic>) {
      throw const FormatException('AI message is invalid');
    }
    final content = message['content'];
    if (content is! String || content.trim().isEmpty) {
      throw const FormatException('AI message is empty');
    }
    return content.trim();
  }

  String _stripMarkdownFence(String content) {
    if (!content.startsWith('```')) return content;
    return content
        .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
        .replaceFirst(RegExp(r'\s*```$'), '');
  }

  void dispose() => _dio.close();
}
