import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/theme/app_theme.dart';

void main() {
  group('AppTheme.dark — 纯黑 / AMOLED', () {
    final dark = AppTheme.dark();

    test('页面背景为纯黑 #000000', () {
      expect(dark.scaffoldBackgroundColor, const Color(0xFF000000));
    });

    test('卡片为近黑 #0B0B0B（浮于纯黑底，非纯黑）', () {
      expect(dark.cardTheme.color, const Color(0xFF0B0B0B));
      expect(dark.cardTheme.color, isNot(const Color(0xFF000000)));
    });

    test('AppBar / 底部导航背景为纯黑', () {
      expect(dark.appBarTheme.backgroundColor, const Color(0xFF000000));
      expect(dark.navigationBarTheme.backgroundColor, const Color(0xFF000000));
    });

    test('surface 系列被覆盖为分级近黑', () {
      final cs = dark.colorScheme;
      expect(cs.surface, const Color(0xFF0B0B0B));
      expect(cs.surfaceContainerLowest, const Color(0xFF000000));
    });

    test('outlineVariant 保留种子派生灰，保证分割线在纯黑上可见', () {
      // 未被覆盖：分割线 (dividerTheme) 依赖该角色色，过暗会看不见
      expect(dark.colorScheme.outlineVariant, isNot(const Color(0xFF1F1F1F)));
      expect(dark.colorScheme.outlineVariant, isNot(const Color(0xFF000000)));
    });

    test('卡片描边使用独立近黑常量 #1F1F1F', () {
      final shape = dark.cardTheme.shape as RoundedRectangleBorder;
      expect(shape.side.color, const Color(0xFF1F1F1F));
    });

    test('primary 保留种子派生蓝，未被改成白色', () {
      expect(dark.colorScheme.primary, isNot(Colors.white));
      expect(dark.colorScheme.brightness, Brightness.dark);
    });
  });

  group('AppTheme.light — 回归保护', () {
    test('浅色页面背景保持浅灰，不受纯黑改造影响', () {
      expect(AppTheme.light().scaffoldBackgroundColor, const Color(0xFFF5F6FA));
    });
  });
}
