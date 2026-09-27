#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="${ROOT_DIR}/apps/macos/WisprLocalMac/WisprLocalMac.xcodeproj"
SCHEME="WisprLocalMac"
DERIVED_DATA_PATH="${ROOT_DIR}/artifacts/mac/dev-deriveddata"
APP_PATH="${DERIVED_DATA_PATH}/Build/Products/Debug/Cortexa.app"
APP_BINARY="${APP_PATH}/Contents/MacOS/Cortexa"
APP_INFO_PLIST="${APP_PATH}/Contents/Info.plist"
RUNTIME_DIR="${APP_PATH}/Contents/Resources/Runtime"
FALLBACK_RUNTIME_DIR="${APP_PATH}/Contents/Resources"
LOG_PATH="${ROOT_DIR}/artifacts/mac/dev-run.log"
SIGNING_ARTIFACT_DIR="${ROOT_DIR}/artifacts/mac/signing"
CURRENT_SIGNING_SUMMARY="${SIGNING_ARTIFACT_DIR}/debug-signing.current.txt"
CURRENT_SIGNING_RAW="${SIGNING_ARTIFACT_DIR}/debug-signing.current.raw.txt"
PREVIOUS_SIGNING_SUMMARY="${SIGNING_ARTIFACT_DIR}/debug-signing.previous.txt"
PREVIOUS_SIGNING_RAW="${SIGNING_ARTIFACT_DIR}/debug-signing.previous.raw.txt"
KEEP_RUNNING=0
SKIP_LAUNCH=0
SKIP_BUILD=0
EXERCISE_UI=1

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
    --skip-build)
      SKIP_BUILD=1
      shift
      ;;
    --no-ui)
      EXERCISE_UI=0
      shift
      ;;
    *)
      error "Unknown argument: $1"
      ;;
  esac
done

require_command xcodebuild
require_command codesign
require_command plutil
require_command pgrep

mkdir -p "${ROOT_DIR}/artifacts/mac"
mkdir -p "${SIGNING_ARTIFACT_DIR}"

log "Preparing runtime bundle (dev/smoke with default model)"
"${ROOT_DIR}/scripts/prepare_runtime_bundle.sh" --include-default-model

log "Generating macOS Xcode project"
"${ROOT_DIR}/scripts/generate_macos_xcodeproj.sh" --check

if [[ "${SKIP_BUILD}" -eq 0 ]]; then
  if [[ -d "${DERIVED_DATA_PATH}" ]]; then
    log "Removing previous derived data"
    if ! rm -rf "${DERIVED_DATA_PATH}" 2>/dev/null; then
      STALE_DERIVED_DATA_PATH="${DERIVED_DATA_PATH}.stale.$(date +%Y%m%d%H%M%S)"
      log "Previous derived data is still busy; moving it aside to ${STALE_DERIVED_DATA_PATH}"
      mv "${DERIVED_DATA_PATH}" "${STALE_DERIVED_DATA_PATH}"
      rm -rf "${STALE_DERIVED_DATA_PATH}" 2>/dev/null || true
    fi
  fi

  log "Building debug app"
  xcodebuild \
    -project "${PROJECT_PATH}" \
    -scheme "${SCHEME}" \
    -configuration Debug \
    -derivedDataPath "${DERIVED_DATA_PATH}" \
    -destination "platform=macOS" \
    build

  # Prevent Spotlight from indexing rapidly changing build artifacts.
  touch "${DERIVED_DATA_PATH}/.metadata_never_index"
else
  log "Skipping build (--skip-build); reusing existing app at ${APP_PATH}"
  [[ -d "${APP_PATH}" ]] || error "No built app at ${APP_PATH}. Run without --skip-build first."
fi

[[ -d "${APP_PATH}" ]] || error "Built app not found at ${APP_PATH}"
[[ -x "${APP_BINARY}" ]] || error "App binary missing at ${APP_BINARY}"
[[ -f "${APP_INFO_PLIST}" ]] || error "App Info.plist missing at ${APP_INFO_PLIST}"
"${ROOT_DIR}/scripts/validate_macos_app_runtime.sh" "${APP_PATH}"
if [[ -x "${RUNTIME_DIR}/whisper-cli" ]] && [[ -d "${RUNTIME_DIR}/models" ]]; then
  EFFECTIVE_RUNTIME_DIR="${RUNTIME_DIR}"
elif [[ -x "${FALLBACK_RUNTIME_DIR}/whisper-cli" ]] && [[ -d "${FALLBACK_RUNTIME_DIR}/models" ]]; then
  EFFECTIVE_RUNTIME_DIR="${FALLBACK_RUNTIME_DIR}"
else
  error "Bundled whisper-cli missing at ${RUNTIME_DIR}/whisper-cli and fallback ${FALLBACK_RUNTIME_DIR}/whisper-cli"
fi

MODEL_COUNT=$(find "${EFFECTIVE_RUNTIME_DIR}/models" -maxdepth 1 -type f -name '*.bin' | wc -l | tr -d ' ')
[[ "${MODEL_COUNT}" -ge 1 ]] || error "No bundled ggml model files found in ${RUNTIME_DIR}/models"

DEFAULT_MODEL_PATH="${EFFECTIVE_RUNTIME_DIR}/models/ggml-base.bin"
[[ -f "${DEFAULT_MODEL_PATH}" ]] || error "Bundled default model missing at ${DEFAULT_MODEL_PATH}"

log "Running bundled whisper-cli transcription E2E"
"${ROOT_DIR}/scripts/verify_whisper_cli_runtime.sh" \
  "${EFFECTIVE_RUNTIME_DIR}/whisper-cli" \
  "${DEFAULT_MODEL_PATH}"

LSUIELEMENT=$(/usr/libexec/PlistBuddy -c "Print :LSUIElement" "${APP_INFO_PLIST}" 2>/dev/null || echo 0)
[[ "${LSUIELEMENT}" == "1" || "${LSUIELEMENT}" == "true" ]] || error "LSUIElement is not enabled. App would stay visible in Dock."

log "Info.plist summary"
plutil -p "${APP_INFO_PLIST}" | sed -n '1,80p'
log "Capturing signing identity snapshot"
if [[ -f "${CURRENT_SIGNING_SUMMARY}" ]]; then
  cp "${CURRENT_SIGNING_SUMMARY}" "${PREVIOUS_SIGNING_SUMMARY}"
fi
if [[ -f "${CURRENT_SIGNING_RAW}" ]]; then
  cp "${CURRENT_SIGNING_RAW}" "${PREVIOUS_SIGNING_RAW}"
fi

set +e
codesign -dvvv -r- "${APP_PATH}" >"${CURRENT_SIGNING_RAW}" 2>&1
CODESIGN_STATUS=$?
set -e

extract_signing_value() {
  local prefix="$1"
  local file_path="$2"
  sed -n "s/^${prefix}=//p" "${file_path}" | head -n 1 | tr -d '\r'
}

extract_designated_requirement() {
  local file_path="$1"
  awk '
    /^designated[[:space:]]*=>/ {
      capturing=1
      line=$0
      sub(/^designated[[:space:]]*=>[[:space:]]*/, "", line)
      if (line != "") {
        captured = captured (captured == "" ? "" : " ") line
      }
      next
    }
    /^Designated Requirement:/ {
      capturing=1
      next
    }
    capturing && /^[[:space:]]+/ {
      line=$0
      sub(/^[[:space:]]+/, "", line)
      if (line != "") {
        captured = captured (captured == "" ? "" : " ") line
      }
      next
    }
    capturing && NF == 0 {
      exit
    }
    END {
      if (captured != "") {
        print captured
      }
    }
  ' "${file_path}" | tr -d '\r'
}

if [[ "${CODESIGN_STATUS}" -ne 0 ]]; then
  log "codesign output:"
  sed -n '1,120p' "${CURRENT_SIGNING_RAW}"
  error "codesign identity snapshot failed with status ${CODESIGN_STATUS}"
fi

CODESIGN_IDENTIFIER="$(extract_signing_value "Identifier" "${CURRENT_SIGNING_RAW}")"
CODESIGN_TEAM_IDENTIFIER="$(extract_signing_value "TeamIdentifier" "${CURRENT_SIGNING_RAW}")"
CODESIGN_EXECUTABLE="$(extract_signing_value "Executable" "${CURRENT_SIGNING_RAW}")"
CODESIGN_DESIGNATED_REQUIREMENT="$(extract_designated_requirement "${CURRENT_SIGNING_RAW}")"

[[ -n "${CODESIGN_IDENTIFIER}" ]] || error "codesign did not report an Identifier for the built app"
[[ -n "${CODESIGN_TEAM_IDENTIFIER}" ]] || log "Warning: codesign did not report a TeamIdentifier"
[[ -n "${CODESIGN_DESIGNATED_REQUIREMENT}" ]] || log "Warning: codesign did not report a designated requirement"

{
  printf 'app_path=%s\n' "${APP_PATH}"
  printf 'executable=%s\n' "${CODESIGN_EXECUTABLE}"
  printf 'identifier=%s\n' "${CODESIGN_IDENTIFIER}"
  printf 'team_identifier=%s\n' "${CODESIGN_TEAM_IDENTIFIER}"
  printf 'designated_requirement=%s\n' "${CODESIGN_DESIGNATED_REQUIREMENT}"
} >"${CURRENT_SIGNING_SUMMARY}"

log "Signing identity snapshot"
log "  Executable: ${CODESIGN_EXECUTABLE}"
log "  Identifier: ${CODESIGN_IDENTIFIER}"
log "  Team Identifier: ${CODESIGN_TEAM_IDENTIFIER:-<missing>}"
log "  Designated Requirement: ${CODESIGN_DESIGNATED_REQUIREMENT:-<missing>}"

if [[ -z "${CODESIGN_TEAM_IDENTIFIER}" || "${CODESIGN_TEAM_IDENTIFIER}" == "not set" || -z "${CODESIGN_DESIGNATED_REQUIREMENT}" ]]; then
  log "Debug smoke uses a non-persistent local signature; it is not a permission-continuity check."
  log "Use the signed release archive to verify Identifier, TeamIdentifier, and designated requirement across updates."
elif [[ -f "${PREVIOUS_SIGNING_SUMMARY}" ]]; then
  if cmp -s "${PREVIOUS_SIGNING_SUMMARY}" "${CURRENT_SIGNING_SUMMARY}"; then
    log "Signing identity matches the previous smoke-test build"
  else
    log "Signing identity changed compared to the previous smoke-test build"
    diff -u "${PREVIOUS_SIGNING_SUMMARY}" "${CURRENT_SIGNING_SUMMARY}" || true
  fi
else
  log "No previous signing snapshot found; stored the current build as the baseline for the next run"
fi

if [[ "${SKIP_LAUNCH}" -eq 1 ]]; then
  log "Skipping app launch; build and bundle validation completed."
  exit 0
fi

log "Killing any previous Cortexa process"
pkill -f "Cortexa.app/Contents/MacOS/Cortexa" >/dev/null 2>&1 || true

LAUNCH_ARGS=()
if [[ "${EXERCISE_UI}" -eq 1 ]]; then
  LAUNCH_ARGS=(--wispr-smoke-open-settings)
fi

log "Launching app via open(1) (LaunchServices/TCC-stable)"
rm -f "${LOG_PATH}"
if [[ ${#LAUNCH_ARGS[@]} -gt 0 ]]; then
  open "${APP_PATH}" --args "${LAUNCH_ARGS[@]}"
else
  open "${APP_PATH}"
fi
sleep 4

APP_PID="$(pgrep -f "${APP_BINARY}" | head -n 1 || true)"

if [[ -z "${APP_PID}" ]] || ! kill -0 "${APP_PID}" >/dev/null 2>&1; then
  echo "--- app log ---"
  cat "${LOG_PATH}" 2>/dev/null || true
  error "App process not running after launch."
fi

log "App process is running with pid ${APP_PID}"
log "Runtime resources verified:"
log "  CLI: ${EFFECTIVE_RUNTIME_DIR}/whisper-cli"
log "  Models: ${MODEL_COUNT}"
log "  Log: ${LOG_PATH}"

if [[ "${EXERCISE_UI}" -eq 1 ]]; then
  log "Waiting for in-app Settings open (--wispr-smoke-open-settings)"
  sleep 2
  if ! kill -0 "${APP_PID}" >/dev/null 2>&1; then
    echo "--- app log ---"
    cat "${LOG_PATH}" 2>/dev/null || true
    error "App process exited during UI exercise."
  fi

  log "UI exercise complete: app stayed alive after opening Settings"
fi

if [[ "${KEEP_RUNNING}" -eq 1 ]]; then
  log "Leaving app running."
  exit 0
fi

log "Stopping app process"
kill "${APP_PID}" >/dev/null 2>&1 || true
wait "${APP_PID}" 2>/dev/null || true
log "Smoke test completed."
