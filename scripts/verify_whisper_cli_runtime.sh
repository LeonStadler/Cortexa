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
Usage: $0 <path to whisper-cli> [path to ggml model [path to speech fixture]]

Checks that whisper-cli has no non-system dynamic-library dependencies and can
start. When a model is supplied, also transcribes the pinned whisper.cpp speech
fixture end to end. The fixture path defaults to third_party/whisper.cpp/samples/jfk.wav.
EOF
  exit 1
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
  usage
fi

CLI_PATH="$1"
MODEL_PATH="${2:-}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SPEECH_SAMPLE_PATH="${3:-${ROOT_DIR}/third_party/whisper.cpp/samples/jfk.wav}"

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
[[ -f "${SPEECH_SAMPLE_PATH}" ]] || error "Whisper speech fixture is missing at ${SPEECH_SAMPLE_PATH}"

E2E_DIR="$(mktemp -d -t cortexa-whisper-e2e.XXXXXX)"
cleanup_e2e() {
  rm -rf "${E2E_DIR}"
}
trap 'cleanup_e2e; cleanup_probe' EXIT

OUTPUT_BASE="${E2E_DIR}/transcript"
CLI_STDOUT_LOG="${E2E_DIR}/stdout.log"
CLI_STDERR_LOG="${E2E_DIR}/stderr.log"

if ! "${CLI_PATH}" \
  -m "${MODEL_PATH}" \
  -f "${SPEECH_SAMPLE_PATH}" \
  -l en \
  -otxt \
  -of "${OUTPUT_BASE}" \
  -nt \
  >"${CLI_STDOUT_LOG}" \
  2>"${CLI_STDERR_LOG}"; then
  E2E_ERROR="$(sed -n '1,20p' "${CLI_STDERR_LOG}")"
  error "whisper-cli transcription failed: ${E2E_ERROR}"
fi

if [[ ! -s "${OUTPUT_BASE}.txt" ]]; then
  CLI_STDOUT="$(sed -n '1,20p' "${CLI_STDOUT_LOG}")"
  CLI_STDERR="$(sed -n '1,20p' "${CLI_STDERR_LOG}")"
  error "whisper-cli produced no transcript for fixture ${SPEECH_SAMPLE_PATH}. stdout: ${CLI_STDOUT:-<empty>}; stderr: ${CLI_STDERR:-<empty>}"
fi
TRANSCRIPT="$(tr '\n' ' ' <"${OUTPUT_BASE}.txt" | sed 's/[[:space:]]\{1,\}/ /g; s/^ //; s/ $//')"
log "Transcription E2E passed with non-empty output from ${SPEECH_SAMPLE_PATH}: ${TRANSCRIPT}"
