#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS_DIR="${ROOT_DIR}/artifacts/mac"
EXPORT_PATH="${EXPORT_PATH:-${ARTIFACTS_DIR}/release}"
APP_PATH="${APP_PATH:-${EXPORT_PATH}/Cortexa.app}"
DMG_PATH="${DMG_PATH:-${ARTIFACTS_DIR}/Cortexa.dmg}"
VOLUME_NAME="${DMG_VOLUME_NAME:-Cortexa}"

log() {
  echo "[create_macos_dmg] $*"
}

error() {
  echo "[create_macos_dmg] ERROR: $*" >&2
  exit 1
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    error "Missing required tool '$1'"
  fi
}

require_command hdiutil
require_command qlmanage

[[ -d "${APP_PATH}" ]] || error "App bundle not found at ${APP_PATH}. Run ./scripts/export_macos_release.sh first."

mkdir -p "${ARTIFACTS_DIR}"
rm -f "${DMG_PATH}"

TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/wisprlocal-dmg.XXXXXX")"
trap 'rm -rf "${TEMP_DIR}"' EXIT

BACKGROUND_SOURCE="${ROOT_DIR}/apps/macos/AppShell/Resources/Assets.xcassets/CortexaLogoHorizontal.imageset/CortexaLogoHorizontal.svg"
[[ -f "${BACKGROUND_SOURCE}" ]] || error "DMG background source is missing at ${BACKGROUND_SOURCE}"

STAGING_DIR="${TEMP_DIR}/staging"
MOUNT_POINT="/Volumes/${VOLUME_NAME}"
STAGING_DMG="${TEMP_DIR}/staging.dmg"
mkdir -p "${STAGING_DIR}/.background"

APP_SIZE_MB="$(du -sm "${APP_PATH}" | awk '{print $1}')"
DMG_SIZE_MB=$((APP_SIZE_MB + 128))

qlmanage -t -s 1600 -o "${TEMP_DIR}" "${BACKGROUND_SOURCE}" >/dev/null 2>&1
BACKGROUND_PNG="${TEMP_DIR}/CortexaLogoHorizontal.svg.png"
[[ -f "${BACKGROUND_PNG}" ]] || error "Could not render the DMG background image"
cp "${BACKGROUND_PNG}" "${STAGING_DIR}/.background/installation.png"
cp -R "${APP_PATH}" "${STAGING_DIR}/"
ln -s /Applications "${STAGING_DIR}/Applications"

hdiutil create -size "${DMG_SIZE_MB}m" -fs HFS+ -volname "${VOLUME_NAME}" -ov "${STAGING_DMG}" >/dev/null
hdiutil attach "${STAGING_DMG}" -noautoopen >/dev/null
cp -R "${STAGING_DIR}/." "${MOUNT_POINT}/"

osascript <<EOF
tell application "Finder"
    tell disk "${VOLUME_NAME}"
        open
        delay 2
        set installerWindow to container window
    end tell
    tell installerWindow
        set current view to icon view
        set toolbar visible to false
        set statusbar visible to false
        set bounds to {120, 120, 920, 620}
        set viewOptions to icon view options
        set position of item "Cortexa.app" to {190, 260}
        set position of item "Applications" to {610, 260}
        close
    end tell
end tell
EOF

hdiutil detach "${MOUNT_POINT}" -quiet

log "Creating DMG at ${DMG_PATH}"
hdiutil convert "${STAGING_DMG}" -format UDZO -o "${DMG_PATH}" >/dev/null

if [[ -n "${CODE_SIGN_IDENTITY:-}" ]]; then
  log "Signing DMG"
  codesign --force --sign "${CODE_SIGN_IDENTITY}" --timestamp "${DMG_PATH}"
fi

log "DMG created at ${DMG_PATH}"
