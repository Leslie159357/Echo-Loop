#!/usr/bin/env bash
# CI 构建：构建所有平台验证，全部成功后打 tag
#
# 用法：scripts/ci.sh [--platform <ios|android|macos>]
#
# 流程：
# 1. 计算构建号（不打 tag）
# 2. 构建各平台（不上传）
# 3. 全部成功 → 打 tag
# 4. 任一失败 → 不打 tag，退出

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# 加载公共函数
source scripts/lib/build_number.sh

log() {
  echo "[ci] $*"
}

fail() {
  echo "[ci] ERROR: $*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: scripts/ci.sh [--platform <ios|android|macos>]

构建所有平台验证，全部成功后打 tag。

Options:
  --platform  只构建指定平台（默认全部）
  --help      显示帮助

Environment:
  API_BASE_URL        API base URL (default: https://www.echo-loop.top)
  POSTHOG_API_KEY     PostHog API key
  POSTHOG_HOST        PostHog host URL
EOF
}

# 解析参数
PLATFORMS=("ios" "android" "macos")
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

# 环境变量
API_BASE_URL="${API_BASE_URL:-https://www.echo-loop.top}"
POSTHOG_API_KEY="${POSTHOG_API_KEY:-}"
POSTHOG_HOST="${POSTHOG_HOST:-https://us.i.posthog.com}"

# 计算构建号
BUILD_NAME="$(get_build_name)" || fail "Failed to get build name"
calculate_build_number "$BUILD_NAME"

log "Build name: $BUILD_NAME"
log "Build number: ${BUILD_NUMBER:-1}"
log "Tag to create: $TAG_NAME"
log "Platforms: ${PLATFORMS[*]}"

if [[ $SKIP_TAG_CREATION -eq 1 ]]; then
  log "Current commit already has tag: $TAG_NAME, reusing"
fi

# 构建各平台（任一失败立即退出）
for PLATFORM in "${PLATFORMS[@]}"; do
  log "Building $PLATFORM..."
  case "$PLATFORM" in
    ios)
      export API_BASE_URL POSTHOG_API_KEY POSTHOG_HOST
      export IOS_BUILD_NAME="$BUILD_NAME"
      export IOS_BUILD_NUMBER="${BUILD_NUMBER:-}"
      if scripts/release_ios.sh; then
        log "$PLATFORM build succeeded"
      else
        fail "$PLATFORM build FAILED, not creating tag"
      fi
      ;;
    android)
      export API_BASE_URL POSTHOG_API_KEY POSTHOG_HOST
      export ANDROID_BUILD_NAME="$BUILD_NAME"
      export ANDROID_BUILD_NUMBER="${BUILD_NUMBER:-}"
      if scripts/release_android.sh; then
        log "$PLATFORM build succeeded"
      else
        fail "$PLATFORM build FAILED, not creating tag"
      fi
      ;;
    macos)
      export MACOS_BUILD_NAME="$BUILD_NAME"
      export MACOS_BUILD_NUMBER="${BUILD_NUMBER:-}"
      if scripts/release_macos.sh; then
        log "$PLATFORM build succeeded"
      else
        fail "$PLATFORM build FAILED, not creating tag"
      fi
      ;;
    *)
      fail "Unknown platform: $PLATFORM"
      ;;
  esac
done

log "All platforms built successfully"

# 全部成功，打 tag
if [[ $SKIP_TAG_CREATION -eq 0 ]]; then
  create_build_tag "$TAG_NAME" || fail "Failed to create tag"
  log "CI passed, tag created: $TAG_NAME"
else
  log "CI passed, tag already exists: $TAG_NAME"
fi

log "Done"