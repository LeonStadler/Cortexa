#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS_DIR="${ROOT_DIR}/artifacts/mac"
ARCHIVE_PATH="${ARCHIVE_PATH:-${ARTIFACTS_DIR}/Cortexa.xcarchive}"
EXPORT_PATH="${EXPORT_PATH:-${ARTIFACTS_DIR}/release}"
EXPORT_OPTIONS_PLIST="${ARTIFACTS_DIR}/ExportOptions-macos.plist"

log() {
  echo "[export_macos_release] $*"
}

error() {
  echo "[export_macos_release] ERROR: $*" >&2
  exit 1
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    error "Missing required tool '$1'"
  fi
}

require_command xcodebuild

[[ -d "${ARCHIVE_PATH}" ]] || error "Archive not found at ${ARCHIVE_PATH}. Run ./scripts/archive_macos_release.sh first."

mkdir -p "${ARTIFACTS_DIR}"
rm -rf "${EXPORT_PATH}"
mkdir -p "${EXPORT_PATH}"

SIGNING_STYLE="${SIGNING_STYLE:-automatic}"
TEAM_ID="${DEVELOPMENT_TEAM:-}"

cat >"${EXPORT_OPTIONS_PLIST}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>destination</key>
  <string>export</string>
  <key>method</key>
  <string>developer-id</string>
  <key>signingStyle</key>
  <string>${SIGNING_STYLE}</string>
  <key>stripSwiftSymbols</key>
  <true/>
EOF

if [[ -n "${TEAM_ID}" ]]; then
  cat >>"${EXPORT_OPTIONS_PLIST}" <<EOF
  <key>teamID</key>
  <string>${TEAM_ID}</string>
EOF
fi

cat >>"${EXPORT_OPTIONS_PLIST}" <<'EOF'
</dict>
</plist>
EOF

log "Exporting archive"
xcodebuild \
  -exportArchive \
  -archivePath "${ARCHIVE_PATH}" \
  -exportPath "${EXPORT_PATH}" \
  -exportOptionsPlist "${EXPORT_OPTIONS_PLIST}"

log "Export finished at ${EXPORT_PATH}"
