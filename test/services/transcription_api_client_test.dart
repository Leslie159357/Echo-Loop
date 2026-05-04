import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:echo_loop/services/transcription_api_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  group('UploadUrlResponse.fromJson', () {
    test('音频已存在', () {
      final json = {
        'audioExists': true,
        'uploadUrl': null,
        'objectName': null,
        'publicUrl': null,
      };
      final resp = UploadUrlResponse.fromJson(json);
      expect(resp.audioExists, isTrue);
      expect(resp.uploadUrl, isNull);
    });

    test('音频不存在，返回上传 URL', () {
      final json = {
        'audioExists': false,
        'uploadUrl': 'https://r2.example.com/put?token=xxx',
        'objectName': 'user-audio/abc123.mp3',
        'publicUrl': 'https://cdn.example.com/user-audio/abc123.mp3',
      };
      final resp = UploadUrlResponse.fromJson(json);
      expect(resp.audioExists, isFalse);
      expect(resp.uploadUrl, 'https://r2.example.com/put?token=xxx');
      expect(resp.objectName, 'user-audio/abc123.mp3');
      expect(resp.publicUrl, 'https://cdn.example.com/user-audio/abc123.mp3');
    });
  });

  group('SubmitTranscriptionResponse.fromJson', () {
    test('缓存命中', () {
      final json = {
        'cached': true,
        'jobId': null,
        'transcript': {
          'sentences': [
            {'text': 'Hello', 'startTime': 0, 'endTime': 1000},
          ],
          'fullText': 'Hello',
        },
      };
      final resp = SubmitTranscriptionResponse.fromJson(json);
      expect(resp.cached, isTrue);
      expect(resp.transcript, isNotNull);
      expect(resp.transcript!.sentences, hasLength(1));
      expect(resp.transcript!.sentences.first.text, 'Hello');
    });

    test('缓存未命中', () {
      final json = {'cached': false, 'jobId': 'job-123', 'transcript': null};
      final resp = SubmitTranscriptionResponse.fromJson(json);
      expect(resp.cached, isFalse);
      expect(resp.jobId, 'job-123');
      expect(resp.transcript, isNull);
    });
  });

  group('JobStatusResponse', () {
    test('各状态正确解析', () {
      expect(
        JobStatusResponse.fromJson({'status': 'queued'}).isPending,
        isTrue,
      );
      expect(
        JobStatusResponse.fromJson({'status': 'running'}).isPending,
        isTrue,
      );
      expect(
        JobStatusResponse.fromJson({'status': 'succeeded'}).isCompleted,
        isTrue,
      );
      expect(
        JobStatusResponse.fromJson({
          'status': 'failed',
          'errorMessage': 'oops',
        }).isFailed,
        isTrue,
      );
    });

    test('失败时包含错误信息', () {
      final resp = JobStatusResponse.fromJson({
        'status': 'failed',
        'errorMessage': 'Deepgram error',
      });
      expect(resp.errorMessage, 'Deepgram error');
    });
  });

  group('TranscriptResult.fromJson', () {
    test('正确解析句子列表（后端单位为秒）', () {
      final json = {
        'sentences': [
          {'text': 'Hello world.', 'startTime': 0, 'endTime': 2.0},
          {'text': 'How are you?', 'startTime': 2.5, 'endTime': 4.0},
        ],
        'fullText': 'Hello world. How are you?',
      };
      final result = TranscriptResult.fromJson(json);
      expect(result.sentences, hasLength(2));
      expect(result.fullText, 'Hello world. How are you?');
      expect(result.sentences[0].startTime, Duration.zero);
      expect(result.sentences[0].endTime, const Duration(seconds: 2));
      expect(result.sentences[1].startTime, const Duration(milliseconds: 2500));
      expect(result.sentences[1].endTime, const Duration(seconds: 4));
    });

    test('空句子列表', () {
      final json = {'sentences': <Map<String, dynamic>>[], 'fullText': ''};
      final result = TranscriptResult.fromJson(json);
      expect(result.sentences, isEmpty);
    });

    test('缺少 fullText 字段默认空字符串', () {
      final json = {'sentences': <Map<String, dynamic>>[]};
      final result = TranscriptResult.fromJson(json);
      expect(result.fullText, '');
    });
  });

  group('TranscriptionApiClient', () {
    test('构造函数创建正确的 Dio 实例', () {
      final client = TranscriptionApiClient(baseUrl: 'https://test.com');
      // 验证不抛异常
      expect(client, isNotNull);
      client.dispose();
    });

    test('withDio 构造函数接受自定义 Dio', () {
      final dio = Dio(BaseOptions(baseUrl: 'https://mock.com'));
      final client = TranscriptionApiClient.withDio(dio);
      expect(client, isNotNull);
      client.dispose();
    });
  });
}
