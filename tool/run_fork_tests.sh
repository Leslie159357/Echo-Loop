#!/usr/bin/env bash
# 运行德语版 fork 的测试集：全量 test/*_test.dart，减去 fork_test_exclusions.txt。
#
# 排除清单只收纳「产品行为刻意与上游不同」的用例，见清单内逐条原因。
set -euo pipefail

cd "$(dirname "$0")/.."

EXCLUSIONS="tool/fork_test_exclusions.txt"
[ -f "$EXCLUSIONS" ] || { echo "missing $EXCLUSIONS" >&2; exit 1; }

mapfile -t EXCLUDED < <(grep -v '^\s*#' "$EXCLUSIONS" | grep -v '^\s*$' | awk '{print $1}')
find test -name '*_test.dart' | sort > /tmp/all_tests.txt
printf '%s\n' "${EXCLUDED[@]}" | sort > /tmp/excluded_tests.txt
comm -23 /tmp/all_tests.txt /tmp/excluded_tests.txt > /tmp/fork_tests.txt

echo "fork test set: $(wc -l < /tmp/fork_tests.txt) files (excluded $(comm -12 /tmp/all_tests.txt /tmp/excluded_tests.txt | wc -l))"
mapfile -t FILES < /tmp/fork_tests.txt

exec flutter test "${FILES[@]}" --concurrency=1 "$@"
