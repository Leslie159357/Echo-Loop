import 'package:dio/dio.dart';
import 'package:echo_loop/features/subscription/models/subscription_plan.dart';
import 'package:echo_loop/features/subscription/services/paddle_billing_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  late _MockDio dio;
  late PaddleBillingRepository repository;

  setUp(() {
    dio = _MockDio();
    repository = PaddleBillingRepository.withDio(dio);
  });

  test('fetchPlans 映射月付、年付和首年优惠', () async {
    when(
      () => dio.get<Map<String, dynamic>>(
        '/api/paddle/plans',
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: '/api/paddle/plans'),
        statusCode: 200,
        data: {
          'plans': [
            {
              'planId': 'plus_monthly',
              'title': 'Monthly',
              'priceString': r'$4.99',
              'period': 'monthly',
              'hasFreeTrial': false,
              'trialDays': 0,
              'introOffer': null,
            },
            {
              'planId': 'plus_yearly',
              'title': 'Yearly',
              'priceString': r'$49.99',
              'period': 'yearly',
              'hasFreeTrial': false,
              'trialDays': 0,
              'introOffer': {
                'priceString': r'$24.99',
                'period': 'year',
                'periodNumberOfUnits': 1,
                'cycles': 1,
                'isFreeTrial': false,
                'renewalPriceString': r'$49.99',
              },
            },
          ],
        },
      ),
    );

    final plans = await repository.fetchPlans();

    expect(plans, hasLength(2));
    expect(plans.first.period, SubscriptionPeriod.monthly);
    expect(plans.last.period, SubscriptionPeriod.yearly);
    expect(plans.last.introOffer?.priceString, r'$24.99');
    expect(plans.last.introOffer?.renewalPriceString, r'$49.99');
  });

  test('createCheckout 只提交 plan/locale，并携带 Bearer 与 UUID 幂等键', () async {
    when(
      () => dio.post<Map<String, dynamic>>(
        '/api/paddle/checkout',
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: '/api/paddle/checkout'),
        statusCode: 200,
        data: {
          'attemptId': 'attempt-1',
          'checkoutUrl': 'https://checkout.paddle.test/txn_1',
        },
      ),
    );

    final session = await repository.createCheckout(
      accessToken: 'token',
      planId: 'plus_yearly',
    );

    expect(session.attemptId, 'attempt-1');
    expect(session.checkoutUrl.host, 'checkout.paddle.test');
    final captured = verify(
      () => dio.post<Map<String, dynamic>>(
        '/api/paddle/checkout',
        data: captureAny(named: 'data'),
        options: captureAny(named: 'options'),
      ),
    ).captured;
    final data = Map<String, dynamic>.from(captured[0] as Map);
    final options = captured[1] as Options;
    expect(data.keys, containsAll(<String>['planId', 'locale']));
    expect(data, isNot(contains('discountId')));
    expect(options.headers?['Authorization'], 'Bearer token');
    expect(
      options.headers?['Idempotency-Key'],
      matches(RegExp(r'^[0-9a-f-]{36}$')),
    );
  });

  test('createPortal 返回服务端短期 overview URL', () async {
    when(
      () => dio.post<Map<String, dynamic>>(
        '/api/paddle/portal',
        options: any(named: 'options'),
      ),
    ).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: '/api/paddle/portal'),
        statusCode: 200,
        data: {'portalUrl': 'https://customer-portal.paddle.test/session'},
      ),
    );

    final uri = await repository.createPortal(accessToken: 'token');

    expect(uri.host, 'customer-portal.paddle.test');
  });

  test('checkout 非 HTTPS URL fail closed', () async {
    when(
      () => dio.post<Map<String, dynamic>>(
        '/api/paddle/checkout',
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: '/api/paddle/checkout'),
        statusCode: 200,
        data: {'attemptId': 'attempt-1', 'checkoutUrl': 'http://unsafe.test'},
      ),
    );

    expect(
      repository.createCheckout(accessToken: 'token', planId: 'plus_yearly'),
      throwsStateError,
    );
  });
}
