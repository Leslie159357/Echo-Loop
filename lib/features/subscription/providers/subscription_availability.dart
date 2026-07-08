/// 订阅可用性查询：当前平台是否启用订阅。
///
/// UI 层所有「要不要展示订阅入口 / 能不能进 Paywall」的判断统一 watch 本
/// provider，不直接读 config——集中一个入口，测试可 override 模拟各平台。
///
/// 真相源是编译期配置 [isSubscriptionSupported]（按平台注入 RC key 即启用，
/// 见 `lib/config/revenuecat_config.dart`）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../config/revenuecat_config.dart';
import '../../../config/web_purchase_config.dart';

part 'subscription_availability.g.dart';

/// 当前平台是否支持订阅（订阅 UI 展示总闸）。
@riverpod
bool subscriptionAvailability(Ref ref) => isSubscriptionSupported;

/// 当前是否走「网页支付」渠道（侧载 APK / 桌面）。
///
/// Paywall 据此切换购买交互：true 时不展示商店套餐卡、改为「浏览器结账 + 回流对账」。
/// 测试可 override 模拟网页渠道。
@riverpod
bool webCheckoutMode(Ref ref) => isWebCheckoutConfigured;
