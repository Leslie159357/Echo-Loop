// TranscriptionTaskManager 单元测试
//
// 测试转录任务的完整生命周期、状态转换、错误处理和取消逻辑。
// 通过 mock TranscriptionApiClient 和 TranscriptionFileOps 避免真实 I/O。
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fluency/models/audio_item.dart';
import 'package:fluency/providers/audio_library_provider.dart';
import 'package:fluency/providers/transcription_task_provider.dart';
import 'package:fluency/services/transcription_api_client.dart';
import 'package:fluency/utils/srt_generator.dart';

import '../helpers/mock_providers.dart';

// ─── Mock 类 ──────────────────────────────────────────────

class MockTranscriptionApiClient extends Mock
    implements TranscriptionApiClient {}

class MockTranscriptionFileOps extends Mock implements TranscriptionFileOps {}

class FakeAudioItem extends Fake implements AudioItem {}

// ─── 测试辅助 ──────────────────────────────────────────────

/// 创建测试用 AudioItem
AudioItem _testAudioItem({
  String id = 'test-audio-1',
  String name = 'Test Audio',
  String audioPath = 'audios/test.mp3',
  String? audioSha256,
}) {
  return AudioItem(
    id: id,
    name: name,
    audioPath: audioPath,
    addedDate: DateTime(2026),
    totalDuration: 120,
    sentenceCount: 0,
    wordCount: 0,
    audioSha256: audioSha256,
  );
}

/// 创建 ProviderContainer 并注入 mock
///
/// [audioItems] 初始音频列表，默认包含一个测试音频。
ProviderContainer _createContainer({
  required MockTranscriptionApiClient mockApi,
  required MockTranscriptionFileOps mockFileOps,
  List<AudioItem>? audioItems,
}) {
  final container = ProviderContainer(
    overrides: [
      transcriptionApiClientProvider.overrideWithValue(mockApi),
      transcriptionFileOpsProvider.overrideWithValue(mockFileOps),
      audioLibraryProvider.overrideWith(TestAudioLibrary.new),
    ],
  );
  // 初始化音频库
  (container.read(audioLibraryProvider.notifier) as TestAudioLibrary).setItems(
    audioItems ?? [_testAudioItem()],
  );
  return container;
}

void main() {
  late MockTranscriptionApiClient mockApi;
  late MockTranscriptionFileOps mockFileOps;

  setUpAll(() {
    registerFallbackValue(FakeAudioItem());
  });

  setUp(() {
    mockApi = MockTranscriptionApiClient();
    mockFileOps = MockTranscriptionFileOps();

    // 所有调用 startTranscription 的测试都需要 getDocDir
    when(
      () => mockFileOps.getDocDir(),
    ).thenAnswer((_) async => Directory.systemTemp);
  });

  group('TranscriptionTaskManager', () {
    test('初始状态为空 Map', () {
      final container = _createContainer(
        mockApi: mockApi,
        mockFileOps: mockFileOps,
      );
      final state = container.read(transcriptionTaskManagerProvider);
      expect(state, isEmpty);
      container.dispose();
    });

    test('getTaskState 对未知 audioId 返回 Idle', () {
      final container = _createContainer(
        mockApi: mockApi,
        mockFileOps: mockFileOps,
      );
      final notifier = container.read(
        transcriptionTaskManagerProvider.notifier,
      );
      expect(notifier.getTaskState('unknown'), isA<TranscriptionIdle>());
      container.dispose();
    });

    test('防止重复发起 — Hashing 状态下忽略新请求', () async {
      final container = _createContainer(
        mockApi: mockApi,
        mockFileOps: mockFileOps,
      );
      final notifier = container.read(
        transcriptionTaskManagerProvider.notifier,
      );

      // 手动设置为 Hashing 状态
      notifier.state = {'test-audio-1': const TranscriptionHashing()};

      // SHA256 不应被调用
      verifyNever(() => mockFileOps.computeSha256(any()));

      // 发起请求应被忽略
      await notifier.startTranscription(_testAudioItem(), 'en');
      verifyNever(() => mockFileOps.computeSha256(any()));

      container.dispose();
    });

    test('防止重复发起 — Uploading 状态下忽略新请求', () async {
      final container = _createContainer(
        mockApi: mockApi,
        mockFileOps: mockFileOps,
      );
      final notifier = container.read(
        transcriptionTaskManagerProvider.notifier,
      );

      notifier.state = {'test-audio-1': const TranscriptionUploading()};
      await notifier.startTranscription(_testAudioItem(), 'en');
      verifyNever(() => mockFileOps.computeSha256(any()));

      container.dispose();
    });

    test('防止重复发起 — Processing 状态下忽略新请求', () async {
      final container = _createContainer(
        mockApi: mockApi,
        mockFileOps: mockFileOps,
      );
      final notifier = container.read(
        transcriptionTaskManagerProvider.notifier,
      );

      notifier.state = {
        'test-audio-1': const TranscriptionProcessing(jobId: 'j1'),
      };
      await notifier.startTranscription(_testAudioItem(), 'en');
      verifyNever(() => mockFileOps.computeSha256(any()));

      container.dispose();
    });

    test('cancelTranscription 将状态重置为 Idle', () {
      final container = _createContainer(
        mockApi: mockApi,
        mockFileOps: mockFileOps,
      );
      final notifier = container.read(
        transcriptionTaskManagerProvider.notifier,
      );

      notifier.state = {
        'test-audio-1': const TranscriptionProcessing(jobId: 'j1'),
      };
      notifier.cancelTranscription('test-audio-1');

      expect(notifier.getTaskState('test-audio-1'), isA<TranscriptionIdle>());
      container.dispose();
    });

    test('clearState 从 Map 中移除条目', () {
      final container = _createContainer(
        mockApi: mockApi,
        mockFileOps: mockFileOps,
      );
      final notifier = container.read(
        transcriptionTaskManagerProvider.notifier,
      );

      notifier.state = {'test-audio-1': const TranscriptionCompleted()};
      notifier.clearState('test-audio-1');

      expect(container.read(transcriptionTaskManagerProvider), isEmpty);
      container.dispose();
    });

    test('缓存命中 — 跳过上传和轮询，直接完成', () async {
      final audioItem = _testAudioItem(audioSha256: 'abc123');

      // mock 文件操作
      when(
        () => mockFileOps.computeSha256(any()),
      ).thenAnswer((_) async => 'abc123');
      when(() => mockFileOps.getFileSize(any())).thenAnswer((_) async => 1024);
      when(
        () => mockFileOps.saveSrt(any(), any()),
      ).thenAnswer((_) async => 'transcripts/test_ai.srt');
      when(() => mockFileOps.getStats(any())).thenAnswer((_) async => (5, 50));

      // mock API: 音频已存在 + 字幕缓存命中
      when(
        () => mockApi.getUploadUrl(
          sha256: any(named: 'sha256'),
          mimeType: any(named: 'mimeType'),
          fileSize: any(named: 'fileSize'),
        ),
      ).thenAnswer(
        (_) async => const UploadUrlResponse(
          audioExists: true,
          objectName: 'user-audio/abc123.mp3',
          publicUrl: 'https://example.com/abc123.mp3',
        ),
      );

      when(
        () => mockApi.submitTranscription(
          sha256: any(named: 'sha256'),
          objectName: any(named: 'objectName'),
          publicUrl: any(named: 'publicUrl'),
          mimeType: any(named: 'mimeType'),
          fileSize: any(named: 'fileSize'),
          language: any(named: 'language'),
        ),
      ).thenAnswer(
        (_) async => SubmitTranscriptionResponse(
          cached: true,
          transcript: TranscriptResult(
            sentences: [
              TranscriptSentence(
                text: 'Hello world',
                startTime: Duration.zero,
                endTime: const Duration(seconds: 2),
              ),
            ],
            fullText: 'Hello world',
          ),
        ),
      );

      final container = _createContainer(
        mockApi: mockApi,
        mockFileOps: mockFileOps,
        audioItems: [audioItem],
      );
      final notifier = container.read(
        transcriptionTaskManagerProvider.notifier,
      );

      // 记录状态变化
      final states = <TranscriptionTaskState>[];
      container.listen(
        transcriptionTaskManagerProvider.select((m) => m['test-audio-1']),
        (_, next) {
          if (next != null) states.add(next);
        },
      );

      await notifier.startTranscription(audioItem, 'en');

      // 不应调用 uploadToR2
      verifyNever(
        () => mockApi.uploadToR2(
          uploadUrl: any(named: 'uploadUrl'),
          filePath: any(named: 'filePath'),
          contentType: any(named: 'contentType'),
        ),
      );

      // 不应轮询
      verifyNever(() => mockApi.getJobStatus(any()));

      // 应该保存 SRT
      verify(() => mockFileOps.saveSrt('test-audio-1', any())).called(1);

      // 最终状态是 Completed
      expect(
        notifier.getTaskState('test-audio-1'),
        isA<TranscriptionCompleted>(),
      );

      // 状态经历: Hashing → Uploading → Processing → Completed
      expect(states.length, greaterThanOrEqualTo(3));
      expect(states.first, isA<TranscriptionHashing>());
      expect(states.last, isA<TranscriptionCompleted>());

      container.dispose();
    });

    test('音频已缓存但字幕未缓存 — 跳过上传，创建 job', () async {
      final audioItem = _testAudioItem(audioSha256: 'abc123');

      when(
        () => mockFileOps.computeSha256(any()),
      ).thenAnswer((_) async => 'abc123');
      when(() => mockFileOps.getFileSize(any())).thenAnswer((_) async => 1024);

      // 音频已存在
      when(
        () => mockApi.getUploadUrl(
          sha256: any(named: 'sha256'),
          mimeType: any(named: 'mimeType'),
          fileSize: any(named: 'fileSize'),
        ),
      ).thenAnswer(
        (_) async => const UploadUrlResponse(
          audioExists: true,
          objectName: 'user-audio/abc123.mp3',
          publicUrl: 'https://example.com/abc123.mp3',
        ),
      );

      // 字幕未缓存，返回 jobId
      when(
        () => mockApi.submitTranscription(
          sha256: any(named: 'sha256'),
          objectName: any(named: 'objectName'),
          publicUrl: any(named: 'publicUrl'),
          mimeType: any(named: 'mimeType'),
          fileSize: any(named: 'fileSize'),
          language: any(named: 'language'),
        ),
      ).thenAnswer(
        (_) async =>
            const SubmitTranscriptionResponse(cached: false, jobId: 'job-123'),
      );

      // 轮询第一次返回 succeeded
      when(
        () => mockApi.getJobStatus('job-123'),
      ).thenAnswer((_) async => const JobStatusResponse(status: 'succeeded'));

      // 获取转录结果
      when(() => mockApi.getTranscript('abc123', 'en')).thenAnswer(
        (_) async => TranscriptResult(
          sentences: [
            TranscriptSentence(
              text: 'Test',
              startTime: Duration.zero,
              endTime: const Duration(seconds: 1),
            ),
          ],
          fullText: 'Test',
        ),
      );

      when(
        () => mockFileOps.saveSrt(any(), any()),
      ).thenAnswer((_) async => 'transcripts/test_ai.srt');
      when(() => mockFileOps.getStats(any())).thenAnswer((_) async => (1, 1));

      final container = _createContainer(
        mockApi: mockApi,
        mockFileOps: mockFileOps,
        audioItems: [audioItem],
      );
      final notifier = container.read(
        transcriptionTaskManagerProvider.notifier,
      );

      await notifier.startTranscription(audioItem, 'en');

      // 不应上传
      verifyNever(
        () => mockApi.uploadToR2(
          uploadUrl: any(named: 'uploadUrl'),
          filePath: any(named: 'filePath'),
          contentType: any(named: 'contentType'),
        ),
      );

      // 应该轮询
      verify(() => mockApi.getJobStatus('job-123')).called(1);

      // 最终完成
      expect(
        notifier.getTaskState('test-audio-1'),
        isA<TranscriptionCompleted>(),
      );

      container.dispose();
    });

    test('submitTranscription 无 jobId 时进入 Failed 状态', () async {
      final audioItem = _testAudioItem(audioSha256: 'abc123');

      when(
        () => mockFileOps.computeSha256(any()),
      ).thenAnswer((_) async => 'abc123');
      when(() => mockFileOps.getFileSize(any())).thenAnswer((_) async => 1024);

      when(
        () => mockApi.getUploadUrl(
          sha256: any(named: 'sha256'),
          mimeType: any(named: 'mimeType'),
          fileSize: any(named: 'fileSize'),
        ),
      ).thenAnswer((_) async => const UploadUrlResponse(audioExists: true));

      // 返回 cached=false 但无 jobId
      when(
        () => mockApi.submitTranscription(
          sha256: any(named: 'sha256'),
          objectName: any(named: 'objectName'),
          publicUrl: any(named: 'publicUrl'),
          mimeType: any(named: 'mimeType'),
          fileSize: any(named: 'fileSize'),
          language: any(named: 'language'),
        ),
      ).thenAnswer(
        (_) async => const SubmitTranscriptionResponse(cached: false),
      );

      final container = _createContainer(
        mockApi: mockApi,
        mockFileOps: mockFileOps,
        audioItems: [audioItem],
      );
      final notifier = container.read(
        transcriptionTaskManagerProvider.notifier,
      );

      await notifier.startTranscription(audioItem, 'en');

      final state = notifier.getTaskState('test-audio-1');
      expect(state, isA<TranscriptionFailed>());
      expect((state as TranscriptionFailed).message, 'server');

      container.dispose();
    });

    test('网络错误进入 Failed 状态', () async {
      final audioItem = _testAudioItem(audioSha256: 'abc123');

      when(
        () => mockFileOps.computeSha256(any()),
      ).thenAnswer((_) async => 'abc123');
      when(() => mockFileOps.getFileSize(any())).thenAnswer((_) async => 1024);

      when(
        () => mockApi.getUploadUrl(
          sha256: any(named: 'sha256'),
          mimeType: any(named: 'mimeType'),
          fileSize: any(named: 'fileSize'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.connectionError,
          message: 'Connection refused',
        ),
      );

      final container = _createContainer(
        mockApi: mockApi,
        mockFileOps: mockFileOps,
        audioItems: [audioItem],
      );
      final notifier = container.read(
        transcriptionTaskManagerProvider.notifier,
      );

      await notifier.startTranscription(audioItem, 'en');

      final state = notifier.getTaskState('test-audio-1');
      expect(state, isA<TranscriptionFailed>());
      expect((state as TranscriptionFailed).message, 'connection');

      container.dispose();
    });

    test('DioException cancel 类型不设置 Failed 状态', () async {
      final audioItem = _testAudioItem(audioSha256: 'abc123');

      when(
        () => mockFileOps.computeSha256(any()),
      ).thenAnswer((_) async => 'abc123');
      when(() => mockFileOps.getFileSize(any())).thenAnswer((_) async => 1024);

      when(
        () => mockApi.getUploadUrl(
          sha256: any(named: 'sha256'),
          mimeType: any(named: 'mimeType'),
          fileSize: any(named: 'fileSize'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.cancel,
        ),
      );

      final container = _createContainer(
        mockApi: mockApi,
        mockFileOps: mockFileOps,
        audioItems: [audioItem],
      );
      final notifier = container.read(
        transcriptionTaskManagerProvider.notifier,
      );

      await notifier.startTranscription(audioItem, 'en');

      // Cancel 不应设置 Failed，状态停留在最后一次 _updateState
      final state = notifier.getTaskState('test-audio-1');
      expect(state, isNot(isA<TranscriptionFailed>()));

      container.dispose();
    });

    test('轮询中 job 失败进入 Failed 状态', () async {
      final audioItem = _testAudioItem(audioSha256: 'abc123');

      when(
        () => mockFileOps.computeSha256(any()),
      ).thenAnswer((_) async => 'abc123');
      when(() => mockFileOps.getFileSize(any())).thenAnswer((_) async => 1024);

      when(
        () => mockApi.getUploadUrl(
          sha256: any(named: 'sha256'),
          mimeType: any(named: 'mimeType'),
          fileSize: any(named: 'fileSize'),
        ),
      ).thenAnswer((_) async => const UploadUrlResponse(audioExists: true));

      when(
        () => mockApi.submitTranscription(
          sha256: any(named: 'sha256'),
          objectName: any(named: 'objectName'),
          publicUrl: any(named: 'publicUrl'),
          mimeType: any(named: 'mimeType'),
          fileSize: any(named: 'fileSize'),
          language: any(named: 'language'),
        ),
      ).thenAnswer(
        (_) async =>
            const SubmitTranscriptionResponse(cached: false, jobId: 'job-fail'),
      );

      when(() => mockApi.getJobStatus('job-fail')).thenAnswer(
        (_) async => const JobStatusResponse(
          status: 'failed',
          errorMessage: 'Deepgram error: unsupported format',
        ),
      );

      final container = _createContainer(
        mockApi: mockApi,
        mockFileOps: mockFileOps,
        audioItems: [audioItem],
      );
      final notifier = container.read(
        transcriptionTaskManagerProvider.notifier,
      );

      await notifier.startTranscription(audioItem, 'en');

      final state = notifier.getTaskState('test-audio-1');
      expect(state, isA<TranscriptionFailed>());
      expect((state as TranscriptionFailed).message, 'server');

      container.dispose();
    });

    test('已有 SHA256 缓存时跳过计算', () async {
      final audioItem = _testAudioItem(audioSha256: 'cached-sha');

      when(() => mockFileOps.getFileSize(any())).thenAnswer((_) async => 1024);

      when(
        () => mockApi.getUploadUrl(
          sha256: any(named: 'sha256'),
          mimeType: any(named: 'mimeType'),
          fileSize: any(named: 'fileSize'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/test'),
          message: 'stop here',
        ),
      );

      final container = _createContainer(
        mockApi: mockApi,
        mockFileOps: mockFileOps,
        audioItems: [audioItem],
      );
      final notifier = container.read(
        transcriptionTaskManagerProvider.notifier,
      );

      await notifier.startTranscription(audioItem, 'en');

      // 不应调用 computeSha256
      verifyNever(() => mockFileOps.computeSha256(any()));

      container.dispose();
    });

    test('_getMimeType 正确映射文件扩展名', () {
      // 通过反射测试静态方法（用公开间接方式验证）
      // 验证 .m4a 文件不会硬编码为 audio/mpeg
      expect(
        TranscriptionTaskManager.getMimeTypeForTest('test.mp3'),
        'audio/mpeg',
      );
      expect(
        TranscriptionTaskManager.getMimeTypeForTest('test.m4a'),
        'audio/mp4',
      );
      expect(
        TranscriptionTaskManager.getMimeTypeForTest('test.wav'),
        'audio/wav',
      );
      expect(
        TranscriptionTaskManager.getMimeTypeForTest('test.flac'),
        'audio/flac',
      );
      expect(
        TranscriptionTaskManager.getMimeTypeForTest('test.ogg'),
        'audio/ogg',
      );
      expect(
        TranscriptionTaskManager.getMimeTypeForTest('TEST.MP3'),
        'audio/mpeg',
      );
      expect(
        TranscriptionTaskManager.getMimeTypeForTest('unknown.xyz'),
        'audio/mpeg',
      );
    });
  });
}
