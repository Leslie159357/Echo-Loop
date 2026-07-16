/// 平台订阅管理入口。
///
/// 原生商店订阅不应当像普通网页一样打开：Apple 优先请求系统订阅管理页，
/// Google Play 优先打开 Play Store 订阅页；只有平台入口不可用时才回退 HTTPS。
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/client_distribution.dart';
import '../../../config/revenuecat_config.dart';
import '../../../services/app_logger.dart';

/// URL 打开函数，供测试注入。
typedef SubscriptionUrlLauncher =
    Future<bool> Function(Uri uri, LaunchMode mode);

/// 当前可用的订阅管理入口。
class SubscriptionManagementLauncher {
  SubscriptionManagementLauncher({
    SubscriptionUrlLauncher? launchUrl,
    MethodChannel? channel,
    Future<PackageInfo> Function()? packageInfoLoader,
  }) : _launchUrl = launchUrl ?? _defaultLaunchUrl,
       _channel = channel ?? _defaultChannel,
       _packageInfoLoader = packageInfoLoader ?? PackageInfo.fromPlatform;

  static const _defaultChannel = MethodChannel(
    'top.echo-loop/subscription_management',
  );

  final SubscriptionUrlLauncher _launchUrl;
  final MethodChannel _channel;
  final Future<PackageInfo> Function() _packageInfoLoader;

  /// 打开当前渠道的订阅管理页。
  ///
  /// 返回 false 表示没有可用入口或全部打开失败；调用方负责显示失败提示。
  Future<bool> open({
    required ClientPaymentChannel channel,
    String? productId,
  }) async {
    return switch (channel) {
      ClientPaymentChannel.appleStore => _openApple(),
      ClientPaymentChannel.googlePlay => _openGooglePlay(productId),
      ClientPaymentChannel.web => _openWebManage(),
      ClientPaymentChannel.unavailable => Future<bool>.value(false),
    };
  }

  Future<bool> _openApple() async {
    if (!kIsWeb && Platform.isIOS) {
      try {
        final opened = await _channel.invokeMethod<bool>(
          'openManageSubscriptions',
        );
        if (opened == true) return true;
      } catch (e) {
        AppLogger.log('Subscription', 'Apple 原生订阅管理页打开失败，回退 URL: $e');
      }
    }
    final url = manageSubscriptionsUrlForChannel(
      ClientPaymentChannel.appleStore,
      webManageUrl: '',
    );
    return _openUri(url == null ? null : Uri.parse(url));
  }

  Future<bool> _openGooglePlay(String? productId) async {
    if (kIsWeb || !Platform.isAndroid) return false;
    final packageName = (await _packageInfoLoader()).packageName;
    final uris = googlePlaySubscriptionManagementUris(
      packageName: packageName,
      productId: productId,
    );
    for (final uri in uris) {
      if (await _openUri(uri)) return true;
    }
    return false;
  }

  Future<bool> _openWebManage() async {
    final url = manageSubscriptionsUrlForChannel(
      ClientPaymentChannel.web,
      webManageUrl: webManageUrl,
    );
    return _openUri(url == null ? null : Uri.parse(url));
  }

  Future<bool> _openUri(Uri? uri) async {
    if (uri == null) return false;
    try {
      return await _launchUrl(uri, LaunchMode.externalApplication);
    } catch (e) {
      AppLogger.log('Subscription', '订阅管理 URL 打开失败: uri=$uri error=$e');
      return false;
    }
  }
}

Future<bool> _defaultLaunchUrl(Uri uri, LaunchMode mode) {
  return launchUrl(uri, mode: mode);
}

/// Google Play 订阅管理入口候选 URL。
///
/// 有商品 ID 时优先打开当前订阅详情；没有商品 ID 时打开订阅列表。
@visibleForTesting
List<Uri> googlePlaySubscriptionManagementUris({
  required String packageName,
  String? productId,
}) {
  final hasProduct = productId != null && productId.isNotEmpty;
  if (!hasProduct) {
    return [
      Uri.parse('market://subscriptions'),
      Uri.parse('https://play.google.com/store/account/subscriptions'),
    ];
  }
  final query = {'sku': productId, 'package': packageName};
  return [
    Uri(scheme: 'market', host: 'subscriptions', queryParameters: query),
    Uri.https('play.google.com', '/store/account/subscriptions', query),
  ];
}
