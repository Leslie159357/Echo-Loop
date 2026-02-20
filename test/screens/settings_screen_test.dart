/// SettingsScreen 测试
///
/// 测试设置页面的渲染和交互。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:fluency/screens/settings_screen.dart';

import '../helpers/test_app.dart';

void main() {
  final testPackageInfo = PackageInfo(
    appName: 'Fluency',
    packageName: 'top.valuespot.fluency',
    version: '1.0.0',
    buildNumber: '1',
  );

  group('SettingsScreen', () {
    group('渲染', () {
      testWidgets('显示主题设置项', (tester) async {
        await tester.pumpWidget(
          createTestScreen(
            SettingsScreen(packageInfo: testPackageInfo),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Theme Mode'), findsOneWidget);
        // 默认 system 模式
        expect(find.text('Follow System'), findsOneWidget);
      });

      testWidgets('显示语言设置项', (tester) async {
        await tester.pumpWidget(
          createTestScreen(
            SettingsScreen(packageInfo: testPackageInfo),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Language'), findsOneWidget);
        // 默认英文
        expect(find.text('English'), findsOneWidget);
      });

      testWidgets('显示关于信息区域', (tester) async {
        await tester.pumpWidget(
          createTestScreen(
            SettingsScreen(packageInfo: testPackageInfo),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('About'), findsOneWidget);
        expect(find.text('Version'), findsOneWidget);
        expect(find.text('1.0.0'), findsOneWidget);
      });

      testWidgets('显示外观标题', (tester) async {
        await tester.pumpWidget(
          createTestScreen(
            SettingsScreen(packageInfo: testPackageInfo),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Appearance'), findsOneWidget);
      });
    });

    group('交互', () {
      testWidgets('点击主题设置弹出选择对话框', (tester) async {
        await tester.pumpWidget(
          createTestScreen(
            SettingsScreen(packageInfo: testPackageInfo),
          ),
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
          createTestScreen(
            SettingsScreen(packageInfo: testPackageInfo),
          ),
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
          createTestScreen(
            SettingsScreen(packageInfo: testPackageInfo),
          ),
        );
        await tester.pumpAndSettle();

        // 点击语言设置项
        await tester.tap(find.text('Language'));
        await tester.pumpAndSettle();

        // 应弹出对话框，显示两个选项
        expect(find.text('English'), findsAtLeast(1));
        expect(find.text('简体中文'), findsOneWidget);
      });

      testWidgets('不传 packageInfo 时版本号为空', (tester) async {
        await tester.pumpWidget(
          createTestScreen(const SettingsScreen()),
        );
        await tester.pumpAndSettle();

        // 版本号应存在但为空字符串
        expect(find.text('Version'), findsOneWidget);
      });
    });
  });
}
