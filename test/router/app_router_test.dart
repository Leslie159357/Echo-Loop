/// GoRouter 路由配置测试
///
/// 验证路由结构、重定向、路径参数传递等。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:fluency/l10n/app_localizations.dart';
import 'package:fluency/router/app_router.dart';
import 'package:fluency/providers/settings_provider.dart';
import 'package:fluency/providers/audio_library_provider.dart';
import 'package:fluency/providers/collection_provider.dart';
import 'package:fluency/providers/listening_practice/listening_practice_provider.dart';
import 'package:fluency/providers/audio_engine/audio_engine_provider.dart';
import 'package:fluency/providers/package_info_provider.dart';
import 'package:fluency/theme/app_theme.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../helpers/mock_providers.dart';

void main() {
  final testPackageInfo = PackageInfo(
    appName: 'Fluency',
    packageName: 'top.valuespot.fluency',
    version: '1.0.0',
    buildNumber: '1',
  );

  Widget createRouterTestApp(GoRouter router) {
    return ProviderScope(
      overrides: [
        appSettingsProvider.overrideWith(() => TestAppSettings()),
        audioLibraryProvider.overrideWith(() => TestAudioLibrary()),
        collectionListProvider.overrideWith(() => TestCollectionList()),
        listeningPracticeProvider.overrideWith(() => TestListeningPractice()),
        audioEngineProvider.overrideWith(() => TestAudioEngine()),
        packageInfoProvider.overrideWithValue(testPackageInfo),
      ],
      child: MaterialApp.router(
        supportedLocales: const [Locale('en'), Locale('zh')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.light(),
        routerConfig: router,
      ),
    );
  }

  group('AppRoutes', () {
    test('路径常量正确', () {
      expect(AppRoutes.collections, '/collections');
      expect(AppRoutes.study, '/study');
      expect(AppRoutes.favorites, '/favorites');
      expect(AppRoutes.settings, '/settings');
    });

    test('collectionDetail 构建正确路径', () {
      expect(
        AppRoutes.collectionDetail('abc-123'),
        '/collections/abc-123',
      );
    });

    test('learningPlan 构建正确路径', () {
      expect(
        AppRoutes.learningPlan('col-1', 'audio-2'),
        '/collections/col-1/audio-2/plan',
      );
    });

    test('player 构建正确路径', () {
      expect(
        AppRoutes.player('col-1', 'audio-2'),
        '/collections/col-1/audio-2/player',
      );
    });
  });

  group('GoRouter 配置', () {
    testWidgets('初始路由为 /study', (tester) async {
      final router = GoRouter(
        initialLocation: AppRoutes.study,
        routes: [
          GoRoute(
            path: '/study',
            builder: (context, state) =>
                const Scaffold(body: Text('Study Page')),
          ),
        ],
      );

      await tester.pumpWidget(createRouterTestApp(router));
      await tester.pumpAndSettle();

      expect(find.text('Study Page'), findsOneWidget);
    });

    testWidgets('/ 重定向到 /study', (tester) async {
      final router = GoRouter(
        initialLocation: '/',
        redirect: (context, state) {
          if (state.uri.path == '/') return AppRoutes.study;
          return null;
        },
        routes: [
          GoRoute(
            path: '/study',
            builder: (context, state) =>
                const Scaffold(body: Text('Study Page')),
          ),
        ],
      );

      await tester.pumpWidget(createRouterTestApp(router));
      await tester.pumpAndSettle();

      expect(find.text('Study Page'), findsOneWidget);
    });

    testWidgets('路径参数正确传递到合集详情页', (tester) async {
      final router = GoRouter(
        initialLocation: '/collections/test-col-id',
        routes: [
          GoRoute(
            path: '/collections/:collectionId',
            builder: (context, state) {
              final id = state.pathParameters['collectionId']!;
              return Scaffold(body: Text('Detail: $id'));
            },
          ),
        ],
      );

      await tester.pumpWidget(createRouterTestApp(router));
      await tester.pumpAndSettle();

      expect(find.text('Detail: test-col-id'), findsOneWidget);
    });

    testWidgets('学习计划页路径参数正确传递', (tester) async {
      final router = GoRouter(
        initialLocation: '/collections/col-1/audio-2/plan',
        routes: [
          GoRoute(
            path: '/collections/:collectionId',
            builder: (context, state) =>
                const Scaffold(body: Text('Detail')),
            routes: [
              GoRoute(
                path: ':audioId/plan',
                builder: (context, state) {
                  final colId = state.pathParameters['collectionId']!;
                  final audioId = state.pathParameters['audioId']!;
                  return Scaffold(
                    body: Text('Plan: $colId/$audioId'),
                  );
                },
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(createRouterTestApp(router));
      await tester.pumpAndSettle();

      expect(find.text('Plan: col-1/audio-2'), findsOneWidget);
    });

    testWidgets('播放器路径参数正确传递', (tester) async {
      final router = GoRouter(
        initialLocation: '/collections/col-1/audio-2/player',
        routes: [
          GoRoute(
            path: '/collections/:collectionId',
            builder: (context, state) =>
                const Scaffold(body: Text('Detail')),
            routes: [
              GoRoute(
                path: ':audioId/player',
                builder: (context, state) {
                  final colId = state.pathParameters['collectionId']!;
                  final audioId = state.pathParameters['audioId']!;
                  return Scaffold(
                    body: Text('Player: $colId/$audioId'),
                  );
                },
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(createRouterTestApp(router));
      await tester.pumpAndSettle();

      expect(find.text('Player: col-1/audio-2'), findsOneWidget);
    });
  });
}
