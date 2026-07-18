/// 自定义 OpenAI 兼容 API 的云端转录服务。
///
/// 音频直接从设备上传到用户配置的 API，不经过 Echo Loop 后端。
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_io/io.dart';

import '../../models/word_timestamp.dart';
import '../../services/transcription_api_client.dart';
import '../../utils/srt_generator.dart';
import 'custom_api_config.dart';

const customTranscriptionMaxFileBytes = 25 * 1000 * 1000;
const diarizedTranscriptionModel = 'gpt-4o-transcribe-diarize';
const wordTimestampTranscriptionModel = 'whisper-1';

/// 自定义云端转录失败，并携带可供界面本地化的稳定错误码。
class CustomCloudTranscriptionException implements Exception {
  final String code;

  const CustomCloudTranscriptionException(this.code);

  @override
  String toString() => 'CustomCloudTranscriptionException($code)';
}

class CustomCloudTranscriptionService {
  final Dio _dio;

  CustomCloudTranscriptionService({
    required String baseUrl,
    required String apiKey,
  }) : _dio = Dio(
         BaseOptions(
           baseUrl: '${normalizeCustomApiBaseUrl(baseUrl)}/',
           connectTimeout: const Duration(seconds: 20),
           sendTimeout: const Duration(minutes: 5),
           receiveTimeout: const Duration(minutes: 10),
           headers: {'Authorization': 'Bearer $apiKey'},
         ),
       );

  /// 测试构造函数：允许注入 Dio，避免真实网络请求。
  CustomCloudTranscriptionService.withDio(this._dio);

  /// 上传音频并生成带时间轴的字幕结果。
  ///
  /// `gpt-4o-transcribe-diarize` 返回说话人分段时间戳；`whisper-1`
  /// 返回分段及逐词时间戳。普通 `gpt-4o-transcribe` 没有字幕时间轴，故不接收。
  Future<TranscriptResult> transcribe({
    required String filePath,
    required String model,
    required String language,
    bool mergeShortSentences = true,
    CancelToken? cancelToken,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    if (model != diarizedTranscriptionModel &&
        model != wordTimestampTranscriptionModel) {
      throw const CustomCloudTranscriptionException('unsupported_model');
    }

    final file = File(filePath);
    if (!await file.exists()) {
      throw const CustomCloudTranscriptionException('file_not_found');
    }
    if (await file.length() > customTranscriptionMaxFileBytes) {
      throw const CustomCloudTranscriptionException('file_too_large');
    }

    final fields = <String, dynamic>{
      'file': await MultipartFile.fromFile(filePath),
      'model': model,
      if (language != 'auto') 'language': language,
      if (model == diarizedTranscriptionModel) ...{
        'response_format': 'diarized_json',
        'chunking_strategy': 'auto',
      } else ...{
        'response_format': 'verbose_json',
        'timestamp_granularities[]': ['segment', 'word'],
      },
    };

    final response = await _dio.post<Object?>(
      'audio/transcriptions',
      data: FormData.fromMap(fields),
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
    );
    final parsed = parseCustomTranscriptionResponse(
      response.data,
      model: model,
    );
    if (!mergeShortSentences || parsed.sentences.length <= 1) return parsed;
    return TranscriptResult(
      sentences: mergeShortTranscriptSentences(parsed.sentences),
      words: parsed.words,
      fullText: parsed.fullText,
    );
  }

  void dispose() => _dio.close();
}

/// 将 OpenAI 音频端点响应转换为 App 现有的字幕领域模型。
TranscriptResult parseCustomTranscriptionResponse(
  Object? raw, {
  required String model,
}) {
  final data = _responseMap(raw);
  final sentences = _parseSegments(data['segments']);
  final words = model == wordTimestampTranscriptionModel
      ? _parseWords(data['words'])
      : const <WordTimestamp>[];
  final rawText = data['text'];
  final fullText = rawText is String && rawText.trim().isNotEmpty
      ? rawText.trim()
      : sentences.map((sentence) => sentence.text).join(' ').trim();

  final resolvedSentences = sentences.isNotEmpty
      ? sentences
      : _fallbackSentence(fullText, words);
  return TranscriptResult(
    sentences: resolvedSentences,
    words: words.isEmpty ? null : words,
    fullText: fullText,
  );
}

Map<String, dynamic> _responseMap(Object? raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is String) {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
  }
  throw const FormatException('Invalid transcription response');
}

List<TranscriptSentence> _parseSegments(Object? raw) {
  if (raw is! List) return const [];
  final result = <TranscriptSentence>[];
  for (final item in raw) {
    if (item is! Map<String, dynamic>) continue;
    final text = item['text'];
    final start = item['start'];
    final end = item['end'];
    if (text is! String || start is! num || end is! num) continue;
    final normalizedText = text.trim();
    if (normalizedText.isEmpty || end <= start) continue;
    result.add(
      TranscriptSentence(
        text: normalizedText,
        startTime: _secondsToDuration(start),
        endTime: _secondsToDuration(end),
      ),
    );
  }
  return result;
}

List<WordTimestamp> _parseWords(Object? raw) {
  if (raw is! List) return const [];
  final result = <WordTimestamp>[];
  for (final item in raw) {
    if (item is! Map<String, dynamic>) continue;
    final word = item['word'];
    final start = item['start'];
    final end = item['end'];
    if (word is! String || start is! num || end is! num || end <= start) {
      continue;
    }
    final probability = item['probability'];
    result.add(
      WordTimestamp(
        word: word.trim(),
        startTime: _secondsToDuration(start),
        endTime: _secondsToDuration(end),
        confidence: probability is num ? probability.toDouble() : 1.0,
      ),
    );
  }
  return result;
}

List<TranscriptSentence> _fallbackSentence(
  String fullText,
  List<WordTimestamp> words,
) {
  if (fullText.isEmpty || words.isEmpty) return const [];
  return [
    TranscriptSentence(
      text: fullText,
      startTime: words.first.startTime,
      endTime: words.last.endTime,
    ),
  ];
}

Duration _secondsToDuration(num seconds) =>
    Duration(milliseconds: (seconds.toDouble() * 1000).round());

/// 合并相邻的过短字幕段，让逐句学习时的句长更自然。
List<TranscriptSentence> mergeShortTranscriptSentences(
  List<TranscriptSentence> sentences,
) {
  if (sentences.length <= 1) return sentences;
  const minimumTarget = Duration(seconds: 4);
  final result = <TranscriptSentence>[];
  TranscriptSentence? current;
  for (final sentence in sentences) {
    if (current == null) {
      current = sentence;
      continue;
    }
    if (current.endTime - current.startTime >= minimumTarget) {
      result.add(current);
      current = sentence;
      continue;
    }
    current = TranscriptSentence(
      text: '${current.text.trim()} ${sentence.text.trim()}'.trim(),
      startTime: current.startTime,
      endTime: sentence.endTime,
    );
  }
  if (current != null) result.add(current);
  return result;
}

final customCloudTranscriptionServiceProvider =
    Provider<CustomCloudTranscriptionService>((ref) {
      final config = ref.watch(customApiConfigNotifierProvider);
      final apiKey = ref
          .read(customApiConfigNotifierProvider.notifier)
          .apiKey;
      final service = CustomCloudTranscriptionService(
        baseUrl: config.baseUrl,
        apiKey: apiKey,
      );
      ref.onDispose(service.dispose);
      return service;
    });
