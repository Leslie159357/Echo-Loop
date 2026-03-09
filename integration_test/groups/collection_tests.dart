/// 合集管理集成测试
///
/// 验证合集的创建、显示等管理流程。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_notifiers.dart';

/// 合集管理相关集成测试
void collectionTests() {
  group('流程 3：合集管理', () {
    testWidgets('创建合集并验证出现在列表中', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // 切换到资源库页（限定在底部导航内，避免点到页面内容区同名图标）
      final railLibraryIcon = find.descendant(
        of: find.byType(NavigationRail),
        matching: find.byIcon(Icons.library_music_outlined),
      );
      final barLibraryIcon = find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byIcon(Icons.library_music_outlined),
      );
      if (railLibraryIcon.evaluate().isNotEmpty) {
        await tester.tap(railLibraryIcon.first);
      } else {
        await tester.tap(barLibraryIcon.first);
      }
      await tester.pumpAndSettle();

      // 点击 AppBar 中的创建按钮（避免误点内容区 add 图标）
      final appBarAdd = find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.add),
      );
      await tester.tap(appBarAdd.first);
      await tester.pumpAndSettle();

      // 输入合集名称
      await tester.enterText(find.byType(TextField), 'My Collection');
      await tester.pumpAndSettle();

      // 点击添加
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      // 合集应出现在列表中
      expect(find.text('My Collection'), findsOneWidget);
    });
  });
}
