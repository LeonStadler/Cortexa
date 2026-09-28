#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS_DIR="${ROOT_DIR}/artifacts/mac"
DERIVED_DATA_DIR="${ARTIFACTS_DIR}/open-source-deriveddata"
APP_VERSION="$(cat "${ROOT_DIR}/VERSION")"
APP_PATH="${ARTIFACTS_DIR}/release/Cortexa.app"
DMG_PATH="${ARTIFACTS_DIR}/Cortexa-${APP_VERSION}.dmg"

log() {
  echo "[build_macos_open_source_release] $*"
}

error() {
  echo "[build_macos_open_source_release] ERROR: $*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || error "Required tool '$1' is missing."
}

[[ "$(uname -s)" == "Darwin" ]] || error "This release build must run on macOS."
for command_name in git xcodebuild xcodegen cmake codesign hdiutil shasum; do
  require_command "${command_name}"
done

log "Removing previous macOS build outputs under ${ARTIFACTS_DIR}"
rm -rf "${ARTIFACTS_DIR}"
mkdir -p "${ARTIFACTS_DIR}"

if [[ ! -f "${ROOT_DIR}/third_party/whisper.cpp/CMakeLists.txt" ]]; then
  log "Initializing the pinned whisper.cpp submodule"
  git -C "${ROOT_DIR}" submodule update --init --recursive third_party/whisper.cpp
fi

log "Building the bundled Whisper runtime"
"${ROOT_DIR}/scripts/build_whisper_xcframework.sh"
"${ROOT_DIR}/scripts/prepare_runtime_bundle.sh"

log "Generating the macOS Xcode project"
"${ROOT_DIR}/scripts/generate_macos_xcodeproj.sh"

log "Building the unsigned Release app bundle"
xcodebuild \
  -project "${ROOT_DIR}/apps/macos/WisprLocalMac/WisprLocalMac.xcodeproj" \
  -scheme WisprLocalMac \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -derivedDataPath "${DERIVED_DATA_DIR}" \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  build

BUILT_APP_PATH="${DERIVED_DATA_DIR}/Build/Products/Release/Cortexa.app"
[[ -d "${BUILT_APP_PATH}" ]] || error "Release app was not produced at ${BUILT_APP_PATH}."
mkdir -p "$(dirname "${APP_PATH}")"
ditto "${BUILT_APP_PATH}" "${APP_PATH}"

log "Applying an ad-hoc signature for bundle integrity (no Apple certificate required)"
codesign --force --deep --sign - "${APP_PATH}"
codesign --verify --deep --strict --verbose=2 "${APP_PATH}"
"${ROOT_DIR}/scripts/validate_macos_app_runtime.sh" "${APP_PATH}"

log "Creating the open-source DMG"
CORTEXA_ALLOW_ADHOC=1 \
APP_PATH="${APP_PATH}" \
DMG_PATH="${DMG_PATH}" \
EXPORT_PATH="${ARTIFACTS_DIR}/release" \
"${ROOT_DIR}/scripts/create_macos_dmg.sh"

log "Verifying the generated DMG"
hdiutil verify "${DMG_PATH}"
shasum -a 256 "${DMG_PATH}" >"${DMG_PATH}.sha256"

cat >"${ARTIFACTS_DIR}/Cortexa-${APP_VERSION}-install-notes.txt" <<'EOF'
Cortexa macOS installation

This open-source build targets Apple Silicon (arm64). It is not signed with an Apple Developer ID and is not notarized.
macOS may block its first launch. Try right-clicking Cortexa.app and choosing Open,
then confirm Open in the dialog. If macOS still blocks it, open System Settings >
Privacy & Security after the attempted launch and use Open Anyway for Cortexa.

This approval is required because the app is distributed without an Apple Developer ID.
EOF

log "Build complete"
log "DMG: ${DMG_PATH}"
log "SHA-256: ${DMG_PATH}.sha256"
log "Install notes: ${ARTIFACTS_DIR}/Cortexa-${APP_VERSION}-install-notes.txt"
