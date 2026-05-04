import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/models/app_update_info.dart';
import 'package:echo_loop/widgets/app_update_dialog.dart';

void main() {
  const info = AppUpdateInfo(
    latestVersion: '2.0.0',
    minimumVersion: '1.5.0',
    releaseNotes: {'en': 'New features!', 'zh': '新功能！'},
    downloadUrl: {'fallback': 'https://example.com/download'},
  );

  Widget buildApp({required Widget child}) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: child,
    );
  }

  group('Soft update 对话框', () {
    testWidgets('显示版本号和更新说明', (tester) async {
      await tester.pumpWidget(buildApp(
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showAppUpdateDialog(
              context: context,
              info: info,
              isForceUpdate: false,
              downloadUrl: 'https://example.com/download',
            ),
            child: const Text('Show'),
          ),
        ),
      ));

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      expect(find.textContaining('2.0.0'), findsOneWidget);
      expect(find.text('New features!'), findsOneWidget);
      expect(find.text('Later'), findsOneWidget);
      expect(find.text('Update Now'), findsOneWidget);
    });

    testWidgets('点击稍后调用 onDismiss', (tester) async {
      var dismissed = false;

      await tester.pumpWidget(buildApp(
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showAppUpdateDialog(
              context: context,
              info: info,
              isForceUpdate: false,
              downloadUrl: 'https://example.com',
              onDismiss: () => dismissed = true,
            ),
            child: const Text('Show'),
          ),
        ),
      ));

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();

      expect(dismissed, isTrue);
    });
  });

  group('Force update 对话框', () {
    testWidgets('不显示稍后按钮，显示复制链接', (tester) async {
      await tester.pumpWidget(buildApp(
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showAppUpdateDialog(
              context: context,
              info: info,
              isForceUpdate: true,
              downloadUrl: 'https://example.com/download',
            ),
            child: const Text('Show'),
          ),
        ),
      ));

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      expect(find.text('Update Required'), findsOneWidget);
      expect(find.text('Later'), findsNothing);
      expect(find.text('Copy Download Link'), findsOneWidget);
      expect(find.text('Update Now'), findsOneWidget);
    });

    testWidgets('不可通过返回键关闭', (tester) async {
      await tester.pumpWidget(buildApp(
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showAppUpdateDialog(
              context: context,
              info: info,
              isForceUpdate: true,
              downloadUrl: 'https://example.com',
            ),
            child: const Text('Show'),
          ),
        ),
      ));

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      // 尝试通过返回键关闭
      final dynamic widgetsBinding =
          tester.binding;
      await widgetsBinding.handlePopRoute();
      await tester.pumpAndSettle();

      // 对话框仍然存在
      expect(find.text('Update Required'), findsOneWidget);
    });
  });
}
