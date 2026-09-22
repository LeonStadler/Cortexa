#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_DIR="${ROOT_DIR}/apps/macos/WisprLocalMac"
ARTIFACTS_DIR="${ROOT_DIR}/artifacts/mac"
ARCHIVE_PATH="${ARTIFACTS_DIR}/Cortexa.xcarchive"
SCHEME="WisprLocalMac"
PROJECT_FILE="${PROJECT_DIR}/WisprLocalMac.xcodeproj"

log() {
  echo "[archive_macos_release] $*"
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "[archive_macos_release] ERROR: missing required tool '$1'" >&2
    exit 1
  fi
}

require_command xcodebuild
require_command codesign

if [[ -z "${CODE_SIGN_IDENTITY:-}" || "${CODE_SIGN_IDENTITY}" == "-" ]]; then
  echo "[archive_macos_release] ERROR: a persistent CODE_SIGN_IDENTITY is required for an update archive." >&2
  echo "[archive_macos_release] ERROR: refusing to create an ad-hoc archive because macOS permission grants are tied to the signed app identity." >&2
  echo "[archive_macos_release] ERROR: use Apple Development for a local-only build or Developer ID Application for a distributable release." >&2
  exit 1
fi

mkdir -p "${ARTIFACTS_DIR}"

log "Preparing bundled runtime"
"${ROOT_DIR}/scripts/prepare_runtime_bundle.sh"

if command -v xcodegen >/dev/null 2>&1; then
  log "Regenerating macOS project"
  "${ROOT_DIR}/scripts/generate_macos_xcodeproj.sh"
else
  log "xcodegen missing; validating existing macOS project"
  "${ROOT_DIR}/scripts/generate_macos_xcodeproj.sh" --check
fi

if [[ -d "${ARCHIVE_PATH}" ]]; then
  log "Removing previous archive at ${ARCHIVE_PATH}"
  rm -rf "${ARCHIVE_PATH}"
fi

XCODE_ARGS=(
  -project "${PROJECT_FILE}"
  -scheme "${SCHEME}"
  -configuration Release
  -destination "generic/platform=macOS"
  -archivePath "${ARCHIVE_PATH}"
  archive
)

if [[ -n "${DEVELOPMENT_TEAM:-}" ]]; then
  XCODE_ARGS+=("DEVELOPMENT_TEAM=${DEVELOPMENT_TEAM}")
fi

# Xcode's automatic provisioning can reject a locally valid macOS certificate
# before it gets to the archive. Sign the final archived app explicitly below;
# this is the exact app that is subsequently validated and packaged.
XCODE_ARGS+=("CODE_SIGNING_ALLOWED=NO")

log "Archiving release build"
xcodebuild "${XCODE_ARGS[@]}"

ARCHIVED_APP_PATH="${ARCHIVE_PATH}/Products/Applications/Cortexa.app"
[[ -d "${ARCHIVED_APP_PATH}" ]] || {
  echo "[archive_macos_release] ERROR: archived app not found at ${ARCHIVED_APP_PATH}" >&2
  exit 1
}

log "Signing archived app with ${CODE_SIGN_IDENTITY}"
codesign --force --deep --options runtime --sign "${CODE_SIGN_IDENTITY}" "${ARCHIVED_APP_PATH}"

log "Validating bundled runtime payload"
"${ROOT_DIR}/scripts/validate_macos_app_runtime.sh" "${ARCHIVED_APP_PATH}"

SIGNING_DETAILS="$(codesign -dvvv "${ARCHIVED_APP_PATH}" 2>&1)"
if ! grep -Eq '^Authority=(Apple Development|Developer ID Application):' <<<"${SIGNING_DETAILS}"; then
  echo "[archive_macos_release] ERROR: archive is not signed by an Apple Development or Developer ID Application identity." >&2
  printf '%s\n' "${SIGNING_DETAILS}" >&2
  exit 1
fi

if grep -Eq '^TeamIdentifier=(not set)?$' <<<"${SIGNING_DETAILS}"; then
  echo "[archive_macos_release] ERROR: archive has no Apple TeamIdentifier; it cannot retain TCC permissions across updates." >&2
  printf '%s\n' "${SIGNING_DETAILS}" >&2
  exit 1
fi

codesign --verify --deep --strict --verbose=2 "${ARCHIVED_APP_PATH}"

log "Archive created at ${ARCHIVE_PATH}"
