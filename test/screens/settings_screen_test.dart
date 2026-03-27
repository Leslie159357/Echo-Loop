/// SettingsScreen 测试
///
/// 测试设置页面的渲染和交互。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:fluency/providers/app_update_provider.dart';
import 'package:fluency/providers/developer_options_provider.dart';
import 'package:fluency/screens/settings_screen.dart';
import 'package:fluency/providers/settings_provider.dart';
import 'package:fluency/providers/audio_library_provider.dart';
import 'package:fluency/providers/collection_provider.dart';
import 'package:fluency/providers/listening_practice/listening_practice_provider.dart';
import 'package:fluency/providers/audio_engine/audio_engine_provider.dart';
import 'package:fluency/providers/package_info_provider.dart';

import '../helpers/mock_providers.dart';
import '../helpers/test_app.dart';

void main() {
  final testPackageInfo = PackageInfo(
    appName: 'Fluency',
    packageName: 'top.echo-loop',
    version: '1.0.0',
    buildNumber: '1',
  );

  List<Override> buildOverrides({
    AppSettingsState settings = const AppSettingsState(),
    bool showDeveloperOptions = true,
  }) {
    return [
      appSettingsProvider.overrideWith(() => TestAppSettings(settings)),
      showDeveloperOptionsProvider.overrideWith(
        () => _TestDeveloperOptions(showDeveloperOptions),
      ),
      audioLibraryProvider.overrideWith(() => TestAudioLibrary()),
      collectionListProvider.overrideWith(() => TestCollectionList()),
      listeningPracticeProvider.overrideWith(() => TestListeningPractice()),
      audioEngineProvider.overrideWith(() => TestAudioEngine()),
      packageInfoProvider.overrideWithValue(testPackageInfo),
      appUpdateProvider.overrideWith(() => TestAppUpdate()),
      analyticsOverride(),
    ];
  }

  group('SettingsScreen', () {
    group('渲染', () {
      testWidgets('显示主题设置项', (tester) async {
        await tester.pumpWidget(
          createTestScreen(const SettingsScreen(), overrides: buildOverrides()),
        );
        await tester.pumpAndSettle();

        expect(find.text('Theme Mode'), findsOneWidget);
        // 默认 system 模式
        expect(find.text('Follow System'), findsOneWidget);
      });

      testWidgets('显示语言设置项', (tester) async {
        await tester.pumpWidget(
          createTestScreen(const SettingsScreen(), overrides: buildOverrides()),
        );
        await tester.pumpAndSettle();

        expect(find.text('Language'), findsOneWidget);
        // 默认英文
        expect(find.text('English'), findsOneWidget);
      });

      testWidgets('显示关于信息区域', (tester) async {
        await tester.pumpWidget(
          createTestScreen(const SettingsScreen(), overrides: buildOverrides()),
        );
        await tester.pumpAndSettle();

        expect(find.text('About'), findsOneWidget);
        expect(find.text('Terms of Service'), findsOneWidget);
        expect(find.text('Privacy Policy'), findsOneWidget);
        expect(find.text('Write Feedback'), findsOneWidget);
        expect(find.text('v1.0.0'), findsOneWidget);
      });

      testWidgets('显示外观标题', (tester) async {
        await tester.pumpWidget(
          createTestScreen(const SettingsScreen(), overrides: buildOverrides()),
        );
        await tester.pumpAndSettle();

        expect(find.text('Appearance'), findsOneWidget);
      });
      testWidgets('开发者选项关闭时不显示开发者分组', (tester) async {
        await tester.pumpWidget(
          createTestScreen(
            const SettingsScreen(),
            overrides: buildOverrides(showDeveloperOptions: false),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Developer'), findsNothing);
        expect(find.text('Time Machine'), findsNothing);
      });

      testWidgets('开发者选项开启且未设置时时显示系统时间文案', (tester) async {
        await tester.pumpWidget(
          createTestScreen(const SettingsScreen(), overrides: buildOverrides()),
        );
        await tester.pumpAndSettle();

        // 滚动到开发者区域
        await tester.scrollUntilVisible(find.text('Time Machine'), 200);
        await tester.pumpAndSettle();

        expect(find.text('Developer'), findsOneWidget);
        expect(find.text('Time Machine'), findsOneWidget);
        expect(find.text('Using system time'), findsOneWidget);
      });

      testWidgets('开发者选项开启且已设置时时显示当前调试时间', (tester) async {
        await tester.pumpWidget(
          createTestScreen(
            const SettingsScreen(),
            overrides: buildOverrides(
              settings: AppSettingsState(
                timeMachineDateTime: DateTime(2026, 3, 11, 22, 15),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 滚动到开发者区域
        await tester.scrollUntilVisible(find.text('Time Machine'), 200);
        await tester.pumpAndSettle();

        expect(find.text('Debug time: 2026-03-11 22:15'), findsOneWidget);
      });
    });

    group('交互', () {
      testWidgets('点击主题设置弹出选择对话框', (tester) async {
        await tester.pumpWidget(
          createTestScreen(const SettingsScreen(), overrides: buildOverrides()),
        );
        await tester.pumpAndSettle();

        // 点击主题设置项
        await tester.tap(find.text('Theme Mode'));
        await tester.pumpAndSettle();

        // 应弹出对话框，显示三个选项
        expect(find.text('Light Mode'), findsOneWidget);
        expect(find.text('Dark Mode'), findsOneWidget);
        // 对话框标题 + 列表中的 Follow System
        expect(find.text('Follow System'), findsAtLeast(1));
      });

      testWidgets('选择 Dark 主题后状态更新', (tester) async {
        await tester.pumpWidget(
          createTestScreen(const SettingsScreen(), overrides: buildOverrides()),
        );
        await tester.pumpAndSettle();

        // 打开主题选择对话框
        await tester.tap(find.text('Theme Mode'));
        await tester.pumpAndSettle();

        // 选择 Dark Mode
        await tester.tap(find.text('Dark Mode'));
        await tester.pumpAndSettle();

        // 对话框关闭后，应显示 Dark Mode
        expect(find.text('Dark Mode'), findsOneWidget);
      });

      testWidgets('点击语言设置弹出选择对话框', (tester) async {
        await tester.pumpWidget(
          createTestScreen(const SettingsScreen(), overrides: buildOverrides()),
        );
        await tester.pumpAndSettle();

        // 点击语言设置项
        await tester.tap(find.text('Language'));
        await tester.pumpAndSettle();

        // 应弹出对话框，显示两个选项
        expect(find.text('English'), findsAtLeast(1));
        expect(find.text('简体中文'), findsOneWidget);
      });

      testWidgets('点击时光机弹出设置对话框', (tester) async {
        await tester.pumpWidget(
          createTestScreen(const SettingsScreen(), overrides: buildOverrides()),
        );
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.text('Time Machine'),
          200,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Time Machine'));
        await tester.pumpAndSettle();

        expect(find.text('Select date'), findsOneWidget);
        expect(find.text('Select time'), findsOneWidget);
        expect(find.text('Save'), findsOneWidget);
      });

      testWidgets('点击恢复系统时间并保存后清除时光机', (tester) async {
        await tester.pumpWidget(
          createTestScreen(
            const SettingsScreen(),
            overrides: buildOverrides(
              settings: AppSettingsState(
                timeMachineDateTime: DateTime(2026, 3, 11, 22, 15),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.text('Time Machine'),
          200,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Time Machine'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Use system time'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        expect(find.text('Using system time'), findsOneWidget);
        expect(find.text('Debug time: 2026-03-11 22:15'), findsNothing);
      });
    });
  });
}

/// 测试用 DeveloperOptions Notifier，固定返回指定值。
class _TestDeveloperOptions extends DeveloperOptions {
  final bool _value;
  _TestDeveloperOptions(this._value);

  @override
  bool build() => _value;

  @override
  Future<void> setEnabled(bool value) async {
    state = value;
  }
}
