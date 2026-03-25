#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS_DIR="${ROOT_DIR}/artifacts/mac"
RELEASE_DIR="${RELEASE_DIR:-${ARTIFACTS_DIR}/release}"
DOWNLOAD_DIR="${DOWNLOAD_DIR:-${ARTIFACTS_DIR}}"

log() {
  echo "[generate_sparkle_appcast] $*"
}

error() {
  echo "[generate_sparkle_appcast] ERROR: $*" >&2
  exit 1
}

find_generate_appcast() {
  if [[ -n "${SPARKLE_BIN_DIR:-}" && -x "${SPARKLE_BIN_DIR}/generate_appcast" ]]; then
    echo "${SPARKLE_BIN_DIR}/generate_appcast"
    return 0
  fi

  if command -v generate_appcast >/dev/null 2>&1; then
    command -v generate_appcast
    return 0
  fi

  return 1
}

GENERATE_APPCAST_BIN="$(find_generate_appcast || true)"
[[ -n "${GENERATE_APPCAST_BIN}" ]] || error "generate_appcast nicht gefunden. Setze SPARKLE_BIN_DIR oder installiere die Sparkle tools."

mkdir -p "${RELEASE_DIR}"
mkdir -p "${DOWNLOAD_DIR}"

if [[ ! -f "${DOWNLOAD_DIR}/WisprLocalMac.dmg" && ! -f "${DOWNLOAD_DIR}/WisprLocalMac.zip" ]]; then
  error "Kein Release-Artefakt gefunden. Erwartet wird WisprLocalMac.dmg oder WisprLocalMac.zip in ${DOWNLOAD_DIR}."
fi

log "Generating Sparkle appcast in ${RELEASE_DIR}"
"${GENERATE_APPCAST_BIN}" "${DOWNLOAD_DIR}" --ed-key-file "${SPARKLE_PRIVATE_KEY_FILE:?Setze SPARKLE_PRIVATE_KEY_FILE auf den Sparkle Private Key}"

log "Appcast generation complete"
