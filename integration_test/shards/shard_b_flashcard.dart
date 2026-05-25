/// Shard B：统计 + 学习流
///
/// 包含：stats_display, learning_flow。
/// 注：flashcard_tests 整组已下沉到 test/screens/flashcard_screen_test.dart。
library;

import '../helpers/test_main_setup.dart';
import '../groups/stats_display_tests.dart';
import '../groups/learning_flow_tests.dart';

void main() {
  setupIntegrationTestBinding();
  registerCommonSetUpAll();

  statsDisplayTests();
  learningFlowTests();
}
