#!/usr/bin/env bash
# Release：基于已有 tag 构建 + 上传
#
# 用法：scripts/release.sh [--platform <ios|android>]
#
# 流程：
# 1. 检查当前 commit 是否有版本 tag
# 2. 无 tag → 报错退出
# 3. 有 tag → 提取版本号和构建号
# 4. 构建 + 上传各平台

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# 加载公共函数
source scripts/lib/build_number.sh

log() {
  echo "[release] $*"
}

fail() {
  echo "[release] ERROR: $*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: scripts/release.sh [--platform <ios|android>]

基于已有 tag 构建 + 上传各平台。需先执行 ci.sh 打 tag。

Options:
  --platform  只发布指定平台（默认 ios + android）
  --help      显示帮助

Environment:
  API_BASE_URL        API base URL (default: https://www.echo-loop.top)
  POSTHOG_API_KEY     PostHog API key (required for analytics)
  POSTHOG_HOST        PostHog host URL (default: https://us.i.posthog.com)

  iOS upload:
  IOS_TEAM_ID
  APP_STORE_API_KEY_ID
  APP_STORE_API_ISSUER_ID
  APP_STORE_API_KEY_PATH

  Android R2 upload:
  R2_ENDPOINT
  R2_ACCESS_KEY_ID
  R2_SECRET_ACCESS_KEY
  R2_BUCKET
  R2_PUBLIC_URL
EOF
}

# 解析参数
PLATFORMS=("ios" "android")
while [[ $# -gt 0 ]]; do
  case "$1" in
    --platform)
      shift
      [[ $# -gt 0 ]] || fail "--platform requires a value"
      PLATFORMS=("$1")
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown option: $1. Use --help for usage."
      ;;
  esac
done

# 检查当前 commit 是否有版本 tag
EXISTING_TAG="$(git tag --points-at HEAD | grep -E '^v[0-9]+[.][0-9]+[.][0-9]+([+][0-9]+)?$' || true)"
if [[ -z "$EXISTING_TAG" ]]; then
  fail "No version tag on current commit. Run ci.sh first."
fi

# 提取版本号和构建号
eval "$(parse_tag "$EXISTING_TAG")"

log "Using tag: $EXISTING_TAG"
log "Build name: $BUILD_NAME"
log "Build number: ${BUILD_NUMBER:-0}"
log "Platforms: ${PLATFORMS[*]}"

# 环境变量
API_BASE_URL="${API_BASE_URL:-https://www.echo-loop.top}"
POSTHOG_API_KEY="${POSTHOG_API_KEY:-}"
POSTHOG_HOST="${POSTHOG_HOST:-https://us.i.posthog.com}"

# 发布各平台
FAILED=0
RELEASE_RESULTS=()

for PLATFORM in "${PLATFORMS[@]}"; do
  log "Releasing $PLATFORM..."
  case "$PLATFORM" in
    ios)
      export API_BASE_URL POSTHOG_API_KEY POSTHOG_HOST
      export IOS_BUILD_NAME="$BUILD_NAME"
      export IOS_BUILD_NUMBER="${BUILD_NUMBER:-}"
      if scripts/release_ios.sh --upload; then
        RELEASE_RESULTS+=("$PLATFORM: ✓")
        log "$PLATFORM release succeeded"
      else
        RELEASE_RESULTS+=("$PLATFORM: ✗")
        log "$PLATFORM release FAILED"
        FAILED=1
      fi
      ;;
    android)
      export API_BASE_URL POSTHOG_API_KEY POSTHOG_HOST
      export ANDROID_BUILD_NAME="$BUILD_NAME"
      export ANDROID_BUILD_NUMBER="${BUILD_NUMBER:-}"
      if scripts/release_android.sh --upload; then
        RELEASE_RESULTS+=("$PLATFORM: ✓")
        log "$PLATFORM release succeeded"
      else
        RELEASE_RESULTS+=("$PLATFORM: ✗")
        log "$PLATFORM release FAILED"
        FAILED=1
      fi
      ;;
    *)
      fail "Unknown platform: $PLATFORM"
      ;;
  esac
done

# 输出发布结果
log "Release results:"
for RESULT in "${RELEASE_RESULTS[@]}"; do
  log "  $RESULT"
done

if [[ $FAILED -eq 1 ]]; then
  fail "Release failed"
fi

log "Done"