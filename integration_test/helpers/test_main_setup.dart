/// 集成测试入口公共 setup
///
/// 把 [app_test.dart] 中的 binding 初始化、analytics 预置抽出来，
/// 供全量入口和各 shard 入口共享，避免重复。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'test_notifiers.dart';

/// 初始化集成测试 binding。
///
/// 调用方：各 shard / 全量入口在 `main()` 顶部调用。
///
/// 历史尝试（已回退）：
/// - `framePolicy = benchmarkLive`：跳空闲帧，会导致 Riverpod async provider 更新后
///   widget 不被重绘，大量 case 因 widget 找不到而失败。
/// - `timeDilation = 0.01`：会触发每个 testWidgets 的 `debugAssertNoTimeDilation`
///   invariant 检查，且 tearDown 时机晚于该检查无法补救。
///
/// 唯一保留的提速措施：[safeSettle] 默认 timeout 从 5s 降到 3s（见 test_notifiers.dart）。
void setupIntegrationTestBinding() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
}

/// 注册全局 setUpAll 钩子（初始化 analytics、Showcase guideSeen 等）。
void registerCommonSetUpAll() {
  setUpAll(() async {
    await initTestAnalytics();
  });
}
