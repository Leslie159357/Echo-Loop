// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subscription_availability.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$subscriptionAvailabilityHash() =>
    r'b445e1bd133f9afb86390b9055e59b9ebf476ab0';

/// 当前平台是否支持订阅（订阅 UI 展示总闸）。
///
/// Copied from [subscriptionAvailability].
@ProviderFor(subscriptionAvailability)
final subscriptionAvailabilityProvider = AutoDisposeProvider<bool>.internal(
  subscriptionAvailability,
  name: r'subscriptionAvailabilityProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$subscriptionAvailabilityHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SubscriptionAvailabilityRef = AutoDisposeProviderRef<bool>;
String _$webCheckoutModeHash() => r'21d9e2ff1e214141e0c0f58f762b4f5cfa8dcebd';

/// 当前是否走「网页支付」渠道（侧载 APK / 桌面）。
///
/// Paywall 据此切换购买交互：true 时不展示商店套餐卡、改为「浏览器结账 + 回流对账」。
/// 测试可 override 模拟网页渠道。
///
/// Copied from [webCheckoutMode].
@ProviderFor(webCheckoutMode)
final webCheckoutModeProvider = AutoDisposeProvider<bool>.internal(
  webCheckoutMode,
  name: r'webCheckoutModeProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$webCheckoutModeHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef WebCheckoutModeRef = AutoDisposeProviderRef<bool>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
