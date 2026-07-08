// 网页支付（RevenueCat Web Purchase Link）配置
//
// 面向**无商店内购通道**的分发渠道：Android 侧载 APK、macOS 官网/GitHub 下载、
// Windows。这些端没有可用的 RevenueCat 原生 SDK，购买改为在浏览器打开
// RevenueCat 托管的 Web Purchase Link（Stripe 结账），权益仍由 RC webhook 落库、
// 客户端经后端 `/api/entitlements` 读回（见 `entitlement_repository.dart`）。
//
// **Google Play 政策洁净（关键）**：网页支付入口**只能进「非商店」构建**。是否启用
// 由编译期 `--dart-define=DISTRIBUTION_CHANNEL` 决定——APK/桌面构建注入 `apk`/`desktop`
// 才启用；Play 版（appbundle）不注入或注入 `play`，构建里根本不含引导外部支付的路径。
library;

import 'package:flutter/foundation.dart' show visibleForTesting;

/// 分发渠道（编译期注入）。
///
/// - `apk`：Android 侧载直装包 → 启用网页支付。
/// - `desktop`：macOS 官网/GitHub、Windows → 启用网页支付。
/// - `play` / 空：Google Play / App Store 等商店构建 → **不**启用网页支付（政策洁净）。
const _distributionChannel = String.fromEnvironment('DISTRIBUTION_CHANNEL');

/// RevenueCat Web Purchase Link 的 base（**到 token 为止、不含末尾用户 ID**）。
///
/// 注意 prod / sandbox 结构不同，故整段 base 由构建注入而非只注入 token：
/// - Production：`https://pay.rev.cat/<token>`
/// - Sandbox：`https://pay.rev.cat/sandbox/<token>`（多一段 `sandbox`）
///
/// release 注入 production base，debug/测试注入 sandbox base；不注入则网页支付不可用。
const webPurchaseLinkBase = String.fromEnvironment('WEB_PURCHASE_LINK_BASE');

/// 当前构建是否属于「启用网页支付」的分发渠道（仅编译期判定，Play 版恒 false）。
bool get isWebCheckoutChannel =>
    _distributionChannel == 'apk' || _distributionChannel == 'desktop';

/// 网页支付是否可用（渠道启用 **且** 已注入 Purchase Link base）。
///
/// 二者缺一即不可用：渠道未开 → 政策洁净不暴露入口；base 缺失 → 无处结账。
bool get isWebCheckoutConfigured =>
    isWebCheckoutChannel && webPurchaseLinkBase.isNotEmpty;

/// 拼出携带用户身份的 Web Purchase Link。
///
/// 必须附 URL-encoded 的 Supabase user.id 作为 RevenueCat app_user_id：不附则
/// RevenueCat 返回 404（见官方文档），且权益无法绑定到用户。调用方须保证已登录。
/// [userId] 为空时返回 null（调用方应先要求登录，不发起结账）。
Uri? buildWebPurchaseUri(String userId) {
  if (!isWebCheckoutConfigured || userId.isEmpty) return null;
  return composeWebPurchaseUri(webPurchaseLinkBase, userId);
}

/// 纯函数：把 base 与 userId 拼成结账 URL（[buildWebPurchaseUri] 的可测内核）。
///
/// 去掉 base 末尾多余的 '/' 防双斜杠；userId 做 URL-encode。base 为空返回 null。
@visibleForTesting
Uri? composeWebPurchaseUri(String base, String userId) {
  if (base.isEmpty || userId.isEmpty) return null;
  final trimmed = base.endsWith('/')
      ? base.substring(0, base.length - 1)
      : base;
  return Uri.parse('$trimmed/${Uri.encodeComponent(userId)}');
}
