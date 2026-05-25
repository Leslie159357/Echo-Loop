#!/usr/bin/env bash
# 快速测试：仅跑 widget/unit test，不含集成测试。
#
# 用途：本地 pre-push、PR CI 必跑项。
# 预期耗时：≤90s（本地）/ ≤2min（CI）
#
# 用法：
#   scripts/test_fast.sh              # 全量 widget/unit test
#   scripts/test_fast.sh test/screens # 指定目录

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TEST_PATH="${1:-test/}"

echo "[test_fast] Running: flutter test $TEST_PATH"
flutter test "$TEST_PATH"
