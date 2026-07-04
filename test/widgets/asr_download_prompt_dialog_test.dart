import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echo_loop/database/enums.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/providers/offline_asr_settings_provider.dart';
import 'package:echo_loop/services/asr/asr_model_manager.dart';
import 'package:echo_loop/services/download/download_failure.dart';
import 'package:echo_loop/widgets/asr_download_prompt_dialog.dart';

import '../helpers/mock_providers.dart';

class _TestOfflineAsrSettingsNotifier extends OfflineAsrSettingsNotifier {
  _TestOfflineAsrSettingsNotifier(this._initialState);

  final OfflineAsrSettingsState _initialState;

  int enableCallCount = 0;
  int disableCallCount = 0;
  int retryDownloadCallCount = 0;
  int loadEngineCallCount = 0;

  @override
  OfflineAsrSettingsState build() => _initialState;

  @override
  Future<void> enable() async {
    enableCallCount += 1;
    state = state.copyWith(
      enabled: true,
      downloadStatus: AsrModelDownloadStatus.downloading,
      downloadProgress: 0.4,
    );
    Future.microtask(() {
      state = state.copyWith(
        enabled: true,
        downloadStatus: AsrModelDownloadStatus.downloaded,
        downloadProgress: 1.0,
        engineReady: true,
      );
    });
  }

  @override
  Future<void> disable() async {
    disableCallCount += 1;
    state = state.copyWith(enabled: false, engineReady: false);
  }

  @override
  Future<void> retryDownload([String? modelId]) async {
    retryDownloadCallCount += 1;
    state = state.copyWith(
      enabled: true,
      downloadStatus: AsrModelDownloadStatus.downloading,
      downloadProgress: 0.6,
      clearError: true,
    );
    Future.microtask(() {
      state = state.copyWith(
        enabled: true,
        downloadStatus: AsrModelDownloadStatus.downloaded,
        downloadProgress: 1.0,
        engineReady: true,
      );
    });
  }

  @override
  Future<void> loadEngine() async {
    loadEngineCallCount += 1;
    state = state.copyWith(engineReady: true);
  }
}

void main() {
  const recommendedModel = AsrModelInfo(
    id: 'moonshine-tiny',
    displayName: 'Moonshine Tiny',
    type: AsrModelType.moonshine,
  );

  Widget createTestWidget({required _TestOfflineAsrSettingsNotifier notifier}) {
    return ProviderScope(
      overrides: [
        analyticsOverride(),
        offlineAsrSettingsProvider.overrideWith(() => notifier),
      ],
      child: MaterialApp(
        supportedLocales: const [Locale('en'), Locale('zh')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => Center(
              child: FilledButton(
                onPressed: () async {
                  final allowed = await ensureAsrReadyBeforeSpeechPractice(
                    context,
                    ref,
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('allowed=$allowed')));
                },
                child: const Text('start'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('ensureAsrReadyBeforeSpeechPractice', () {
    test('只在录音子阶段要求本地 ASR', () {
      expect(
        requiresAsrBeforeEnteringSubStage(SubStageType.blindListen),
        isFalse,
      );
      expect(
        requiresAsrBeforeEnteringSubStage(SubStageType.intensiveListen),
        isFalse,
      );
      expect(
        requiresAsrBeforeEnteringSubStage(SubStageType.listenAndRepeat),
        isTrue,
      );
      expect(requiresAsrBeforeEnteringSubStage(SubStageType.retell), isTrue);
      expect(
        requiresAsrBeforeEnteringSubStage(SubStageType.reviewDifficultPractice),
        isTrue,
      );
      expect(
        requiresAsrBeforeEnteringSubStage(SubStageType.reviewRetellParagraph),
        isTrue,
      );
      expect(
        requiresAsrBeforeEnteringSubStage(SubStageType.reviewRetellSummary),
        isTrue,
      );
      expect(
        requiresAsrBeforeEnteringSubStage(
          SubStageType.listenAndRepeat,
          listenAndRepeatRatingEnabled: false,
        ),
        isFalse,
      );
      expect(
        requiresAsrBeforeEnteringSubStage(
          SubStageType.retell,
          retellRatingEnabled: false,
        ),
        isFalse,
      );
    });

    testWidgets('默认开启但未下载时点空白关闭后返回 false 且不改状态', (tester) async {
      final notifier = _TestOfflineAsrSettingsNotifier(
        OfflineAsrSettingsState(
          backend: AsrBackend.offline,
          recommendedModel: recommendedModel,
        ),
      );

      await tester.pumpWidget(createTestWidget(notifier: notifier));
      await tester.tap(find.text('start'));
      await tester.pumpAndSettle();

      expect(find.text('Speech Recognition Model Required'), findsOneWidget);

      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();

      expect(find.text('allowed=false'), findsOneWidget);
      expect(notifier.enableCallCount, 0);
      expect(notifier.disableCallCount, 0);
      expect(notifier.state.enabled, isTrue);
    });

    testWidgets('默认开启但未下载时点右上角关闭后返回 false 且不改状态', (tester) async {
      final notifier = _TestOfflineAsrSettingsNotifier(
        OfflineAsrSettingsState(
          backend: AsrBackend.offline,
          recommendedModel: recommendedModel,
        ),
      );

      await tester.pumpWidget(createTestWidget(notifier: notifier));
      await tester.tap(find.text('start'));
      await tester.pumpAndSettle();

      expect(find.text('Speech Recognition Model Required'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('allowed=false'), findsOneWidget);
      expect(notifier.enableCallCount, 0);
      expect(notifier.disableCallCount, 0);
      expect(notifier.state.enabled, isTrue);
    });

    testWidgets('默认开启但未下载时点空白关闭后返回 false 且不改状态', (tester) async {
      final notifier = _TestOfflineAsrSettingsNotifier(
        OfflineAsrSettingsState(
          backend: AsrBackend.offline,
          recommendedModel: recommendedModel,
        ),
      );

      await tester.pumpWidget(createTestWidget(notifier: notifier));
      await tester.tap(find.text('start'));
      await tester.pumpAndSettle();

      expect(find.text('Speech Recognition Model Required'), findsOneWidget);

      // 点击空白区域关闭对话框（"Download Now" 是唯一按钮，没有 "Not Now"）
      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();

      expect(find.text('allowed=false'), findsOneWidget);
      expect(notifier.enableCallCount, 0);
      expect(notifier.disableCallCount, 0);
      expect(notifier.state.enabled, isTrue);
    });

    testWidgets('默认开启但未下载时下载成功后返回 true 并后台加载引擎', (tester) async {
      final notifier = _TestOfflineAsrSettingsNotifier(
        OfflineAsrSettingsState(
          backend: AsrBackend.offline,
          recommendedModel: recommendedModel,
        ),
      );

      await tester.pumpWidget(createTestWidget(notifier: notifier));
      await tester.tap(find.text('start'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Download Now'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('allowed=true'), findsOneWidget);
      expect(notifier.enableCallCount, 1);
      expect(notifier.loadEngineCallCount, 0);
    });

    testWidgets('已下载但引擎未就绪时会先加载引擎再放行', (tester) async {
      final notifier = _TestOfflineAsrSettingsNotifier(
        OfflineAsrSettingsState(
          backend: AsrBackend.offline,
          enabled: true,
          downloadStatus: AsrModelDownloadStatus.downloaded,
          engineReady: false,
          recommendedModel: recommendedModel,
        ),
      );

      await tester.pumpWidget(createTestWidget(notifier: notifier));
      await tester.tap(find.text('start'));
      await tester.pumpAndSettle();

      expect(find.text('allowed=true'), findsOneWidget);
      expect(notifier.loadEngineCallCount, 1);
    });

    testWidgets('已在下载中时只显示等待进度且可关闭', (tester) async {
      final notifier = _TestOfflineAsrSettingsNotifier(
        OfflineAsrSettingsState(
          backend: AsrBackend.offline,
          enabled: true,
          downloadStatus: AsrModelDownloadStatus.downloading,
          downloadProgress: 0.45,
          recommendedModel: recommendedModel,
        ),
      );

      await tester.pumpWidget(createTestWidget(notifier: notifier));
      await tester.tap(find.text('start'));
      await tester.pumpAndSettle();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('Download Now'), findsNothing);
      expect(find.text('Not Now'), findsNothing);
      expect(find.byIcon(Icons.close), findsOneWidget);

      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();

      expect(find.text('allowed=false'), findsOneWidget);
      expect(notifier.enableCallCount, 0);
      expect(notifier.disableCallCount, 0);
    });

    testWidgets('已启用但下载失败时点空白关闭返回 false', (tester) async {
      final notifier = _TestOfflineAsrSettingsNotifier(
        OfflineAsrSettingsState(
          backend: AsrBackend.offline,
          enabled: true,
          downloadStatus: AsrModelDownloadStatus.failed,
          downloadError: DownloadFailureKind.unknown,
          recommendedModel: recommendedModel,
        ),
      );

      await tester.pumpWidget(createTestWidget(notifier: notifier));
      await tester.tap(find.text('start'));
      await tester.pumpAndSettle();

      expect(find.text('Download failed. Tap to retry.'), findsOneWidget);

      // 点击空白区域关闭对话框（"Retry" 是唯一按钮，没有 "Not Now"）
      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();

      expect(find.text('allowed=false'), findsOneWidget);
      expect(notifier.retryDownloadCallCount, 0);
      expect(notifier.disableCallCount, 0);
    });

    testWidgets('已启用但下载失败时重试成功后返回 true', (tester) async {
      final notifier = _TestOfflineAsrSettingsNotifier(
        OfflineAsrSettingsState(
          backend: AsrBackend.offline,
          enabled: true,
          downloadStatus: AsrModelDownloadStatus.failed,
          downloadError: DownloadFailureKind.unknown,
          recommendedModel: recommendedModel,
        ),
      );

      await tester.pumpWidget(createTestWidget(notifier: notifier));
      await tester.tap(find.text('start'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('allowed=true'), findsOneWidget);
      expect(notifier.enableCallCount, 1);
    });

    testWidgets('下载失败弹窗点空白后返回 false 且不改状态', (tester) async {
      final notifier = _TestOfflineAsrSettingsNotifier(
        OfflineAsrSettingsState(
          backend: AsrBackend.offline,
          enabled: true,
          downloadStatus: AsrModelDownloadStatus.failed,
          downloadError: DownloadFailureKind.unknown,
          recommendedModel: recommendedModel,
        ),
      );

      await tester.pumpWidget(createTestWidget(notifier: notifier));
      await tester.tap(find.text('start'));
      await tester.pumpAndSettle();

      expect(find.text('Download failed. Tap to retry.'), findsOneWidget);

      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();

      expect(find.text('allowed=false'), findsOneWidget);
      expect(notifier.retryDownloadCallCount, 0);
      expect(notifier.disableCallCount, 0);
      expect(notifier.state.enabled, isTrue);
    });

    testWidgets('下载失败弹窗点右上角关闭后返回 false 且不改状态', (tester) async {
      final notifier = _TestOfflineAsrSettingsNotifier(
        OfflineAsrSettingsState(
          backend: AsrBackend.offline,
          enabled: true,
          downloadStatus: AsrModelDownloadStatus.failed,
          downloadError: DownloadFailureKind.unknown,
          recommendedModel: recommendedModel,
        ),
      );

      await tester.pumpWidget(createTestWidget(notifier: notifier));
      await tester.tap(find.text('start'));
      await tester.pumpAndSettle();

      expect(find.text('Download failed. Tap to retry.'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('allowed=false'), findsOneWidget);
      expect(notifier.retryDownloadCallCount, 0);
      expect(notifier.disableCallCount, 0);
      expect(notifier.state.enabled, isTrue);
    });

    testWidgets('平台后端不需要 Whisper 模型并直接放行', (tester) async {
      final notifier = _TestOfflineAsrSettingsNotifier(
        OfflineAsrSettingsState(
          backend: AsrBackend.platform,
          recommendedModel: recommendedModel,
        ),
      );

      await tester.pumpWidget(createTestWidget(notifier: notifier));
      await tester.tap(find.text('start'));
      await tester.pumpAndSettle();

      expect(find.text('Speech Recognition Required'), findsNothing);
      expect(find.text('allowed=true'), findsOneWidget);
      expect(notifier.enableCallCount, 0);
      expect(notifier.disableCallCount, 0);
    });
  });
}
