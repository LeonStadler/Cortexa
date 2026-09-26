#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
log() {
  echo "[smoke_test_parakeet] $*"
}

error() {
  echo "[smoke_test_parakeet] ERROR: $*" >&2
  exit 1
}

command -v say >/dev/null 2>&1 || error "Required macOS tool 'say' is missing."
command -v afconvert >/dev/null 2>&1 || error "Required macOS tool 'afconvert' is missing."

SMOKE_DIR="$(mktemp -d -t cortexa-parakeet-smoke.XXXXXX)"
cleanup() {
  rm -rf "${SMOKE_DIR}"
}
trap cleanup EXIT

say -o "${SMOKE_DIR}/speech.aiff" "This is a speech recognition test for Cortexa."
afconvert -f WAVE -d LEI16@16000 "${SMOKE_DIR}/speech.aiff" "${SMOKE_DIR}/speech.wav"

log "Installing required assets through VoiceModelInstaller and running Parakeet through Cortexa ASRCore"
CORTEXA_PARAKEET_SMOKE_AUDIO="${SMOKE_DIR}/speech.wav" \
  swift test --package-path "${ROOT_DIR}" \
    --filter 'ParakeetIntegrationSmokeTests/testParakeetRuntimeTranscribesSynthesizedAudio'

log "Parakeet ASRCore integration smoke test passed."
