/// `supabaseSessionProvider` / `isAuthenticatedProvider` 基线测试。
///
/// 步骤 0 阶段：Supabase 凭据未通过 `--dart-define` 注入，
/// `isAuthConfigured == false`，provider 走 fallback 分支永远 emit `null`。
/// 验证 fallback 分支不崩、行为合理，避免后续步骤回归。
library;

import 'package:echo_loop/analytics/analytics_providers.dart';
import 'package:echo_loop/analytics/analytics_service.dart';
import 'package:echo_loop/features/auth/providers/auth_providers.dart';
import 'package:echo_loop/services/user_id_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

void main() {
  group('supabaseSessionProvider（Supabase 未配置 fallback 分支）', () {
    test('首值 emit null（匿名态）', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(supabaseSessionProvider.future);

      final value = container.read(supabaseSessionProvider).valueOrNull;
      expect(value, isNull);
    });

    test('Stream 完成且不抛错', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final future = container.read(supabaseSessionProvider.future);
      expect(await future, isNull);
    });
  });

  group('isAuthenticatedProvider', () {
    test('未配置时为 false', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(supabaseSessionProvider.future);

      expect(container.read(isAuthenticatedProvider), isFalse);
    });
  });

  group('AuthController', () {
    late _MockAuthRepository repository;
    late _MockAnalyticsService analytics;
    late ProviderContainer container;

    setUp(() {
      repository = _MockAuthRepository();
      analytics = _MockAnalyticsService();
      container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(repository),
          analyticsServiceProvider.overrideWithValue(analytics),
          userIdProvider.overrideWithValue('anon-123'),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('requestEmailOtp 通过统一仓库发送验证码', () async {
      when(
        () => repository.sendEmailOtp('user@example.com'),
      ).thenAnswer((_) async {});

      await container
          .read(authControllerProvider)
          .requestEmailOtp('user@example.com');

      verify(() => repository.sendEmailOtp('user@example.com')).called(1);
    });

    test('verifyEmailOtp 通过统一仓库验证并同步 analytics 身份属性', () async {
      final user = User(
        id: 'user-1',
        email: 'user@example.com',
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: '2026-06-03T00:00:00.000Z',
      );
      final response = AuthResponse(session: null, user: user);

      when(
        () => repository.verifyEmailOtp(
          email: 'user@example.com',
          token: '123456',
        ),
      ).thenAnswer((_) async => response);
      when(() => analytics.setUserId('user-1')).thenAnswer((_) async {});
      when(
        () => analytics.registerSuperProperties({'supabase_user_id': 'user-1'}),
      ).thenAnswer((_) async {});
      when(
        () => analytics.setUserProperty('email', 'user@example.com'),
      ).thenAnswer((_) async {});
      when(
        () => analytics.setUserProperty('app_anonymous_id', 'anon-123'),
      ).thenAnswer((_) async {});

      await container
          .read(authControllerProvider)
          .verifyEmailOtp(email: 'user@example.com', token: '123456');

      verify(
        () => repository.verifyEmailOtp(
          email: 'user@example.com',
          token: '123456',
        ),
      ).called(1);
      verify(() => analytics.setUserId('user-1')).called(1);
      verify(
        () => analytics.registerSuperProperties({'supabase_user_id': 'user-1'}),
      ).called(1);
      verify(
        () => analytics.setUserProperty('email', 'user@example.com'),
      ).called(1);
      verify(
        () => analytics.setUserProperty('app_anonymous_id', 'anon-123'),
      ).called(1);
    });

    test('verifyEmailOtp 无邮箱时跳过 email 属性，但仍绑定匿名 ID', () async {
      final user = User(
        id: 'user-1',
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: '2026-06-03T00:00:00.000Z',
      );
      final response = AuthResponse(session: null, user: user);

      when(
        () => repository.verifyEmailOtp(
          email: 'user@example.com',
          token: '123456',
        ),
      ).thenAnswer((_) async => response);
      when(() => analytics.setUserId('user-1')).thenAnswer((_) async {});
      when(
        () => analytics.registerSuperProperties({'supabase_user_id': 'user-1'}),
      ).thenAnswer((_) async {});
      when(
        () => analytics.setUserProperty('app_anonymous_id', 'anon-123'),
      ).thenAnswer((_) async {});

      await container
          .read(authControllerProvider)
          .verifyEmailOtp(email: 'user@example.com', token: '123456');

      verify(() => analytics.setUserId('user-1')).called(1);
      verify(
        () => analytics.registerSuperProperties({'supabase_user_id': 'user-1'}),
      ).called(1);
      verify(
        () => analytics.setUserProperty('app_anonymous_id', 'anon-123'),
      ).called(1);
      verifyNever(() => analytics.setUserProperty('email', any()));
    });

    test('signOut 通过统一仓库退出并清理 analytics userId', () async {
      when(() => repository.signOut()).thenAnswer((_) async {});
      when(() => analytics.setUserId(null)).thenAnswer((_) async {});

      await container.read(authControllerProvider).signOut();

      verify(() => repository.signOut()).called(1);
      verify(() => analytics.setUserId(null)).called(1);
    });
  });

  group('AuthAnalyticsSync', () {
    late _MockAnalyticsService analytics;
    late ProviderContainer container;

    setUp(() {
      analytics = _MockAnalyticsService();
      container = ProviderContainer(
        overrides: [
          analyticsServiceProvider.overrideWithValue(analytics),
          userIdProvider.overrideWithValue('anon-123'),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('syncSignedInUser 同步真实 ID、邮箱和匿名 ID', () async {
      final user = User(
        id: 'user-1',
        email: 'user@example.com',
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: '2026-06-03T00:00:00.000Z',
      );

      when(() => analytics.setUserId('user-1')).thenAnswer((_) async {});
      when(
        () => analytics.registerSuperProperties({'supabase_user_id': 'user-1'}),
      ).thenAnswer((_) async {});
      when(
        () => analytics.setUserProperty('email', 'user@example.com'),
      ).thenAnswer((_) async {});
      when(
        () => analytics.setUserProperty('app_anonymous_id', 'anon-123'),
      ).thenAnswer((_) async {});

      await container.read(authAnalyticsSyncProvider).syncSignedInUser(user);

      verify(() => analytics.setUserId('user-1')).called(1);
      verify(
        () => analytics.registerSuperProperties({'supabase_user_id': 'user-1'}),
      ).called(1);
      verify(
        () => analytics.setUserProperty('email', 'user@example.com'),
      ).called(1);
      verify(
        () => analytics.setUserProperty('app_anonymous_id', 'anon-123'),
      ).called(1);
    });

    test('syncSessionChange 首次恢复已登录 session 也会同步身份', () async {
      final user = User(
        id: 'user-1',
        email: 'user@example.com',
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: '2026-06-03T00:00:00.000Z',
      );
      final session = Session(
        accessToken: 'access',
        refreshToken: 'refresh',
        tokenType: 'bearer',
        user: user,
      );

      when(() => analytics.setUserId('user-1')).thenAnswer((_) async {});
      when(
        () => analytics.registerSuperProperties({'supabase_user_id': 'user-1'}),
      ).thenAnswer((_) async {});
      when(
        () => analytics.setUserProperty('email', 'user@example.com'),
      ).thenAnswer((_) async {});
      when(
        () => analytics.setUserProperty('app_anonymous_id', 'anon-123'),
      ).thenAnswer((_) async {});

      await container.read(authAnalyticsSyncProvider).syncSessionChange(
        previous: null,
        current: session,
      );

      verify(() => analytics.setUserId('user-1')).called(1);
      verify(
        () => analytics.setUserProperty('email', 'user@example.com'),
      ).called(1);
      verify(
        () => analytics.setUserProperty('app_anonymous_id', 'anon-123'),
      ).called(1);
    });

    test('syncSessionChange 仅在已登录 -> 已登出时 reset analytics', () async {
      final user = User(
        id: 'user-1',
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: '2026-06-03T00:00:00.000Z',
      );
      final session = Session(
        accessToken: 'access',
        refreshToken: 'refresh',
        tokenType: 'bearer',
        user: user,
      );

      when(() => analytics.setUserId(null)).thenAnswer((_) async {});
      when(
        () => analytics.unregisterSuperProperty('supabase_user_id'),
      ).thenAnswer((_) async {});

      await container.read(authAnalyticsSyncProvider).syncSessionChange(
        previous: session,
        current: null,
      );

      verify(
        () => analytics.unregisterSuperProperty('supabase_user_id'),
      ).called(1);
      verify(() => analytics.setUserId(null)).called(1);
    });

    test('syncSessionChange 匿名启动时不 reset analytics', () async {
      await container.read(authAnalyticsSyncProvider).syncSessionChange(
        previous: null,
        current: null,
      );

      verifyNever(() => analytics.setUserId(null));
    });
  });
}
