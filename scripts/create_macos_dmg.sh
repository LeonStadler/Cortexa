#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS_DIR="${ROOT_DIR}/artifacts/mac"
EXPORT_PATH="${EXPORT_PATH:-${ARTIFACTS_DIR}/release}"
APP_PATH="${APP_PATH:-${EXPORT_PATH}/Cortexa.app}"
DMG_PATH="${DMG_PATH:-${ARTIFACTS_DIR}/Cortexa.dmg}"
VOLUME_NAME="${DMG_VOLUME_NAME:-Cortexa}"
BACKGROUND_SOURCE="${ROOT_DIR}/apps/macos/AppShell/Resources/CortexaInstallerBackground.svg"

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
require_command osascript
require_command qlmanage

[[ -d "${APP_PATH}" ]] || error "App bundle not found at ${APP_PATH}. Run ./scripts/export_macos_release.sh first."
[[ -f "${BACKGROUND_SOURCE}" ]] || error "Installer background not found at ${BACKGROUND_SOURCE}."

mkdir -p "${ARTIFACTS_DIR}"
rm -f "${DMG_PATH}"

TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/wisprlocal-dmg.XXXXXX")"
trap 'rm -rf "${TEMP_DIR}"' EXIT

cp -R "${APP_PATH}" "${TEMP_DIR}/"
ln -s /Applications "${TEMP_DIR}/Applications"

mkdir -p "${TEMP_DIR}/.background"
qlmanage -t -s 1600 -o "${TEMP_DIR}" "${BACKGROUND_SOURCE}" >/dev/null 2>&1
BACKGROUND_PNG="${TEMP_DIR}/CortexaInstallerBackground.svg.png"
[[ -f "${BACKGROUND_PNG}" ]] || error "Could not render installer background."
mv "${BACKGROUND_PNG}" "${TEMP_DIR}/.background/installation.png"

RW_DMG_PATH="${ARTIFACTS_DIR}/.Cortexa-rw-$$.dmg"
MOUNT_POINT=""

log "Creating writable DMG staging image"
hdiutil create \
  -volname "${VOLUME_NAME}" \
  -srcfolder "${TEMP_DIR}" \
  -ov \
  -format UDRW \
  "${RW_DMG_PATH}"

ATTACH_OUTPUT="$(hdiutil attach "${RW_DMG_PATH}" -nobrowse -noautoopen)"
MOUNT_POINT="$(printf '%s\n' "${ATTACH_OUTPUT}" | awk '/\/Volumes\// {print $3; exit}')"
[[ -n "${MOUNT_POINT}" ]] || error "Could not determine the mounted DMG path."
detach_mount() {
  hdiutil detach "${MOUNT_POINT}" -quiet >/dev/null 2>&1 || true
}
trap 'detach_mount; rm -f "${RW_DMG_PATH}"; rm -rf "${TEMP_DIR}"' EXIT

osascript <<EOF
tell application "Finder"
    tell disk "${VOLUME_NAME}"
        open
        delay 1
        set installerWindow to container window
    end tell
    tell installerWindow
        set current view to icon view
        set toolbar visible to false
        set statusbar visible to false
        set bounds to {120, 120, 920, 620}
        set viewOptions to icon view options
        set background picture of icon view options of installerWindow to file ".background:installation.png"
        set position of item "Cortexa.app" to {190, 260}
        set position of item "Applications" to {610, 260}
        close
    end tell
end tell
EOF

detach_mount

log "Creating compressed DMG at ${DMG_PATH}"
hdiutil convert "${RW_DMG_PATH}" \
  -format UDZO \
  -ov \
  -o "${DMG_PATH}" >/dev/null

if [[ -n "${CODE_SIGN_IDENTITY:-}" ]]; then
  log "Signing DMG"
  codesign --force --sign "${CODE_SIGN_IDENTITY}" --timestamp "${DMG_PATH}"
fi

log "DMG created at ${DMG_PATH}"
