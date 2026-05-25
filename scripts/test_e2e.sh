#!/usr/bin/env bash
# 端到端测试：跑集成测试（需要 macOS runner / 模拟器）。
#
# 用途：PR 加 label e2e 时、nightly/release 全量验证。
# 预期耗时：≤3min（55 cases）
#
# 用法：
#   scripts/test_e2e.sh                              # 全量集成测试
#   scripts/test_e2e.sh --name "流程 1"               # 按名称过滤

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

DEVICE="${INTEGRATION_TEST_DEVICE:-macos}"

echo "[test_e2e] Running integration tests on $DEVICE..."

if [[ $# -gt 0 ]]; then
  flutter test integration_test/app_test.dart -d "$DEVICE" "$@"
else
  flutter test integration_test/app_test.dart -d "$DEVICE"
fi
