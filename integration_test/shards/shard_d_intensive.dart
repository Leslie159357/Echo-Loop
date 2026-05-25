/// Shard D：精听 + 复述 + 复习子阶段（24 个 case，最重）
///
/// 包含：intensive_listen, retell, review_sub_stage。
library;

import '../helpers/test_main_setup.dart';
import '../groups/intensive_listen_tests.dart';
import '../groups/retell_tests.dart';
import '../groups/review_sub_stage_tests.dart';

void main() {
  setupIntegrationTestBinding();
  registerCommonSetUpAll();

  intensiveListenTests();
  retellTests();
  reviewSubStageTests();
}
