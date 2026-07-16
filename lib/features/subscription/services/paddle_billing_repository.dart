/// Paddle direct 渠道的后端 API client。
library;

import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../config/api_config.dart';
import '../../../providers/package_info_provider.dart';
import '../../../services/backend_dio.dart';
import '../models/subscription_plan.dart';

const _uuid = Uuid();

/// 一次 Paddle checkout 的服务端结果。
class PaddleCheckoutSession {
  const PaddleCheckoutSession({
    required this.attemptId,
    required this.checkoutUrl,
  });

  final String attemptId;
  final Uri checkoutUrl;
}

/// Paddle 后端 API 访问层；不负责登录状态或 UI 编排。
class PaddleBillingRepository {
  PaddleBillingRepository({required String baseUrl, String? appVersion})
    : _dio = createBackendDio(
        baseUrl: baseUrl,
        appVersion: appVersion,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        apiLogTag: 'PADDLE',
      );

  @visibleForTesting
  PaddleBillingRepository.withDio(this._dio);

  final Dio _dio;

  /// 从服务端读取当前 locale 的 Paddle 套餐，价格不在客户端计算。
  Future<List<SubscriptionPlan>> fetchPlans() async {
    final locale = ui.PlatformDispatcher.instance.locale.toLanguageTag();
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/paddle/plans',
      queryParameters: {'locale': locale},
    );
    final data = response.data;
    final rawPlans = data?['plans'];
    if (rawPlans is! List) {
      throw StateError('Paddle plans response is invalid');
    }
    return rawPlans
        .whereType<Map>()
        .map((raw) => _planFrom(Map<String, dynamic>.from(raw)))
        .toList(growable: false);
  }

  /// 创建服务端 Paddle transaction；客户端不能提交 discount 或 redirect URL。
  Future<PaddleCheckoutSession> createCheckout({
    required String accessToken,
    required String planId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/paddle/checkout',
      data: {'planId': planId, 'locale': _localeTag()},
      options: Options(
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Idempotency-Key': _uuid.v4(),
        },
      ),
    );
    final data = response.data;
    final attemptId = data?['attemptId'];
    final checkoutUrl = data?['checkoutUrl'];
    if (attemptId is! String || checkoutUrl is! String) {
      throw StateError('Paddle checkout response is invalid');
    }
    final uri = Uri.tryParse(checkoutUrl);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw StateError('Paddle checkout URL is invalid');
    }
    return PaddleCheckoutSession(attemptId: attemptId, checkoutUrl: uri);
  }

  /// 创建短期 Customer Portal session，返回服务端生成的 overview URL。
  Future<Uri> createPortal({required String accessToken}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/paddle/portal',
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    final raw = response.data?['portalUrl'];
    if (raw is! String) {
      throw StateError('Paddle portal response is invalid');
    }
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw StateError('Paddle portal URL is invalid');
    }
    return uri;
  }

  SubscriptionPlan _planFrom(Map<String, dynamic> json) {
    final planId = json['planId'];
    final title = json['title'];
    final priceString = json['priceString'];
    if (planId is! String || title is! String || priceString is! String) {
      throw StateError('Paddle plan fields are invalid');
    }
    final period = switch (planId) {
      'plus_monthly' => SubscriptionPeriod.monthly,
      'plus_yearly' => SubscriptionPeriod.yearly,
      _ => throw StateError('Unsupported Paddle plan id: $planId'),
    };
    final offer = json['introOffer'];
    return SubscriptionPlan(
      planId: planId,
      title: title,
      priceString: priceString,
      period: period,
      hasFreeTrial: json['hasFreeTrial'] == true,
      trialDays: _intValue(json['trialDays'], fallback: 0),
      introOffer: offer is Map
          ? _introOfferFrom(Map<String, dynamic>.from(offer))
          : null,
    );
  }

  SubscriptionIntroOffer _introOfferFrom(Map<String, dynamic> json) {
    final priceString = json['priceString'];
    final renewalPriceString = json['renewalPriceString'];
    if (priceString is! String || renewalPriceString is! String) {
      throw StateError('Paddle intro offer fields are invalid');
    }
    final period = switch (json['period']) {
      'day' => SubscriptionOfferPeriod.day,
      'week' => SubscriptionOfferPeriod.week,
      'month' => SubscriptionOfferPeriod.month,
      'year' => SubscriptionOfferPeriod.year,
      _ => SubscriptionOfferPeriod.unknown,
    };
    return SubscriptionIntroOffer(
      priceString: priceString,
      period: period,
      periodNumberOfUnits: _intValue(json['periodNumberOfUnits'], fallback: 1),
      cycles: _intValue(json['cycles'], fallback: 1),
      isFreeTrial: json['isFreeTrial'] == true,
      renewalPriceString: renewalPriceString,
    );
  }

  String _localeTag() => ui.PlatformDispatcher.instance.locale.toLanguageTag();

  int _intValue(Object? value, {required int fallback}) =>
      value is num ? value.toInt() : fallback;
}

final paddleBillingRepositoryProvider = Provider<PaddleBillingRepository>((
  ref,
) {
  return PaddleBillingRepository(
    baseUrl: apiBaseUrl,
    appVersion: readAppVersion(ref),
  );
});
