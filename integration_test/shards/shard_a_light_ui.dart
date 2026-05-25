/// Shard A：标签管理（轻量 UI）
///
/// 包含：tag。
///
/// 注：已下沉到 widget test 的 group：
/// settings, collection, retell_toggle, flashcard, audio_pin,
/// learning_plan, pause_resume, navigation。
///
/// 用途：CI 并行 / 本地按子集快速验证。
library;

import '../helpers/test_main_setup.dart';
import '../groups/tag_tests.dart';

void main() {
  setupIntegrationTestBinding();
  registerCommonSetUpAll();

  tagTests();
}
