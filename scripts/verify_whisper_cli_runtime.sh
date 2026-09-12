#!/usr/bin/env bash
set -euo pipefail

log() {
  echo "[verify_whisper_cli_runtime] $*"
}

error() {
  echo "[verify_whisper_cli_runtime] ERROR: $*" >&2
  exit 1
}

usage() {
  cat <<EOF
Usage: $0 <path to whisper-cli> [path to ggml model]

Checks that whisper-cli has no non-system dynamic-library dependencies and can
start. When a model is supplied, also transcribes synthesized speech end to end.
EOF
  exit 1
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
  usage
fi

CLI_PATH="$1"
MODEL_PATH="${2:-}"

[[ -x "${CLI_PATH}" ]] || error "whisper-cli is missing or not executable at ${CLI_PATH}"
command -v otool >/dev/null 2>&1 || error "Required tool 'otool' is missing."

NON_SYSTEM_DEPENDENCIES="$(
  otool -L "${CLI_PATH}" | awk '
    NR > 1 {
      dependency = $1
      if (dependency !~ "^/usr/lib/" &&
          dependency !~ "^/System/Library/Frameworks/" &&
          dependency !~ "^/System/Library/PrivateFrameworks/") {
        print dependency
      }
    }
  '
)"

if [[ -n "${NON_SYSTEM_DEPENDENCIES}" ]]; then
  FORMATTED_DEPENDENCIES="$(printf '%s' "${NON_SYSTEM_DEPENDENCIES}" | tr '\n' ',')"
  error "whisper-cli has non-portable dynamic-library dependencies: ${FORMATTED_DEPENDENCIES}"
fi

PROBE_LOG="$(mktemp -t cortexa-whisper-probe.XXXXXX)"
cleanup_probe() {
  rm -f "${PROBE_LOG}"
}
trap cleanup_probe EXIT

if ! "${CLI_PATH}" --help >/dev/null 2>"${PROBE_LOG}"; then
  PROBE_ERROR="$(sed -n '1,12p' "${PROBE_LOG}")"
  error "whisper-cli launch probe failed: ${PROBE_ERROR}"
fi

log "Portable dependencies and launch probe passed: ${CLI_PATH}"

if [[ -z "${MODEL_PATH}" ]]; then
  exit 0
fi

[[ -f "${MODEL_PATH}" ]] || error "Model is missing at ${MODEL_PATH}"
command -v say >/dev/null 2>&1 || error "Required tool 'say' is missing."
command -v afconvert >/dev/null 2>&1 || error "Required tool 'afconvert' is missing."

E2E_DIR="$(mktemp -d -t cortexa-whisper-e2e.XXXXXX)"
cleanup_e2e() {
  rm -rf "${E2E_DIR}"
}
trap 'cleanup_e2e; cleanup_probe' EXIT

SPEECH_AIFF="${E2E_DIR}/speech.aiff"
SPEECH_WAV="${E2E_DIR}/speech.wav"
OUTPUT_BASE="${E2E_DIR}/transcript"

say -o "${SPEECH_AIFF}" "This is a speech recognition test for Cortexa."
afconvert -f WAVE -d LEI16@16000 "${SPEECH_AIFF}" "${SPEECH_WAV}"

if ! "${CLI_PATH}" \
  -m "${MODEL_PATH}" \
  -f "${SPEECH_WAV}" \
  -l en \
  -otxt \
  -of "${OUTPUT_BASE}" \
  -nt \
  >"${E2E_DIR}/stdout.log" \
  2>"${E2E_DIR}/stderr.log"; then
  E2E_ERROR="$(sed -n '1,20p' "${E2E_DIR}/stderr.log")"
  error "whisper-cli transcription failed: ${E2E_ERROR}"
fi

[[ -s "${OUTPUT_BASE}.txt" ]] || error "whisper-cli produced no transcript for synthesized speech."
TRANSCRIPT="$(tr '\n' ' ' <"${OUTPUT_BASE}.txt" | sed 's/[[:space:]]\{1,\}/ /g; s/^ //; s/ $//')"
log "Transcription E2E passed with non-empty output: ${TRANSCRIPT}"
