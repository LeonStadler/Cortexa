#!/usr/bin/env bash
set -euo pipefail

APP_PATH="${1:-}"

error() {
  echo "[validate_macos_app_runtime] ERROR: $*" >&2
  exit 1
}

command -v python3 >/dev/null 2>&1 || error "Missing required tool python3"

[[ -n "${APP_PATH}" ]] || error "Usage: $(basename "$0") /path/to/Cortexa.app"
[[ -d "${APP_PATH}" ]] || error "App bundle not found at ${APP_PATH}"

INFO_PLIST="${APP_PATH}/Contents/Info.plist"
APP_BINARY="${APP_PATH}/Contents/MacOS/Cortexa"
RESOURCES_DIR="${APP_PATH}/Contents/Resources"
[[ -f "${INFO_PLIST}" ]] || error "App Info.plist is missing at ${INFO_PLIST}"
[[ -x "${APP_BINARY}" ]] || error "Cortexa executable is missing at ${APP_BINARY}"

APP_ICON_NAME="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconName' "${INFO_PLIST}" 2>/dev/null || true)"
[[ "${APP_ICON_NAME}" == "Cortexa" ]] || error "Compiled app icon name is missing or incorrect in ${INFO_PLIST}; expected Cortexa. Build with Xcode 26 or later."
APP_ICON_FILE="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "${INFO_PLIST}" 2>/dev/null || true)"
[[ -n "${APP_ICON_FILE}" ]] || error "Compiled app icon file is missing in ${INFO_PLIST}."
if [[ "${APP_ICON_FILE}" != *.icns ]]; then
  APP_ICON_FILE="${APP_ICON_FILE}.icns"
fi
[[ -s "${RESOURCES_DIR}/${APP_ICON_FILE}" ]] || error "Compiled app icon is missing at ${RESOURCES_DIR}/${APP_ICON_FILE}."

command -v otool >/dev/null 2>&1 || error "Missing required tool otool"
FOUNDATION_MODELS_LINK="$(otool -L "${APP_BINARY}" | grep -F 'FoundationModels.framework/' || true)"
if [[ -z "${FOUNDATION_MODELS_LINK}" ]]; then
  otool -L "${APP_BINARY}" >&2
  error "Cortexa was built without FoundationModels.framework. Use the macOS 26 SDK or later."
fi
printf '[validate_macos_app_runtime] Foundation Models link verified: %s\n' "${FOUNDATION_MODELS_LINK}"

RUNTIME_DIR="${APP_PATH}/Contents/Resources/Runtime"
CLI_PATH="${RUNTIME_DIR}/whisper-cli"
MANIFEST_PATH="${RUNTIME_DIR}/runtime-manifest.json"
MODELS_DIR="${RUNTIME_DIR}/models"

[[ -d "${RUNTIME_DIR}" ]] || error "Bundled Runtime directory is missing at ${RUNTIME_DIR}"
[[ -x "${CLI_PATH}" ]] || error "Bundled whisper-cli is missing or not executable at ${CLI_PATH}"
[[ -d "${MODELS_DIR}" ]] || error "Bundled models directory is missing at ${MODELS_DIR}"
[[ -f "${MANIFEST_PATH}" ]] || error "Bundled runtime manifest is missing at ${MANIFEST_PATH}"

if ! python3 -m json.tool "${MANIFEST_PATH}" >/dev/null; then
  error "Bundled runtime manifest is not valid JSON at ${MANIFEST_PATH}"
fi

if ! "${CLI_PATH}" --help >/dev/null 2>&1; then
  error "Bundled whisper-cli could not start at ${CLI_PATH}"
fi

echo "[validate_macos_app_runtime] Runtime payload verified: ${RUNTIME_DIR}"
echo "[validate_macos_app_runtime] Compiled Cortexa.icns and FoundationModels.framework verified."
