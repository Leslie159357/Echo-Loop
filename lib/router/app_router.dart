/// GoRouter 路由配置
///
/// 定义应用的路由结构和类型安全的路径常量。
/// 使用 StatefulShellRoute.indexedStack 保持 Tab 状态。
/// 详情页使用 parentNavigatorKey 确保全屏展示。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../screens/collection_screen.dart';
import '../screens/collection_detail_screen.dart';
import '../screens/study_screen.dart';
import '../screens/favorites_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/learning_plan_screen.dart';
import '../screens/player_screen.dart';
import 'main_shell.dart';

/// 全局根导航器 key
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// 路由路径常量 + 类型安全的路径构建方法
abstract class AppRoutes {
  static const collections = '/collections';
  static const study = '/study';
  static const favorites = '/favorites';
  static const settings = '/settings';

  /// 合集详情页路径
  static String collectionDetail(String collectionId) =>
      '/collections/$collectionId';

  /// 学习计划页路径
  static String learningPlan(String collectionId, String audioId) =>
      '/collections/$collectionId/$audioId/plan';

  /// 播放器页路径
  static String player(String collectionId, String audioId) =>
      '/collections/$collectionId/$audioId/player';
}

/// GoRouter Provider（keepAlive，不可 invalidate）
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.study,
    redirect: (context, state) {
      if (state.uri.path == '/') return AppRoutes.study;
      return null;
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/collections',
                builder: (context, state) => const CollectionScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/study',
                builder: (context, state) => const StudyScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/favorites',
                builder: (context, state) => const FavoritesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      // 详情页放在 shell 外部，全屏显示
      GoRoute(
        path: '/collections/:collectionId',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final collectionId = state.pathParameters['collectionId']!;
          return CollectionDetailScreen(collectionId: collectionId);
        },
        routes: [
          GoRoute(
            path: ':audioId/plan',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) {
              final collectionId = state.pathParameters['collectionId']!;
              final audioId = state.pathParameters['audioId']!;
              return LearningPlanScreen(
                collectionId: collectionId,
                audioItemId: audioId,
              );
            },
          ),
          GoRoute(
            path: ':audioId/player',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) => const PlayerScreen(),
          ),
        ],
      ),
    ],
  );
});
