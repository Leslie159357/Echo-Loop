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

      // 切换到资源库页（通过底部导航图标，用 last 避免匹配学习页空状态图标）
      await tester.tap(find.byIcon(Icons.library_music_outlined).last);
      await tester.pumpAndSettle();

      // 初始为空状态
      expect(find.text('No collections yet'), findsOneWidget);

      // 点击 AppBar 中的创建按钮（空状态 CTA 中也有 add 图标）
      await tester.tap(find.byIcon(Icons.add).first);
      await tester.pumpAndSettle();

      // 输入合集名称
      await tester.enterText(find.byType(TextField), 'My Collection');
      await tester.pumpAndSettle();

      // 点击添加
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      // 合集应出现在列表中
      expect(find.text('My Collection'), findsOneWidget);
      // 空状态应消失
      expect(find.text('No collections yet'), findsNothing);
    });
  });
}
