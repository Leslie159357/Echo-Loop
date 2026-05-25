/// Shard C：盲听 + 字幕管理（13 个 case）
///
/// 包含：blind_listen, manage_subtitles。
/// 注：listen_and_repeat_tests 已删除（6 个 case 全为 skip）。
library;

import '../helpers/test_main_setup.dart';
import '../groups/blind_listen_tests.dart';
import '../groups/manage_subtitles_tests.dart';

void main() {
  setupIntegrationTestBinding();
  registerCommonSetUpAll();

  blindListenTests();
  manageSubtitlesTests();
}
