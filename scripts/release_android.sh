#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

log() {
  echo "[android-release] $*"
}

fail() {
  echo "[android-release] ERROR: $*" >&2
  exit 1
}

# 确保 ANDROID_HOME 已设置
if [[ -z "${ANDROID_HOME:-}" ]]; then
  if [[ -d "$HOME/Android/sdk" ]]; then
    export ANDROID_HOME="$HOME/Android/sdk"
  else
    fail "ANDROID_HOME is not set and ~/Android/sdk does not exist"
  fi
fi

# 从 pubspec.yaml 读取版本号
RAW_VERSION="$(grep '^version:' pubspec.yaml | awk '{print $2}')"
[[ -n "$RAW_VERSION" ]] || fail "Unable to read version from pubspec.yaml"

# 分离版本名和构建号（格式: 1.0.4 或 1.0.4+5）
VERSION="${RAW_VERSION%%+*}"
ARCH="arm64"
APK_NAME="Echo-Loop-${VERSION}-${ARCH}.apk"

log "Version: $VERSION"
log "Architecture: $ARCH"
log "Output: build/release/$APK_NAME"

# 清理并构建
log "Cleaning..."
flutter clean

log "Building release APK..."
flutter build apk --release --target-platform android-arm64

# 复制并重命名产物
SRC="build/app/outputs/flutter-apk/app-release.apk"
[[ -f "$SRC" ]] || fail "APK not found at $SRC"

mkdir -p build/release
cp "$SRC" "build/release/$APK_NAME"

SIZE="$(du -h "build/release/$APK_NAME" | cut -f1 | xargs)"
log "Done: build/release/$APK_NAME ($SIZE)"
