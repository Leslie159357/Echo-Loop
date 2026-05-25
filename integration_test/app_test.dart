/// 集成测试全量入口
///
/// 一次性跑所有 group。CI 并行可改用 [shards/shard_*.dart] 拆分入口。
library;

import 'helpers/test_main_setup.dart';
import 'groups/blind_listen_tests.dart';
import 'groups/intensive_listen_tests.dart';
import 'groups/learning_flow_tests.dart';
import 'groups/tag_tests.dart';
import 'groups/stats_display_tests.dart';
import 'groups/retell_tests.dart';
import 'groups/review_sub_stage_tests.dart';
import 'groups/manage_subtitles_tests.dart';

void main() {
  setupIntegrationTestBinding();
  registerCommonSetUpAll();

  tagTests();
  blindListenTests();
  intensiveListenTests();
  learningFlowTests();
  statsDisplayTests();
  retellTests();
  reviewSubStageTests();
  manageSubtitlesTests();
}
