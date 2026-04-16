#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

log() {
  echo "[macos-release] $*"
}

fail() {
  echo "[macos-release] ERROR: $*" >&2
  exit 1
}

# 从 pubspec.yaml 读取版本号
RAW_VERSION="$(grep '^version:' pubspec.yaml | awk '{print $2}')"
[[ -n "$RAW_VERSION" ]] || fail "Unable to read version from pubspec.yaml"

VERSION="${RAW_VERSION%%+*}"
APP_NAME="Echo-Loop-${VERSION}-macos"

log "Version: $VERSION"
log "Output: build/release/$APP_NAME.dmg"

# 清理并构建
log "Cleaning..."
flutter clean

log "Building release app..."
flutter build macos --release --flavor=prod

# 找到 .app 产物
APP_PATH="build/macos/Build/Products/Release-prod/Echo Loop.app"
[[ -d "$APP_PATH" ]] || APP_PATH="$(find build/macos -name '*.app' -path '*/Release*/*' | head -1)"
[[ -d "$APP_PATH" ]] || fail ".app not found in build/macos"

# 打包为 DMG（经典拖拽安装界面）
command -v create-dmg >/dev/null 2>&1 || fail "Missing create-dmg. Install with: brew install create-dmg"

mkdir -p build/release
DMG_PATH="build/release/$APP_NAME.dmg"
ICON_PATH="macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png"

log "Creating DMG..."
rm -f "$DMG_PATH"

create-dmg \
  --volname "Echo Loop" \
  --volicon "$ICON_PATH" \
  --window-pos 200 120 \
  --window-size 520 280 \
  --icon-size 80 \
  --icon "Echo Loop.app" 130 140 \
  --app-drop-link 390 140 \
  "$DMG_PATH" \
  "$APP_PATH"

SIZE="$(du -h "$DMG_PATH" | cut -f1 | xargs)"
log "Done: $DMG_PATH ($SIZE)"
