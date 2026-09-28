#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNTIME_DIR="${ROOT_DIR}/apps/macos/AppShell/Resources/Runtime"
PROJECT_FILE="${ROOT_DIR}/apps/macos/WisprLocalMac/WisprLocalMac.xcodeproj/project.pbxproj"
INFO_PLIST="${ROOT_DIR}/apps/macos/WisprLocalMac/WisprLocalMac-Info.plist"
ICON_COMPOSER_FILE="${ROOT_DIR}/apps/macos/AppShell/Resources/Cortexa.icon/icon.json"
APP_VERSION="$(cat "${ROOT_DIR}/VERSION")"

log() {
  echo "[preflight_macos_release] $*"
}

error() {
  echo "[preflight_macos_release] ERROR: $*" >&2
  exit 1
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    error "Missing required tool '$1'"
  fi
}

require_pattern() {
  local pattern="$1"
  local path="$2"
  local message="$3"

  if ! grep -Eq "${pattern}" "${path}"; then
    error "${message}"
  fi
}

validate_non_empty() {
  local name="$1"
  local value="$2"
  if [[ -z "${value}" ]]; then
    error "${name} ist nicht gesetzt."
  fi
}

require_command plutil
require_command git
require_command grep

"${ROOT_DIR}/scripts/verify_macos_release_sdk.sh"

validate_non_empty "SPARKLE_FEED_URL" "${SPARKLE_FEED_URL:-}"
validate_non_empty "SPARKLE_PUBLIC_ED_KEY" "${SPARKLE_PUBLIC_ED_KEY:-}"

if [[ "${SPARKLE_FEED_URL}" != https://* ]]; then
  error "SPARKLE_FEED_URL muss mit https:// beginnen."
fi

log "Preparing runtime bundle"
"${ROOT_DIR}/scripts/prepare_runtime_bundle.sh"

[[ -x "${RUNTIME_DIR}/whisper-cli" ]] || error "Bundled whisper-cli fehlt unter ${RUNTIME_DIR}/whisper-cli"
[[ -f "${RUNTIME_DIR}/runtime-manifest.json" ]] || error "runtime-manifest.json fehlt unter ${RUNTIME_DIR}"
MODEL_COUNT=$(find "${RUNTIME_DIR}/models" -maxdepth 1 -type f -name '*.bin' 2>/dev/null | wc -l | tr -d ' ')
[[ "${MODEL_COUNT}" -eq 0 ]] || error "Release erwartet keine gebündelten .bin-Modelle in ${RUNTIME_DIR}/models, gefunden: ${MODEL_COUNT}"

log "Regenerating macOS Xcode project with production variables"
"${ROOT_DIR}/scripts/generate_macos_xcodeproj.sh" --check

plutil -lint "${INFO_PLIST}" >/dev/null
require_pattern 'SUPublicEDKey' "${INFO_PLIST}" "SUPublicEDKey fehlt in Info.plist"
require_pattern 'SUFeedURL' "${INFO_PLIST}" "SUFeedURL fehlt in Info.plist"
EXPECTED_VERSION_PATTERN="$(printf '%s' "${APP_VERSION}" | sed 's/\./\\./g')"
require_pattern "MARKETING_VERSION = ${EXPECTED_VERSION_PATTERN};" "${PROJECT_FILE}" "MARKETING_VERSION im generierten Projekt entspricht nicht VERSION"
EXPECTED_BUILD_NUMBER="$(printf '%s' "${APP_VERSION}" | tr -cd '0-9' | sed 's/^0*//')"
if [[ -z "${EXPECTED_BUILD_NUMBER}" ]]; then
  EXPECTED_BUILD_NUMBER="1"
fi
require_pattern "CURRENT_PROJECT_VERSION = ${EXPECTED_BUILD_NUMBER};" "${PROJECT_FILE}" "CURRENT_PROJECT_VERSION im generierten Projekt entspricht nicht VERSION"
require_pattern 'Assets\.xcassets' "${PROJECT_FILE}" "Asset-Katalog fehlt im generierten Projekt"
[[ -f "${ICON_COMPOSER_FILE}" ]] || error "Cortexa.icon fehlt unter ${ICON_COMPOSER_FILE}"
require_pattern '"fill"[[:space:]]*:[[:space:]]*"automatic"' "${ICON_COMPOSER_FILE}" "Cortexa.icon ist nicht auf automatische Appearance-Darstellung gesetzt"
require_pattern '"translucency"' "${ICON_COMPOSER_FILE}" "Cortexa.icon enthält keine Translucency-Konfiguration"
require_pattern '"hidden-specializations"' "${ICON_COMPOSER_FILE}" "Cortexa.icon enthält keine Dark-Appearance-Glyph-Variante"
require_pattern 'Logo 5 Dark\.svg' "${ICON_COMPOSER_FILE}" "Cortexa.icon referenziert keine helle Dark-Appearance-Glyph"

log "Preflight erfolgreich"
log "Runtime-Modelle: ${MODEL_COUNT}"
log "Nächste Schritte:"
log "  1. ./scripts/smoke_test_macos_app.sh --keep-running"
log "  2. DEVELOPMENT_TEAM=... CODE_SIGN_IDENTITY=\"Developer ID Application\" ./scripts/archive_macos_release.sh"
log "  3. DEVELOPMENT_TEAM=... ./scripts/export_macos_release.sh"
log "  4. CODE_SIGN_IDENTITY=\"Developer ID Application: ...\" ./scripts/create_macos_dmg.sh"
