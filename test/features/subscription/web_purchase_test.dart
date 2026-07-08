import 'package:echo_loop/config/web_purchase_config.dart';
import 'package:echo_loop/features/subscription/models/subscription_plan.dart';
import 'package:echo_loop/features/subscription/services/web_purchase_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// 网页支付渠道单测：URL 拼接内核 + [WebPurchaseService] 的占位契约。
void main() {
  group('composeWebPurchaseUri', () {
    test('prod base + userId → 追加 URL-encoded userId', () {
      final uri = composeWebPurchaseUri(
        'https://pay.rev.cat/bwnqefbrodyrornl',
        'a1b2-c3',
      );
      expect(uri.toString(), 'https://pay.rev.cat/bwnqefbrodyrornl/a1b2-c3');
    });

    test('sandbox base（含 /sandbox 段）保持结构', () {
      final uri = composeWebPurchaseUri(
        'https://pay.rev.cat/sandbox/dlgtqpwowmzoingm',
        'uid',
      );
      expect(
        uri.toString(),
        'https://pay.rev.cat/sandbox/dlgtqpwowmzoingm/uid',
      );
    });

    test('base 末尾多余 / 被去掉，不出现双斜杠', () {
      final uri = composeWebPurchaseUri('https://pay.rev.cat/tok/', 'uid');
      expect(uri.toString(), 'https://pay.rev.cat/tok/uid');
    });

    test('userId 做 URL-encode（含特殊字符）', () {
      final uri = composeWebPurchaseUri('https://pay.rev.cat/tok', 'a b/c');
      expect(uri.toString(), 'https://pay.rev.cat/tok/a%20b%2Fc');
    });

    test('base 或 userId 为空 → null', () {
      expect(composeWebPurchaseUri('', 'uid'), isNull);
      expect(composeWebPurchaseUri('https://pay.rev.cat/tok', ''), isNull);
    });
  });

  group('WebPurchaseService 占位契约', () {
    const service = WebPurchaseService();

    test('fetchPlans → 空（无商店 SDK，套餐由托管结账页展示）', () async {
      expect(await service.fetchPlans(), const <SubscriptionPlan>[]);
    });

    test('currentEntitlement 抛异常（平台不可达，交由缓存兜底、不误降级）', () {
      expect(service.currentEntitlement(), throwsStateError);
    });

    test('purchase / restore 抛 UnsupportedError（网页态不走此路径）', () {
      expect(service.purchase('x'), throwsUnsupportedError);
      expect(service.restore(), throwsUnsupportedError);
    });

    test('entitlementStream 为空流', () {
      expect(service.entitlementStream, emitsDone);
    });

    test('identify / invalidate 为 no-op（不抛）', () async {
      await service.identify('u');
      await service.identify(null);
      await service.invalidateCustomerInfoCache();
      expect(await service.debugCustomerInfoSnapshot(), const {});
    });
  });
}
