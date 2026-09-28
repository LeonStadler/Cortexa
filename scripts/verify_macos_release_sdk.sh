#!/usr/bin/env bash
set -euo pipefail

error() {
  echo "[verify_macos_release_sdk] ERROR: $*" >&2
  exit 1
}

command -v xcodebuild >/dev/null 2>&1 || error "xcodebuild is required."
command -v xcrun >/dev/null 2>&1 || error "xcrun is required."

XCODE_VERSION="$(xcodebuild -version | awk '$1 == "Xcode" {print $2; exit}')"
MACOS_SDK_VERSION="$(xcrun --sdk macosx --show-sdk-version)"
MACOS_SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
XCODE_MAJOR="${XCODE_VERSION%%.*}"
MACOS_SDK_MAJOR="${MACOS_SDK_VERSION%%.*}"

[[ "${XCODE_MAJOR}" =~ ^[0-9]+$ ]] || error "Could not read the active Xcode version: ${XCODE_VERSION:-missing}."
[[ "${MACOS_SDK_MAJOR}" =~ ^[0-9]+$ ]] || error "Could not read the active macOS SDK version: ${MACOS_SDK_VERSION:-missing}."

(( XCODE_MAJOR >= 26 )) || error "Xcode 26 or later is required to compile the Cortexa Icon Composer asset and Foundation Models integration; active version is ${XCODE_VERSION}."
(( MACOS_SDK_MAJOR >= 26 )) || error "The macOS 26 SDK or later is required; active SDK is ${MACOS_SDK_VERSION}."
[[ -d "${MACOS_SDK_PATH}/System/Library/Frameworks/FoundationModels.framework" ]] \
  || error "FoundationModels.framework is missing from ${MACOS_SDK_PATH}."

echo "[verify_macos_release_sdk] Xcode ${XCODE_VERSION}, macOS SDK ${MACOS_SDK_VERSION}, and FoundationModels.framework are ready."
