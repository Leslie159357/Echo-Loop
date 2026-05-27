/// 应用主题系统
///
/// 集中定义所有视觉规范：配色方案、组件主题、间距常量、语义色、文字样式辅助。
/// 参考 Learna AI 风格：干净现代 + 彩色点缀，浅灰背景 + 白色卡片浮起。
/// 种子色 `#1976D2`（明亮蓝），专业清爽。
library;

import 'package:flutter/material.dart';

/// 应用主题配置
class AppTheme {
  AppTheme._();

  /// 种子色：明亮蓝
  static const Color seedColor = Color(0xFF1976D2);

  /// 浅灰页面背景色
  static const Color _scaffoldBg = Color(0xFFF5F6FA);

  /// 纯黑色板（深色主题专用，AMOLED 省电 + 沉浸式）
  ///
  /// 分层策略：页面背景纯黑，卡片/AppBar/底栏近黑浮起，浮层逐级提亮，
  /// 既得纯黑效果又保留 M3 elevation 层次，避免大面积纯黑糊成一片。
  static const Color _pureBlack = Color(0xFF000000); // 页面背景
  static const Color _surfaceBlack = Color(0xFF0B0B0B); // 卡片 / AppBar / 底栏
  static const Color _surfaceBorder = Color(0xFF1F1F1F); // 卡片描边

  /// 导航栏选中态颜色：明亮蓝
  static const Color navActiveColor = Color(0xFF3AA0FF);

  /// 语义色：书签/收藏/星标
  static const Color bookmarkColor = Colors.amber;

  /// 语义色：置顶图钉
  static const Color pinColor = Color(0xFFE53935);

  /// 语义色：官方合集角标（深橙金色，对应"认证/精选"的通用视觉）
  /// 选 Material Orange 800：白字对比足够，区别于品牌蓝、不会与封面同色系混淆
  static const Color officialBadgeColor = Color(0xFFEF6C00);

  /// 亮色主题
  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
      surface: Colors.white,
      surfaceContainerLowest: _scaffoldBg,
    );
    return _buildTheme(colorScheme, Brightness.light);
  }

  /// 暗色主题（纯黑 / AMOLED）
  ///
  /// 保留 `fromSeed` 派生的完整角色色（primary/secondary/container 等），
  /// 仅用 `copyWith` 把 surface 系列覆盖为分级近黑，确保品牌蓝等不丢失。
  static ThemeData dark() {
    final base = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
    );
    final colorScheme = base.copyWith(
      surface: _surfaceBlack,
      surfaceContainerLowest: _pureBlack,
      surfaceContainerLow: _surfaceBlack,
      surfaceContainer: const Color(0xFF101010),
      surfaceContainerHigh: const Color(0xFF161616),
      surfaceContainerHighest: const Color(0xFF1C1C1C),
    );
    return _buildTheme(colorScheme, Brightness.dark);
  }

  /// 根据 ColorScheme 构建完整主题
  static ThemeData _buildTheme(ColorScheme colorScheme, Brightness brightness) {
    final isLight = brightness == Brightness.light;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: isLight ? _scaffoldBg : _pureBlack,

      // Card 主题：
      // - 浅色：去边框 + 微弱阴影，白色浮于灰底
      // - 深色（纯黑）：阴影在纯黑上不可见，改用 1px 近黑描边区分卡片边界
      cardTheme: CardThemeData(
        elevation: isLight ? 1 : 0,
        shadowColor: isLight ? Colors.black.withValues(alpha: 0.08) : null,
        color: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isLight
              ? BorderSide.none
              : BorderSide(color: _surfaceBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      // 全局禁用 Tooltip（长按提示）
      tooltipTheme: const TooltipThemeData(
        padding: EdgeInsets.zero,
        margin: EdgeInsets.zero,
        constraints: BoxConstraints(maxHeight: 0, maxWidth: 0),
        textStyle: TextStyle(fontSize: 0),
        decoration: BoxDecoration(color: Colors.transparent),
        waitDuration: Duration(days: 1),
      ),

      // AppBar 主题：与页面背景一致，标题加粗
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        backgroundColor: isLight ? _scaffoldBg : _pureBlack,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: colorScheme.onSurface,
        ),
      ),

      // 底部导航栏主题：白色底栏，选中态 #3AA0FF 蓝色图标和标签，无背景指示器
      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        backgroundColor: isLight ? Colors.white : _pureBlack,
        indicatorColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: navActiveColor);
          }
          return IconThemeData(color: colorScheme.onSurfaceVariant);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: navActiveColor,
            );
          }
          return TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant);
        }),
      ),

      // 侧边导航栏主题：白色侧栏，选中态 #3AA0FF 蓝色图标和标签，无背景指示器
      navigationRailTheme: NavigationRailThemeData(
        indicatorColor: Colors.transparent,
        backgroundColor: isLight ? Colors.white : _pureBlack,
        selectedIconTheme: const IconThemeData(color: navActiveColor),
        unselectedIconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
        selectedLabelTextStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: navActiveColor,
        ),
        unselectedLabelTextStyle: TextStyle(
          fontSize: 12,
          color: colorScheme.onSurfaceVariant,
        ),
      ),

      // 输入框主题：圆角 12
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        isDense: true,
      ),

      // 对话框主题：圆角 20
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      // 列表项主题：圆角 + 宽松间距
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      // 图标主题
      iconTheme: IconThemeData(size: 24, color: colorScheme.onSurfaceVariant),

      // TabBar 主题
      tabBarTheme: TabBarThemeData(
        indicatorColor: colorScheme.primary,
        labelColor: colorScheme.primary,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
      ),

      // SnackBar 主题：圆角 12
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      // ElevatedButton 主题：圆角 16 + 加粗文字 + 更大 padding
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      // TextButton 主题：圆角 16
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),

      // FilledButton 主题：圆角 16 + 加粗文字 + 更大 padding
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      // 分割线主题
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
    );
  }
}

/// 间距常量
class AppSpacing {
  AppSpacing._();

  /// 4.0
  static const double xs = 4;

  /// 8.0
  static const double s = 8;

  /// 16.0
  static const double m = 16;

  /// 24.0
  static const double l = 24;

  /// 32.0
  static const double xl = 32;
}

/// 文字样式辅助
///
/// 基于当前 BuildContext 的 Theme 生成常用文字样式。
class AppTextStyles {
  AppTextStyles._();

  /// 辅助文字样式：用于时间戳、次要信息
  ///
  /// fontSize 11, onSurfaceVariant 色
  static TextStyle caption(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant);
  }

  /// 标签文字样式：用于标签、badge
  ///
  /// fontSize 12, onSurfaceVariant 色
  static TextStyle label(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant);
  }
}
