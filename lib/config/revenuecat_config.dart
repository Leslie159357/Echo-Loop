// RevenueCat（IAP 订阅）配置
//
// 通过 `--dart-define` 注入 RevenueCat 的**公开 SDK API Key**（按平台区分，
// 可安全打进客户端）。与 Supabase 一样三套环境各维护一份，build 时用
// `--dart-define-from-file=auth.env` 加载。
//
// Key 来源：RevenueCat 后台 → Project settings → API keys →
//   - Apple App Store 的 public key（iOS / macOS 用）
//   - Google Play Store 的 public key（Android 用）
//
// 任一平台 key 缺失时，main.dart 跳过该平台的 Purchases 初始化，订阅功能不可用
// 但 app 仍可匿名运行（与认证一致的渐进式策略）。
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;

import 'web_purchase_config.dart';

/// Apple App Store 平台的 RevenueCat 公开 API Key（iOS / macOS）。
const _revenueCatApiKeyApple = String.fromEnvironment(
  'REVENUECAT_API_KEY_APPLE',
);

/// Google Play Store 平台的 RevenueCat 公开 API Key（Android）。
const _revenueCatApiKeyGoogle = String.fromEnvironment(
  'REVENUECAT_API_KEY_GOOGLE',
);

/// RevenueCat 中代表 Plus 会员的 entitlement identifier。
///
/// 必须与 RevenueCat 后台 Entitlements 里配置的标识一致（当前后台为 `Echo Loop Plus`）。
/// 可通过 `--dart-define=REVENUECAT_ENTITLEMENT_ID=xxx` 覆盖。
const revenueCatEntitlementId = String.fromEnvironment(
  'REVENUECAT_ENTITLEMENT_ID',
  defaultValue: 'Echo Loop Plus',
);

/// 当前平台应使用的 RevenueCat API Key（不可用平台返回空串）。
///
/// iOS 与 macOS 都属于 Apple App Store / StoreKit 购买通道，统一由
/// `REVENUECAT_API_KEY_APPLE` 控制；Android 由 Google Play key 控制。
String get revenueCatApiKey {
  return revenueCatApiKeyForPlatform(
    isWeb: kIsWeb,
    isIOS: !kIsWeb && Platform.isIOS,
    isMacOS: !kIsWeb && Platform.isMacOS,
    isAndroid: !kIsWeb && Platform.isAndroid,
    appleKey: _revenueCatApiKeyApple,
    googleKey: _revenueCatApiKeyGoogle,
  );
}

/// 根据目标平台选择 RevenueCat public key。
///
/// 抽成纯函数便于测试，避免平台判断散落在 UI / 购买服务中。Apple 生态内
/// iOS 与 macOS 共用同一组 StoreKit / RevenueCat 配置。
@visibleForTesting
String revenueCatApiKeyForPlatform({
  required bool isWeb,
  required bool isIOS,
  required bool isMacOS,
  required bool isAndroid,
  required String appleKey,
  required String googleKey,
}) {
  if (isWeb) return '';
  if (isIOS || isMacOS) return appleKey;
  if (isAndroid) return googleKey;
  return '';
}

/// 当前平台是否已配置 RevenueCat（决定是否初始化 SDK / 启用真实购买）。
bool get isRevenueCatConfigured => revenueCatApiKey.isNotEmpty;

/// 当前平台是否支持订阅（订阅 UI 展示的总闸）。
///
/// 「某平台是否启用订阅」由编译期配置表达：
/// - 商店渠道：注入 RC key → 走原生内购；
/// - 非商店渠道（侧载 APK / 桌面）：注入 `DISTRIBUTION_CHANNEL` + `WEB_PURCHASE_LINK_BASE`
///   → 走网页支付（[isWebCheckoutConfigured]）；
/// - 本地 StoreKit 测试模式视为支持（开发调试用）。
bool get isSubscriptionSupported =>
    useLocalStoreKit || isRevenueCatConfigured || isWebCheckoutConfigured;

/// 本地 StoreKit 测试模式开关（`--dart-define=USE_LOCAL_STOREKIT=true`）。
///
/// 开启后：
/// - `main.dart` **跳过** `Purchases.configure()`，RevenueCat 完全不初始化，
///   因此 Xcode `.storekit` 本地交易不会被 RC SDK 捕获上报（不污染 RC Sandbox）；
/// - 购买走 `in_app_purchase` 直连 `.storekit`，权益状态只存在于 StoreKit 本地，
///   重置只需 Xcode「Debug ▸ StoreKit ▸ Manage Transactions」删交易。
///
/// 仅供本地开发/测试使用；release 构建不应注入此 define。
const bool useLocalStoreKit = bool.fromEnvironment('USE_LOCAL_STOREKIT');

/// 平台订阅管理页 URL（「管理订阅」跳转用）。
///
/// iOS 走 App Store 订阅管理深链；Android 走 Google Play 订阅页。
String? get manageSubscriptionsUrl {
  if (kIsWeb) return null;
  // 网页支付渠道优先：这类订阅经 Stripe 结账，**不**走商店订阅页（侧载 APK 仍是
  // Android，但绝不能跳 Google Play 订阅管理）。v1 无稳定的自助管理深链时返回
  // 可选注入的 [webManageUrl]，缺省为 null（Paywall 据此隐藏「管理订阅」按钮）。
  if (isWebCheckoutConfigured) {
    return webManageUrl.isNotEmpty ? webManageUrl : null;
  }
  if (Platform.isIOS || Platform.isMacOS) {
    return 'https://apps.apple.com/account/subscriptions';
  }
  if (Platform.isAndroid) {
    return 'https://play.google.com/store/account/subscriptions';
  }
  return null;
}

/// 网页支付订阅的自助管理页 URL（可选，`--dart-define=WEB_MANAGE_URL=` 注入）。
///
/// RevenueCat Billing 的客户自助管理链接是按客户下发的，无 SDK 时拿不到稳定 URL；
/// 若你有统一的账户/管理页可注入此项，否则「管理订阅」按钮隐藏。
const webManageUrl = String.fromEnvironment('WEB_MANAGE_URL');
