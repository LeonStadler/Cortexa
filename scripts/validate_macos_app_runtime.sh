#!/usr/bin/env bash
set -euo pipefail

APP_PATH="${1:-}"

error() {
  echo "[validate_macos_app_runtime] ERROR: $*" >&2
  exit 1
}

command -v jq >/dev/null 2>&1 || error "Missing required tool jq"

[[ -n "${APP_PATH}" ]] || error "Usage: $(basename "$0") /path/to/Cortexa.app"
[[ -d "${APP_PATH}" ]] || error "App bundle not found at ${APP_PATH}"

RUNTIME_DIR="${APP_PATH}/Contents/Resources/Runtime"
CLI_PATH="${RUNTIME_DIR}/whisper-cli"
MANIFEST_PATH="${RUNTIME_DIR}/runtime-manifest.json"
MODELS_DIR="${RUNTIME_DIR}/models"

[[ -d "${RUNTIME_DIR}" ]] || error "Bundled Runtime directory is missing at ${RUNTIME_DIR}"
[[ -x "${CLI_PATH}" ]] || error "Bundled whisper-cli is missing or not executable at ${CLI_PATH}"
[[ -d "${MODELS_DIR}" ]] || error "Bundled models directory is missing at ${MODELS_DIR}"
[[ -f "${MANIFEST_PATH}" ]] || error "Bundled runtime manifest is missing at ${MANIFEST_PATH}"

if ! jq empty "${MANIFEST_PATH}" >/dev/null; then
  error "Bundled runtime manifest is not valid JSON at ${MANIFEST_PATH}"
fi

if ! "${CLI_PATH}" --help >/dev/null 2>&1; then
  error "Bundled whisper-cli could not start at ${CLI_PATH}"
fi

echo "[validate_macos_app_runtime] Runtime payload verified: ${RUNTIME_DIR}"
