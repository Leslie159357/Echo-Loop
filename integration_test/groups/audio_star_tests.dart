/// 音频星标集成测试
///
/// 验证音频列表中星标按钮的交互：点击切换、图标变化、leading 图标高亮。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluency/theme/app_theme.dart';

import '../helpers/test_notifiers.dart';

/// 音频星标相关集成测试
void audioStarTests() {
  group('流程 8：音频星标', () {
    testWidgets('在音频列表中切换星标状态', (tester) async {
      await tester.pumpWidget(createTestAppWithAudio());
      await tester.pumpAndSettle();

      // 导航到资源库页
      await tester.tap(find.byIcon(Icons.library_music_outlined));
      await tester.pumpAndSettle();

      // 切换到音频 Tab
      await tester.tap(find.text('Audio'));
      await tester.pumpAndSettle();

      // 验证音频项存在
      expect(find.text('Test Audio'), findsOneWidget);

      // 初始状态：star_border 灰色图标
      expect(find.byIcon(Icons.star_border), findsOneWidget);
      expect(find.byIcon(Icons.star), findsNothing);

      // 点击星标按钮
      await tester.tap(find.byIcon(Icons.star_border));
      await tester.pumpAndSettle();

      // 验证星标已切换为实心星
      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(find.byIcon(Icons.star_border), findsNothing);

      // 验证实心星使用 bookmarkColor
      final starIcon = tester.widget<Icon>(find.byIcon(Icons.star));
      expect(starIcon.color, AppTheme.bookmarkColor);

      // 再次点击取消星标
      await tester.tap(find.byIcon(Icons.star));
      await tester.pumpAndSettle();

      // 验证恢复为空心星
      expect(find.byIcon(Icons.star_border), findsOneWidget);
      expect(find.byIcon(Icons.star), findsNothing);
    });
  });
}
