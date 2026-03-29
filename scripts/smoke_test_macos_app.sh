#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="${ROOT_DIR}/apps/macos/WisprLocalMac/WisprLocalMac.xcodeproj"
SCHEME="WisprLocalMac"
DERIVED_DATA_PATH="${ROOT_DIR}/artifacts/mac/dev-deriveddata"
APP_PATH="${DERIVED_DATA_PATH}/Build/Products/Debug/WisprLocalMac.app"
APP_BINARY="${APP_PATH}/Contents/MacOS/WisprLocalMac"
APP_INFO_PLIST="${APP_PATH}/Contents/Info.plist"
RUNTIME_DIR="${APP_PATH}/Contents/Resources/Runtime"
FALLBACK_RUNTIME_DIR="${APP_PATH}/Contents/Resources"
LOG_PATH="${ROOT_DIR}/artifacts/mac/dev-run.log"
KEEP_RUNNING=0
SKIP_LAUNCH=0

log() {
  echo "[smoke_test_macos_app] $*"
}

error() {
  echo "[smoke_test_macos_app] ERROR: $*" >&2
  exit 1
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    error "Missing required tool '$1'"
  fi
}

print_xcodegen_preflight_help() {
  cat >&2 <<'EOF'
[smoke_test_macos_app] XcodeGen is required before the macOS smoke test can generate the Xcode project.
[smoke_test_macos_app] Install it first, for example:
[smoke_test_macos_app]   brew install xcodegen
[smoke_test_macos_app] If Homebrew is not available, install XcodeGen manually and ensure `xcodegen` is on your PATH.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --keep-running)
      KEEP_RUNNING=1
      shift
      ;;
    --skip-launch)
      SKIP_LAUNCH=1
      shift
      ;;
    *)
      error "Unknown argument: $1"
      ;;
  esac
done

require_command xcodebuild
require_command plutil
require_command pgrep

mkdir -p "${ROOT_DIR}/artifacts/mac"

log "Preparing runtime bundle"
"${ROOT_DIR}/scripts/prepare_runtime_bundle.sh"

log "Generating macOS Xcode project"
"${ROOT_DIR}/scripts/generate_macos_xcodeproj.sh" --check

if [[ -d "${DERIVED_DATA_PATH}" ]]; then
  log "Removing previous derived data"
  rm -rf "${DERIVED_DATA_PATH}"
fi

log "Building debug app"
xcodebuild \
  -project "${PROJECT_PATH}" \
  -scheme "${SCHEME}" \
  -configuration Debug \
  -derivedDataPath "${DERIVED_DATA_PATH}" \
  -destination "platform=macOS" \
  build

[[ -d "${APP_PATH}" ]] || error "Built app not found at ${APP_PATH}"
[[ -x "${APP_BINARY}" ]] || error "App binary missing at ${APP_BINARY}"
[[ -f "${APP_INFO_PLIST}" ]] || error "App Info.plist missing at ${APP_INFO_PLIST}"
if [[ -x "${RUNTIME_DIR}/whisper-cli" ]] && [[ -d "${RUNTIME_DIR}/models" ]]; then
  EFFECTIVE_RUNTIME_DIR="${RUNTIME_DIR}"
elif [[ -x "${FALLBACK_RUNTIME_DIR}/whisper-cli" ]] && [[ -d "${FALLBACK_RUNTIME_DIR}/models" ]]; then
  EFFECTIVE_RUNTIME_DIR="${FALLBACK_RUNTIME_DIR}"
else
  error "Bundled whisper-cli missing at ${RUNTIME_DIR}/whisper-cli and fallback ${FALLBACK_RUNTIME_DIR}/whisper-cli"
fi

MODEL_COUNT=$(find "${EFFECTIVE_RUNTIME_DIR}/models" -maxdepth 1 -type f -name '*.bin' | wc -l | tr -d ' ')
[[ "${MODEL_COUNT}" -ge 1 ]] || error "No bundled ggml model files found in ${RUNTIME_DIR}/models"

LSUIELEMENT=$(/usr/libexec/PlistBuddy -c "Print :LSUIElement" "${APP_INFO_PLIST}" 2>/dev/null || echo 0)
[[ "${LSUIELEMENT}" == "1" || "${LSUIELEMENT}" == "true" ]] || error "LSUIElement is not enabled. App would stay visible in Dock."

log "Info.plist summary"
plutil -p "${APP_INFO_PLIST}" | sed -n '1,80p'

if [[ "${SKIP_LAUNCH}" -eq 1 ]]; then
  log "Skipping app launch; build and bundle validation completed."
  exit 0
fi

log "Killing any previous WisprLocalMac process"
pkill -f "${APP_BINARY}" >/dev/null 2>&1 || true

log "Launching app binary"
rm -f "${LOG_PATH}"
"${APP_BINARY}" >"${LOG_PATH}" 2>&1 &
APP_PID=$!
sleep 4

if ! kill -0 "${APP_PID}" >/dev/null 2>&1; then
  echo "--- app log ---"
  cat "${LOG_PATH}" 2>/dev/null || true
  error "App process exited immediately."
fi

log "App process is running with pid ${APP_PID}"
log "Runtime resources verified:"
log "  CLI: ${EFFECTIVE_RUNTIME_DIR}/whisper-cli"
log "  Models: ${MODEL_COUNT}"
log "  Log: ${LOG_PATH}"

if [[ "${KEEP_RUNNING}" -eq 1 ]]; then
  log "Leaving app running."
  exit 0
fi

log "Stopping app process"
kill "${APP_PID}" >/dev/null 2>&1 || true
wait "${APP_PID}" 2>/dev/null || true
log "Smoke test completed."
