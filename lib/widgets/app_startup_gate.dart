/// 在启动依赖就绪前隐藏所有业务路由。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/user_region/user_region_providers.dart';
import '../providers/startup_bootstrap_provider.dart';
import 'startup_splash_screen.dart';

/// 本地数据和地区决策并行准备时展示品牌页，完成后挂载路由树。
class AppStartupGate extends ConsumerWidget {
  const AppStartupGate({
    required this.child,
    this.splashScreen = const StartupSplashScreen(),
    super.key,
  });

  final Widget child;
  final Widget splashScreen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localStartup = ref.watch(localStartupProvider);
    final userRegionStartup = ref.watch(userRegionBootstrapProvider);
    if (localStartup.isLoading || userRegionStartup.isLoading) {
      return splashScreen;
    }
    return child;
  }
}
