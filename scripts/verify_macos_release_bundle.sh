#!/usr/bin/env bash
set -euo pipefail

log() {
  echo "[verify_macos_release_bundle] $*"
}

error() {
  echo "[verify_macos_release_bundle] ERROR: $*" >&2
  exit 1
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    error "Required tool '$1' is missing. Install it before running this script."
  fi
}

usage() {
  cat <<EOF
Usage: $0 <path to .app|.pkg|.dmg>

Verifies codesign, Gatekeeper assessment, and notarization staples for the supplied macOS bundle.
EOF
  exit 1
}

if [[ $# -ne 1 ]]; then
  usage
fi

BUNDLE_PATH="$1"
if [[ ! -e "${BUNDLE_PATH}" ]]; then
  error "Path '${BUNDLE_PATH}' does not exist."
fi

require_command codesign
require_command spctl
require_command xcrun

log "Verifying bundle at ${BUNDLE_PATH}"
case "${BUNDLE_PATH##*.}" in
app)
  log "Validating code signature and runtime hardening"
  codesign --verify --deep --strict --verbose=2 "${BUNDLE_PATH}"
  spctl --assess --type exec --verbose=2 "${BUNDLE_PATH}"
  log "Checking notarization staple"
  xcrun stapler validate "${BUNDLE_PATH}"
  ;;
pkg|dmg)
  log "Running Gatekeeper assessment for disk image or installer"
  spctl --assess --type open --verbose=2 "${BUNDLE_PATH}"
  log "Checking notarization staple"
  xcrun stapler validate "${BUNDLE_PATH}"
  ;;
*)
  log "Performing generic Gatekeeper assessment"
  spctl --assess --verbose=2 "${BUNDLE_PATH}"
  ;;
esac

log "Bundle verification complete."
