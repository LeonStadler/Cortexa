#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_DIR="${ROOT_DIR}/apps/macos/WisprLocalMac"
ARTIFACTS_DIR="${ROOT_DIR}/artifacts/mac"
ARCHIVE_PATH="${ARTIFACTS_DIR}/WisprLocalMac.xcarchive"
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
require_command xcodegen

mkdir -p "${ARTIFACTS_DIR}"

log "Preparing bundled runtime"
"${ROOT_DIR}/scripts/prepare_runtime_bundle.sh"

log "Regenerating macOS project"
"${ROOT_DIR}/scripts/generate_macos_xcodeproj.sh"

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

if [[ -n "${CODE_SIGN_IDENTITY:-}" ]]; then
  XCODE_ARGS+=("CODE_SIGN_IDENTITY=${CODE_SIGN_IDENTITY}")
fi

log "Archiving release build"
xcodebuild "${XCODE_ARGS[@]}"

log "Archive created at ${ARCHIVE_PATH}"
