#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WHISPER_DIR="${ROOT_DIR}/third_party/whisper.cpp"
OUTPUT_DIR="${ROOT_DIR}/artifacts/whisper"
CLI_BUILD_DIR="${WHISPER_DIR}/build-macos-cli"
ENABLE_XCFRAMEWORK_BUILD="${ENABLE_XCFRAMEWORK_BUILD:-OFF}"
ENABLE_COREML_FOR_CLI_BUILD="${ENABLE_COREML_FOR_CLI_BUILD:-OFF}"
XCFRAMEWORK_CANDIDATES=(
  "${WHISPER_DIR}/build/whisper.xcframework"
  "${WHISPER_DIR}/build-apple/whisper.xcframework"
)

log() {
  echo "[build_whisper_xcframework] $*"
}

error() {
  echo "[build_whisper_xcframework] ERROR: $*" >&2
  exit 1
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    error "Required tool '$1' is not installed or not on the PATH."
  fi
}

if [[ ! -d "${WHISPER_DIR}" ]]; then
  error "whisper.cpp not found. Run ./scripts/bootstrap_whisper_submodule.sh first."
fi

require_command cmake

log "Ensuring output directory ${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}"

should_try_xcframework=false
force_xcframework=false
if [[ "${ENABLE_XCFRAMEWORK_BUILD}" == "ON" ]]; then
  force_xcframework=true
  require_command xcodebuild
  should_try_xcframework=true
elif [[ "${ENABLE_XCFRAMEWORK_BUILD}" == "auto" ]] && command -v xcodebuild >/dev/null 2>&1; then
  should_try_xcframework=true
fi

if [[ "${should_try_xcframework}" == "true" ]] && [[ -x "${WHISPER_DIR}/build-xcframework.sh" ]]; then
  log "Attempting upstream whisper.xcframework build..."
  set +e
  (
    cd "${WHISPER_DIR}"
    ./build-xcframework.sh
  )
  xcframework_status=$?
  set -e

  xcframework_artifact=""
  for candidate in "${XCFRAMEWORK_CANDIDATES[@]}"; do
    if [[ -d "${candidate}" ]]; then
      xcframework_artifact="${candidate}"
      break
    fi
  done

  if [[ ${xcframework_status} -eq 0 ]] && [[ -n "${xcframework_artifact}" ]]; then
    rm -rf "${OUTPUT_DIR}/whisper.xcframework"
    cp -R "${xcframework_artifact}" "${OUTPUT_DIR}/whisper.xcframework"
    log "XCFramework copied to ${OUTPUT_DIR}/whisper.xcframework"
  else
    if [[ "${force_xcframework}" == "true" ]]; then
      error "XCFramework build failed while ENABLE_XCFRAMEWORK_BUILD=ON. Check Xcode/SDK availability."
    else
      log "XCFramework build skipped or failed; continuing with macOS CLI-only build."
    fi
  fi
else
  log "Skipping XCFramework build (no full Xcode setup detected or disabled)."
fi

log "Building macOS whisper-cli (Release)"
(
  cd "${WHISPER_DIR}"
  cmake -S . -B "${CLI_BUILD_DIR}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DGGML_METAL=ON \
    -DWHISPER_COREML="${ENABLE_COREML_FOR_CLI_BUILD}" \
    -DWHISPER_BUILD_EXAMPLES=ON \
    -DWHISPER_BUILD_TESTS=OFF \
    -DWHISPER_BUILD_SERVER=OFF
  cmake --build "${CLI_BUILD_DIR}" --config Release -j
)

CLI_CANDIDATES=(
  "${CLI_BUILD_DIR}/bin/whisper-cli"
  "${CLI_BUILD_DIR}/bin/main"
  "${WHISPER_DIR}/build/bin/whisper-cli"
  "${WHISPER_DIR}/build/bin/main"
)

for candidate in "${CLI_CANDIDATES[@]}"; do
  if [[ -x "${candidate}" ]]; then
    cp "${candidate}" "${OUTPUT_DIR}/whisper-cli"
    chmod +x "${OUTPUT_DIR}/whisper-cli"
    log "CLI copied to ${OUTPUT_DIR}/whisper-cli"
    exit 0
  fi
done

error "Could not locate whisper-cli binary in any of the expected output paths. Build failed."
