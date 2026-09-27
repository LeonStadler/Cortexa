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

require_command sips
require_command python3
require_command codesign

[[ -d "${APP_PATH}" ]] || error "App bundle not found at ${APP_PATH}. Run ./scripts/export_macos_release.sh first."
[[ -f "${BACKGROUND_SOURCE}" ]] || error "Installer background not found at ${BACKGROUND_SOURCE}."

log "Validating bundled runtime payload"
"${ROOT_DIR}/scripts/validate_macos_app_runtime.sh" "${APP_PATH}"

SIGNING_DETAILS="$(codesign -dvvv "${APP_PATH}" 2>&1)" || error "Could not inspect app signature at ${APP_PATH}."
if ! grep -Eq '^Authority=(Apple Development|Developer ID Application):' <<<"${SIGNING_DETAILS}"; then
  error "Refusing to package an ad-hoc or unsigned app. Build the app with a persistent Apple Development or Developer ID Application identity first."
fi
if grep -Eq '^TeamIdentifier=(not set)?$' <<<"${SIGNING_DETAILS}"; then
  error "Refusing to package an app without a TeamIdentifier; Privacy & Security grants may not survive replacement."
fi
codesign --verify --deep --strict "${APP_PATH}" || error "App signature verification failed at ${APP_PATH}."

mkdir -p "${ARTIFACTS_DIR}"
DMGBUILD_ENV="${ROOT_DIR}/.build/dmgbuild-venv"
DMGBUILD="${DMGBUILD_ENV}/bin/dmgbuild"

if [[ ! -x "${DMGBUILD}" ]]; then
  log "Preparing pinned dmgbuild environment"
  python3 -m venv "${DMGBUILD_ENV}"
  "${DMGBUILD_ENV}/bin/python" -m pip install --disable-pip-version-check -r "${ROOT_DIR}/scripts/requirements-macos-dmg.txt"
fi

TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/wisprlocal-dmg.XXXXXX")"
trap 'rm -rf "${TEMP_DIR}"' EXIT

mkdir -p "${TEMP_DIR}/.background"
BACKGROUND_PNG="${TEMP_DIR}/.background/installation.png"
sips -s format png "${BACKGROUND_SOURCE}" --out "${BACKGROUND_PNG}" >/dev/null
[[ -f "${BACKGROUND_PNG}" ]] || error "Could not render installer background."

log "Creating Finder-layout DMG at ${DMG_PATH}"
"${DMGBUILD}" \
  --settings "${ROOT_DIR}/scripts/macos_dmg_settings.py" \
  -D "app=${APP_PATH}" \
  -D "background=${BACKGROUND_PNG}" \
  "${VOLUME_NAME}" \
  "${DMG_PATH}"

if [[ -n "${CODE_SIGN_IDENTITY:-}" ]]; then
  log "Signing DMG"
  codesign --force --sign "${CODE_SIGN_IDENTITY}" --timestamp "${DMG_PATH}"
fi

log "DMG created at ${DMG_PATH}"
