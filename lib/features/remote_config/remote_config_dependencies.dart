/// 共享远程配置服务与初始缓存的 Riverpod 依赖。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/package_info_provider.dart';
import '../../services/runtime_endpoint_router.dart';
import '../onboarding_survey/providers/onboarding_survey_provider.dart'
    show sharedPreferencesProvider;
import 'remote_config.dart';
import 'remote_config_service.dart';

/// 启动期可用同步读取的本地缓存覆盖默认配置。
final initialRemoteConfigProvider = Provider<RemoteConfig>(
  (ref) => RemoteConfig.defaults,
);

/// 启动地区解析和运行期刷新共用同一配置服务与缓存。
final remoteConfigServiceProvider = Provider<RemoteConfigService>((ref) {
  return RemoteConfigService.create(
    prefs: ref.watch(sharedPreferencesProvider),
    appVersion: readAppVersion(ref),
    endpointRouter: runtimeEndpointRouter,
  );
});
