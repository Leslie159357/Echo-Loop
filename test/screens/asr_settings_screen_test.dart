import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/providers/offline_asr_settings_provider.dart';
import 'package:echo_loop/screens/asr_settings_screen.dart';
import 'package:echo_loop/services/asr/asr_model_manager.dart';
import 'package:echo_loop/services/asr/offline_asr_engine.dart';
import 'package:echo_loop/theme/app_theme.dart';

class _StaticOfflineAsrSettingsNotifier extends OfflineAsrSettingsNotifier {
  _StaticOfflineAsrSettingsNotifier(this._initialState);

  final OfflineAsrSettingsState _initialState;

  @override
  OfflineAsrSettingsState build() => _initialState;

  @override
  Future<void> retryDownload() async {}
}

Widget _buildTestWidget(_StaticOfflineAsrSettingsNotifier notifier) {
  return ProviderScope(
    overrides: [offlineAsrSettingsProvider.overrideWith(() => notifier)],
    child: MaterialApp(
      supportedLocales: const [Locale('en'), Locale('zh')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light(),
      home: const AsrSettingsScreen(),
    ),
  );
}

void main() {
  const recommendedModel = AsrModelInfo(
    id: 'whisper-base-en-int8',
    displayName: 'Whisper Base.en',
    type: AsrModelType.whisper,
  );

  testWidgets('残缺模型显示失败状态和模型档位', (tester) async {
    final notifier = _StaticOfflineAsrSettingsNotifier(
      OfflineAsrSettingsState(
        enabled: true,
        backend: AsrBackend.offline,
        downloadStatus: AsrModelDownloadStatus.failed,
        localSizeBytes: 153 * 1024 * 1024,
        recommendedModel: recommendedModel,
      ),
    );

    await tester.pumpWidget(_buildTestWidget(notifier));
    await tester.pumpAndSettle();

    // 显示模型档位名称
    expect(find.textContaining('Balanced'), findsAny);
    // 不显示 Ready（下载失败）
    expect(find.textContaining('Ready'), findsNothing);
  });

  testWidgets('关闭状态下隐藏后端选择和模型信息', (tester) async {
    final notifier = _StaticOfflineAsrSettingsNotifier(
      OfflineAsrSettingsState(
        enabled: false,
        backend: AsrBackend.offline,
        localSizeBytes: 153 * 1024 * 1024,
        recommendedModel: recommendedModel,
      ),
    );

    await tester.pumpWidget(_buildTestWidget(notifier));
    await tester.pumpAndSettle();

    // 开关显示 Disabled
    expect(find.text('Disabled'), findsOneWidget);
    // 不显示模型档位（关闭时隐藏）
    expect(find.textContaining('Balanced'), findsNothing);
    // 不显示删除按钮（已移除）
    expect(find.text('Delete Model'), findsNothing);
  });

  testWidgets('已下载模型显示 Ready 和大小', (tester) async {
    final notifier = _StaticOfflineAsrSettingsNotifier(
      OfflineAsrSettingsState(
        enabled: true,
        backend: AsrBackend.offline,
        downloadStatus: AsrModelDownloadStatus.downloaded,
        localSizeBytes: 153 * 1024 * 1024,
        recommendedModel: recommendedModel,
      ),
    );

    await tester.pumpWidget(_buildTestWidget(notifier));
    await tester.pumpAndSettle();

    expect(find.textContaining('Balanced'), findsAny);
    expect(find.textContaining('Ready'), findsAny);
    expect(find.textContaining('153 MB'), findsAny);
  });
}
