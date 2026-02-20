/// App 冒烟测试
///
/// 验证 App 能正常启动并显示首页。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:fluency/main.dart';

import 'helpers/test_app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    final packageInfo = PackageInfo(
      appName: 'Fluency',
      packageName: 'top.valuespot.fluency',
      version: '1.0.0',
      buildNumber: '1',
    );

    // 使用 createTestScreen 包装，提供 ProviderScope 和必要的 mock
    await tester.pumpWidget(
      createTestScreen(FluencyApp(packageInfo: packageInfo)),
    );
    await tester.pumpAndSettle();

    // 验证 App 正常加载
    expect(find.text('Audio Library'), findsOneWidget);
  });
}
