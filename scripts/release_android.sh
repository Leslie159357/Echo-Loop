#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# 加载公共构建号函数
source scripts/lib/build_number.sh

log() {
  echo "[android-release] $*"
}

fail() {
  echo "[android-release] ERROR: $*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: scripts/release_android.sh [--flavor <dev|prod>] [--upload] [--skip-build] [--build-name NAME] [--build-number NUMBER] [-h|--help]

Build a release APK and optionally upload it to Cloudflare R2.

Options:
  --flavor <f>      Product flavor: dev or prod (default: prod).
  --upload          Upload the APK to R2 (default: skip upload).
  --skip-build      Skip the build step (use existing APK in build/release/).
  --build-name      Override version name (default: from pubspec.yaml).
  --build-number    Override build number (default: from git tag or 0).
  -h, --help        Show this help.

Environment variables:
  API_BASE_URL          API base URL (default: https://www.echo-loop.top)
  POSTHOG_API_KEY       PostHog API key (required for analytics)
  POSTHOG_HOST          PostHog host URL (default: https://us.i.posthog.com)

  Build (for CI/release scripts):
  ANDROID_BUILD_NAME    Version name override
  ANDROID_BUILD_NUMBER  Build number override

  R2 upload:
  R2_ENDPOINT           S3-compatible endpoint URL
  R2_ACCESS_KEY_ID      R2 API token access key ID
  R2_SECRET_ACCESS_KEY  R2 API token secret access key
  R2_BUCKET             R2 bucket name (default: public)
  R2_PUBLIC_URL         Public base URL for download links (default: https://cdn.echo-loop.top)
EOF
}

# --- 参数解析 ---
DO_UPLOAD=false
SKIP_BUILD=false
FLAVOR="prod"
BUILD_NAME=""
BUILD_NUMBER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --flavor)       FLAVOR="${2:-}"; shift 2 ;;
    --upload)       DO_UPLOAD=true; shift ;;
    --skip-build)   SKIP_BUILD=true; shift ;;
    --build-name)   BUILD_NAME="${2:-}"; shift 2 ;;
    --build-number) BUILD_NUMBER="${2:-}"; shift 2 ;;
    -h|--help)      usage; exit 0 ;;
    *)              fail "Unknown option: $1. Use -h for help." ;;
  esac
done

[[ "$FLAVOR" == "dev" || "$FLAVOR" == "prod" ]] || fail "Invalid --flavor: $FLAVOR (expected dev|prod)"

# --- 环境检查 ---
if [[ -z "${ANDROID_HOME:-}" ]]; then
  if [[ -d "$HOME/Android/Sdk" ]]; then
    export ANDROID_HOME="$HOME/Android/Sdk"
  elif [[ -d "$HOME/Android/sdk" ]]; then
    export ANDROID_HOME="$HOME/Android/sdk"
  else
    fail "ANDROID_HOME is not set and ~/Android/Sdk does not exist"
  fi
fi
export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/tools:$PATH"

API_BASE_URL="${API_BASE_URL:-https://www.echo-loop.top}"
POSTHOG_API_KEY="${POSTHOG_API_KEY:-}"
POSTHOG_HOST="${POSTHOG_HOST:-https://us.i.posthog.com}"

# 版本号来源优先级：命令行参数 > 环境变量 > 从 tag 解析
if [[ -z "$BUILD_NAME" ]]; then
  BUILD_NAME="${ANDROID_BUILD_NAME:-}"
fi
if [[ -z "$BUILD_NUMBER" ]]; then
  BUILD_NUMBER="${ANDROID_BUILD_NUMBER:-}"
fi

# 如果参数和环境变量都没提供，从当前 commit 的 tag 解析
if [[ -z "$BUILD_NAME" || -z "$BUILD_NUMBER" ]]; then
  TAG="$(git tag --points-at HEAD | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+[+][0-9]+$' | head -1 || true)"
  if [[ -z "$TAG" ]]; then
    fail "No version tag on current commit. Run ci.sh first, or provide --build-name and --build-number."
  fi
  log "Using tag: $TAG"
  eval "$(parse_tag "$TAG")"
fi

# 安装包名字统一包含构建号
VERSION="${BUILD_NAME}+${BUILD_NUMBER}"
ARCH="arm64"
APK_NAME="Echo-Loop-${VERSION}-${ARCH}.apk"
APK_PATH="build/release/$APK_NAME"

log "Version: $VERSION"
log "Build number: ${BUILD_NUMBER:-1}"
log "Architecture: $ARCH"
log "Flavor: $FLAVOR"
log "API base URL: $API_BASE_URL"
log "Output: $APK_PATH"

# --- 构建 ---
if [[ "$SKIP_BUILD" == false ]]; then
  log "Cleaning..."
  flutter clean

  log "Building release APK..."
  DART_DEFINES=(
    "--dart-define=API_BASE_URL=${API_BASE_URL}"
    "--dart-define=POSTHOG_HOST=${POSTHOG_HOST}"
  )
  # POSTHOG_API_KEY 为空时不传，让代码使用内置默认值
  [[ -n "${POSTHOG_API_KEY:-}" ]] && DART_DEFINES+=("--dart-define=POSTHOG_API_KEY=${POSTHOG_API_KEY}")

  FLUTTER_ARGS=(
    build
    apk
    --release
    "--flavor=$FLAVOR"
    --target-platform
    android-arm64
    # --build-name 只传版本号，不含构建号
    "--build-name=$BUILD_NAME"
  )
  # 仅当有构建号时才传 --build-number
  if [[ -n "${BUILD_NUMBER:-}" ]]; then
    FLUTTER_ARGS+=("--build-number=$BUILD_NUMBER")
  fi
  FLUTTER_ARGS+=("${DART_DEFINES[@]}")

  flutter "${FLUTTER_ARGS[@]}"

  SRC="build/app/outputs/flutter-apk/app-${FLAVOR}-release.apk"
  [[ -f "$SRC" ]] || fail "APK not found at $SRC"

  mkdir -p build/release
  cp "$SRC" "$APK_PATH"

  SIZE="$(du -h "$APK_PATH" | cut -f1 | xargs)"
  log "Build done: $APK_PATH ($SIZE)"
else
  log "Skipping build (--skip-build)"
  [[ -f "$APK_PATH" ]] || fail "APK not found at $APK_PATH. Run without --skip-build first."
fi

# --- 上传到 R2 ---
if [[ "$DO_UPLOAD" == false ]]; then
  log "APK ready (upload skipped). Use --upload to upload to R2."
  exit 0
fi

# 检查必要环境变量
: "${R2_ENDPOINT:?Set R2_ENDPOINT}"
R2_ACCESS_KEY_ID="${R2_ACCESS_KEY_ID:-$R2_ACCESS_KEY_ID_PUBLIC}"
R2_SECRET_ACCESS_KEY="${R2_SECRET_ACCESS_KEY:-$R2_SECRET_ACCESS_KEY_PUBLIC}"
: "${R2_ACCESS_KEY_ID:?Set R2_ACCESS_KEY_ID or R2_ACCESS_KEY_ID_PUBLIC}"
: "${R2_SECRET_ACCESS_KEY:?Set R2_SECRET_ACCESS_KEY or R2_SECRET_ACCESS_KEY_PUBLIC}"
R2_BUCKET="${R2_BUCKET:-public}"
R2_PUBLIC_URL="${R2_PUBLIC_URL:-https://cdn.echo-loop.top}"

command -v aws >/dev/null 2>&1 || fail "aws CLI not found. Install it first."

R2_KEY="android/$APK_NAME"
R2_LATEST_KEY="android/Echo-Loop-latest.apk"

log "Uploading to R2: s3://${R2_BUCKET}/${R2_KEY} ..."

AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY_ID" \
AWS_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY" \
aws s3 cp "$APK_PATH" "s3://${R2_BUCKET}/${R2_KEY}" \
  --endpoint-url "$R2_ENDPOINT" \
  --region auto \
  --content-type "application/vnd.android.package-archive"

log "Copying to latest: s3://${R2_BUCKET}/${R2_LATEST_KEY} ..."

AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY_ID" \
AWS_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY" \
aws s3 cp "$APK_PATH" "s3://${R2_BUCKET}/${R2_LATEST_KEY}" \
  --endpoint-url "$R2_ENDPOINT" \
  --region auto \
  --content-type "application/vnd.android.package-archive"

DOWNLOAD_URL="${R2_PUBLIC_URL%/}/${R2_LATEST_KEY}"
log "Upload done!"
log "Download URL: $DOWNLOAD_URL"


log "All done."
