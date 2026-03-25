#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS_DIR="${ROOT_DIR}/artifacts/mac"
EXPORT_PATH="${EXPORT_PATH:-${ARTIFACTS_DIR}/release}"
APP_PATH="${APP_PATH:-${EXPORT_PATH}/WisprLocalMac.app}"
DMG_PATH="${DMG_PATH:-${ARTIFACTS_DIR}/WisprLocalMac.dmg}"
VOLUME_NAME="${DMG_VOLUME_NAME:-WisprLocalMac}"

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

[[ -d "${APP_PATH}" ]] || error "App bundle not found at ${APP_PATH}. Run ./scripts/export_macos_release.sh first."

mkdir -p "${ARTIFACTS_DIR}"
rm -f "${DMG_PATH}"

TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/wisprlocal-dmg.XXXXXX")"
trap 'rm -rf "${TEMP_DIR}"' EXIT

cp -R "${APP_PATH}" "${TEMP_DIR}/"
ln -s /Applications "${TEMP_DIR}/Applications"

log "Creating DMG at ${DMG_PATH}"
hdiutil create \
  -volname "${VOLUME_NAME}" \
  -srcfolder "${TEMP_DIR}" \
  -ov \
  -format UDZO \
  "${DMG_PATH}"

if [[ -n "${CODE_SIGN_IDENTITY:-}" ]]; then
  log "Signing DMG"
  codesign --force --sign "${CODE_SIGN_IDENTITY}" --timestamp "${DMG_PATH}"
fi

log "DMG created at ${DMG_PATH}"
