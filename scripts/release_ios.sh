#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

usage() {
  cat <<'EOF'
Usage: scripts/release_ios.sh [--wait] [--skip-upload] [--work-dir DIR] [--build-name NAME] [--build-number NUMBER]

Archive the iOS app, export or repackage an IPA, and upload it to App Store Connect.

Options:
  --wait         Wait for App Store Connect processing after upload.
  --skip-upload  Stop after generating the IPA.
  --work-dir     Override the temporary output directory.
  --build-name   Override CFBundleShortVersionString for this release.
  --build-number Override CFBundleVersion for this release.
  -h, --help     Show this help.

Environment overrides:
  IOS_WORKSPACE
  IOS_SCHEME
  IOS_CONFIGURATION
  IOS_TEAM_ID
  IOS_BUILD_NAME
  IOS_BUILD_NUMBER
  API_BASE_URL
  POSTHOG_API_KEY
  POSTHOG_HOST
  APP_STORE_API_KEY_ID
  APP_STORE_API_ISSUER_ID
  APP_STORE_API_KEY_PATH
EOF
}

log() {
  echo "[ios-release] $*"
}

fail() {
  echo "[ios-release] ERROR: $*" >&2
  exit 1
}

ensure_apple_toolchain_path() {
  # Xcode export 会调用带 Apple 扩展参数的 /usr/bin/rsync。
  # 若 PATH 前面命中了 Homebrew rsync，会在打包 IPA 时触发不兼容错误。
  export PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
}

encode_dart_define() {
  local result=""
  for arg in "$@"; do
    local encoded
    encoded="$(printf '%s' "$arg" | base64 | tr -d '\n')"
    result="${result:+$result,}$encoded"
  done
  printf '%s' "$result"
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    fail "Missing required command: $1"
  fi
}

find_latest_pipeline_dir() {
  local tmp_root="${TMPDIR:-/tmp}"

  find "$tmp_root" -maxdepth 1 -type d -name 'XcodeDistPipeline.*' -print 2>/dev/null \
    | while IFS= read -r dir; do
        printf '%s\t%s\n' "$(stat -f '%m' "$dir")" "$dir"
      done \
    | sort -nr \
    | head -n 1 \
    | cut -f2-
}

find_exported_ipa() {
  find "$EXPORT_DIR" -maxdepth 1 -type f -name '*.ipa' -print | head -n 1
}

package_from_pipeline() {
  local pipeline_dir="$1"
  local root_path="$pipeline_dir/Root"
  local app_path="$root_path/Payload/Runner.app"
  local signature

  [[ -d "$app_path" ]] || fail "Fallback payload not found: $app_path"

  signature="$(codesign -dv --verbose=4 "$app_path" 2>&1 || true)"
  if ! grep -Eq 'Authority=Apple Distribution' <<<"$signature"; then
    fail "Fallback payload is not distribution-signed"
  fi

  mkdir -p "$EXPORT_DIR"
  (
    cd "$root_path"
    /usr/bin/ditto -c -k --sequesterRsrc --keepParent Payload "$IPA_PATH"
  )
}

WAIT_FOR_PROCESSING=0
SKIP_UPLOAD=0
WORK_DIR=""
BUILD_NAME="${IOS_BUILD_NAME:-}"
BUILD_NUMBER="${IOS_BUILD_NUMBER:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --wait)
      WAIT_FOR_PROCESSING=1
      ;;
    --skip-upload)
      SKIP_UPLOAD=1
      ;;
    --work-dir)
      shift
      [[ $# -gt 0 ]] || fail "--work-dir requires a value"
      WORK_DIR="$1"
      ;;
    --build-name)
      shift
      [[ $# -gt 0 ]] || fail "--build-name requires a value"
      BUILD_NAME="$1"
      ;;
    --build-number)
      shift
      [[ $# -gt 0 ]] || fail "--build-number requires a value"
      BUILD_NUMBER="$1"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown argument: $1"
      ;;
  esac
  shift
done

require_command xcodebuild
require_command xcrun
require_command plutil
require_command codesign
require_command security
ensure_apple_toolchain_path

if [[ -x "scripts/preflight.sh" ]]; then
  scripts/preflight.sh
fi

WORKSPACE="${IOS_WORKSPACE:-ios/Runner.xcworkspace}"
SCHEME="${IOS_SCHEME:-Runner}"
CONFIGURATION="${IOS_CONFIGURATION:-Release}"
TEAM_ID="${IOS_TEAM_ID:-S8S968QAV3}"
API_BASE_URL="${API_BASE_URL:-https://www.echo-loop.top}"
POSTHOG_API_KEY="${POSTHOG_API_KEY:-}"
POSTHOG_HOST="${POSTHOG_HOST:-https://us.i.posthog.com}"
API_KEY_ID="${APP_STORE_API_KEY_ID:-5GB5KL75VZ}"
API_ISSUER_ID="${APP_STORE_API_ISSUER_ID:-3ec439fe-b66c-4034-b8c2-16e133fc4d6b}"
API_KEY_PATH="${APP_STORE_API_KEY_PATH:-$ROOT_DIR/ios/AuthKey_${API_KEY_ID}.p8}"
DART_DEFINES_VALUE="$(encode_dart_define "API_BASE_URL=${API_BASE_URL}" "POSTHOG_API_KEY=${POSTHOG_API_KEY}" "POSTHOG_HOST=${POSTHOG_HOST}")"

[[ -d "$WORKSPACE" ]] || fail "Workspace not found: $WORKSPACE"
[[ -f "$API_KEY_PATH" ]] || fail "API key file not found: $API_KEY_PATH"

VERSION_LINE="$(grep -n '^version:' pubspec.yaml || true)"
if [[ -n "$VERSION_LINE" ]]; then
  log "pubspec version: ${VERSION_LINE#*:}"
fi

RAW_VERSION="$(grep '^version:' pubspec.yaml | awk '{print $2}' || true)"
if [[ -z "$BUILD_NAME" ]]; then
  if [[ "$RAW_VERSION" == *"+"* ]]; then
    BUILD_NAME="${RAW_VERSION%%+*}"
  elif [[ -n "$RAW_VERSION" ]]; then
    BUILD_NAME="$RAW_VERSION"
  fi
fi

if [[ -z "$BUILD_NUMBER" ]]; then
  if [[ "$RAW_VERSION" == *"+"* ]]; then
    BUILD_NUMBER="${RAW_VERSION##*+}"
  else
    BUILD_NUMBER="$(date '+%Y%m%d%H%M')"
  fi
fi

[[ -n "$BUILD_NAME" ]] || fail "Unable to determine build name"
[[ -n "$BUILD_NUMBER" ]] || fail "Unable to determine build number"
log "Using build name: $BUILD_NAME"
log "Using build number: $BUILD_NUMBER"
log "Using API base URL: $API_BASE_URL"

log "Checking available code signing identities"
security find-identity -v -p codesigning

if [[ -z "$WORK_DIR" ]]; then
  WORK_DIR="/tmp/fluency-ios-release-$(date '+%Y%m%d-%H%M%S')"
fi

ARCHIVE_PATH="$WORK_DIR/Runner.xcarchive"
EXPORT_DIR="$WORK_DIR/export"
EXPORT_OPTIONS_PATH="$WORK_DIR/ExportOptions.plist"
IPA_PATH="$EXPORT_DIR/Runner.ipa"
UPLOAD_LOG="$WORK_DIR/upload.log"

mkdir -p "$WORK_DIR" "$EXPORT_DIR"

cat > "$EXPORT_OPTIONS_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>destination</key>
  <string>export</string>
  <key>manageAppVersionAndBuildNumber</key>
  <false/>
  <key>method</key>
  <string>app-store-connect</string>
  <key>signingStyle</key>
  <string>automatic</string>
  <key>stripSwiftSymbols</key>
  <true/>
  <key>teamID</key>
  <string>${TEAM_ID}</string>
  <key>uploadSymbols</key>
  <true/>
</dict>
</plist>
EOF

plutil -lint "$EXPORT_OPTIONS_PATH"

log "Syncing Flutter dependencies"
flutter pub get

log "Running pod install"
(cd ios && pod install --repo-update)

log "Archiving iOS app"
xcodebuild \
  -workspace "$WORKSPACE" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination generic/platform=iOS \
  -archivePath "$ARCHIVE_PATH" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$API_KEY_PATH" \
  -authenticationKeyID "$API_KEY_ID" \
  -authenticationKeyIssuerID "$API_ISSUER_ID" \
  DART_DEFINES="$DART_DEFINES_VALUE" \
  FLUTTER_BUILD_NAME="$BUILD_NAME" \
  FLUTTER_BUILD_NUMBER="$BUILD_NUMBER" \
  archive

log "Exporting IPA"
set +e
xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$EXPORT_OPTIONS_PATH" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$API_KEY_PATH" \
  -authenticationKeyID "$API_KEY_ID" \
  -authenticationKeyIssuerID "$API_ISSUER_ID" \
  DART_DEFINES="$DART_DEFINES_VALUE" \
  FLUTTER_BUILD_NAME="$BUILD_NAME" \
  FLUTTER_BUILD_NUMBER="$BUILD_NUMBER"
export_status=$?
set -e

if [[ $export_status -eq 0 ]]; then
  exported_ipa="$(find_exported_ipa)"
  [[ -n "$exported_ipa" ]] || fail "xcodebuild export succeeded but no IPA was found"
  IPA_PATH="$exported_ipa"
else
  log "Standard export failed, trying fallback packaging from XcodeDistPipeline"
  pipeline_dir="$(find_latest_pipeline_dir)"
  [[ -n "$pipeline_dir" ]] || fail "No XcodeDistPipeline directory found for fallback packaging"
  package_from_pipeline "$pipeline_dir"
fi

log "IPA ready: $IPA_PATH"
log "Artifacts kept in: $WORK_DIR"

# 复制到统一输出目录
RELEASE_DIR="$ROOT_DIR/build/release"
IPA_NAME="Echo-Loop-${BUILD_NAME}-ios.ipa"
mkdir -p "$RELEASE_DIR"
cp "$IPA_PATH" "$RELEASE_DIR/$IPA_NAME"
log "Copied to: build/release/$IPA_NAME"

if [[ $SKIP_UPLOAD -eq 1 ]]; then
  log "Skipping upload as requested"
  exit 0
fi

log "Uploading IPA to App Store Connect"
set +e
xcrun altool \
  --upload-app \
  --type ios \
  --file "$IPA_PATH" \
  --apiKey "$API_KEY_ID" \
  --apiIssuer "$API_ISSUER_ID" \
  --p8-file-path "$API_KEY_PATH" \
  --show-progress \
  2>&1 | tee "$UPLOAD_LOG"
upload_status=${PIPESTATUS[0]}
set -e

delivery_id="$(grep -Eo 'Delivery UUID: [0-9a-fA-F-]+' "$UPLOAD_LOG" | awk '{print $3}' | tail -n 1 || true)"
upload_succeeded=0
if grep -q 'Upload succeeded' "$UPLOAD_LOG"; then
  upload_succeeded=1
fi

if grep -q 'Failed to upload archive' "$UPLOAD_LOG"; then
  upload_succeeded=0
fi

if [[ $upload_status -ne 0 || $upload_succeeded -ne 1 ]]; then
  fail "Upload failed"
fi

if [[ -n "$delivery_id" ]]; then
  log "Delivery UUID: $delivery_id"
else
  log "Upload succeeded, but Delivery UUID was not parsed automatically"
fi

if [[ $WAIT_FOR_PROCESSING -eq 1 ]]; then
  [[ -n "$delivery_id" ]] || fail "Cannot wait for processing without a Delivery UUID"
  log "Waiting for App Store Connect processing"
  xcrun altool \
    --build-status \
    --delivery-id "$delivery_id" \
    --apiKey "$API_KEY_ID" \
    --apiIssuer "$API_ISSUER_ID" \
    --p8-file-path "$API_KEY_PATH" \
    --wait
fi

log "Done"
