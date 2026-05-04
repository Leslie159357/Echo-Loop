#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# 加载公共构建号函数
source scripts/lib/build_number.sh

log() {
  echo "[macos-release] $*"
}

fail() {
  echo "[macos-release] ERROR: $*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: scripts/release_macos.sh [--build-name NAME] [--build-number NUMBER] [-h|--help]

Build a macOS DMG for distribution.

Options:
  --build-name      Override version name (default: from pubspec.yaml).
  --build-number    Override build number (default: from git tag or 0).
  -h, --help        Show this help.

Environment variables (for CI/release scripts):
  MACOS_BUILD_NAME    Version name override
  MACOS_BUILD_NUMBER  Build number override
EOF
}

# 参数解析
BUILD_NAME=""
BUILD_NUMBER=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --build-name)   BUILD_NAME="${2:-}"; shift 2 ;;
    --build-number) BUILD_NUMBER="${2:-}"; shift 2 ;;
    -h|--help)      usage; exit 0 ;;
    *)              fail "Unknown option: $1. Use -h for help." ;;
  esac
done

# 构建号来源优先级：命令行参数 > 环境变量 > 自动计算
# 环境变量: MACOS_BUILD_NAME, MACOS_BUILD_NUMBER (兼容 ci.sh/release.sh)
if [[ -z "$BUILD_NAME" ]]; then
  BUILD_NAME="${MACOS_BUILD_NAME:-}"
fi
if [[ -z "$BUILD_NUMBER" ]]; then
  BUILD_NUMBER="${MACOS_BUILD_NUMBER:-}"
fi

# 计算版本号和构建号（如果命令行和环境变量都没提供）
if [[ -z "$BUILD_NAME" ]]; then
  BUILD_NAME="$(get_build_name)" || fail "Unable to read version from pubspec.yaml"
fi

if [[ -z "$BUILD_NUMBER" ]]; then
  calculate_build_number "$BUILD_NAME"
fi

VERSION="$BUILD_NAME"
APP_NAME="Echo-Loop-${VERSION}-macos"

log "Version: $VERSION"
log "Build number: ${BUILD_NUMBER:-0} (default)"
log "Output: build/release/$APP_NAME.dmg"

# 清理并构建
log "Cleaning..."
flutter clean

log "Building release app..."
FLUTTER_ARGS=(
  build macos --release
  "--flavor=prod"
  "--build-name=$VERSION"
)
if [[ -n "${BUILD_NUMBER:-}" ]]; then
  FLUTTER_ARGS+=("--build-number=$BUILD_NUMBER")
fi
flutter "${FLUTTER_ARGS[@]}"

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
