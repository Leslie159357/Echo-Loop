/// Direct 渠道 Paddle 配置。
library;

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'client_distribution.dart';
import 'api_config.dart';

@visibleForTesting
bool? debugIsPaddleCheckoutChannelOverride;

/// direct 构建使用后端 Paddle API；Play/App Store 构建不会进入该分支。
bool get isPaddleCheckoutConfigured =>
    isPaddleCheckoutChannel && apiBaseUrl.trim().isNotEmpty;

bool get isPaddleCheckoutChannel {
  final override = debugIsPaddleCheckoutChannelOverride;
  if (override != null) return override;
  return clientPaymentChannel == ClientPaymentChannel.web;
}
