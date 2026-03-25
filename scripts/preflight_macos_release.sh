#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNTIME_DIR="${ROOT_DIR}/apps/macos/AppShell/Resources/Runtime"
PROJECT_FILE="${ROOT_DIR}/apps/macos/WisprLocalMac/WisprLocalMac.xcodeproj/project.pbxproj"
INFO_PLIST="${ROOT_DIR}/apps/macos/WisprLocalMac/WisprLocalMac-Info.plist"
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

validate_non_empty() {
  local name="$1"
  local value="$2"
  if [[ -z "${value}" ]]; then
    error "${name} ist nicht gesetzt."
  fi
}

require_command rg
require_command plutil

validate_non_empty "WISPR_LICENSE_PUBLIC_KEY_BASE64" "${WISPR_LICENSE_PUBLIC_KEY_BASE64:-}"
validate_non_empty "SPARKLE_FEED_URL" "${SPARKLE_FEED_URL:-}"
validate_non_empty "SPARKLE_PUBLIC_ED_KEY" "${SPARKLE_PUBLIC_ED_KEY:-}"

if ! printf '%s' "${WISPR_LICENSE_PUBLIC_KEY_BASE64}" | base64 --decode >/dev/null 2>&1; then
  error "WISPR_LICENSE_PUBLIC_KEY_BASE64 ist kein gültiges Base64."
fi

if [[ "${SPARKLE_FEED_URL}" != https://* ]]; then
  error "SPARKLE_FEED_URL muss mit https:// beginnen."
fi

log "Preparing runtime bundle"
"${ROOT_DIR}/scripts/prepare_runtime_bundle.sh"

[[ -x "${RUNTIME_DIR}/whisper-cli" ]] || error "Bundled whisper-cli fehlt unter ${RUNTIME_DIR}/whisper-cli"
MODEL_COUNT=$(find "${RUNTIME_DIR}/models" -maxdepth 1 -type f -name '*.bin' | wc -l | tr -d ' ')
[[ "${MODEL_COUNT}" -ge 1 ]] || error "Keine ggml-Modelle in ${RUNTIME_DIR}/models gefunden."

log "Regenerating macOS Xcode project with production variables"
"${ROOT_DIR}/scripts/generate_macos_xcodeproj.sh"

plutil -lint "${INFO_PLIST}" >/dev/null
rg -q 'SUPublicEDKey' "${INFO_PLIST}" || error "SUPublicEDKey fehlt in Info.plist"
rg -q 'SUFeedURL' "${INFO_PLIST}" || error "SUFeedURL fehlt in Info.plist"
rg -q 'WLMLicensePublicKeyBase64' "${INFO_PLIST}" || error "WLMLicensePublicKeyBase64 fehlt in Info.plist"
EXPECTED_VERSION_PATTERN="$(printf '%s' "${APP_VERSION}" | sed 's/\./\\./g')"
rg -q "MARKETING_VERSION = ${EXPECTED_VERSION_PATTERN};" "${PROJECT_FILE}" || error "MARKETING_VERSION im generierten Projekt entspricht nicht VERSION"

log "Preflight erfolgreich"
log "Runtime-Modelle: ${MODEL_COUNT}"
log "Nächste Schritte:"
log "  1. ./scripts/smoke_test_macos_app.sh --keep-running"
log "  2. ./scripts/archive_macos_release.sh"
log "  3. DEVELOPMENT_TEAM=... ./scripts/export_macos_release.sh"
log "  4. CODE_SIGN_IDENTITY=\"Developer ID Application: ...\" ./scripts/create_macos_dmg.sh"
