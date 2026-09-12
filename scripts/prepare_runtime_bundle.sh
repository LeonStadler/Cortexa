#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_CLI="${ROOT_DIR}/artifacts/whisper/whisper-cli"
SRC_MODELS_DIR="${ROOT_DIR}/models"
DEST_RUNTIME_DIR="${ROOT_DIR}/apps/macos/AppShell/Resources/Runtime"
DEST_MODELS_DIR="${DEST_RUNTIME_DIR}/models"
DEFAULT_MODEL_FILE="ggml-base.bin"
MANIFEST_PATH="${DEST_RUNTIME_DIR}/runtime-manifest.json"
INCLUDE_DEFAULT_MODEL=0

usage() {
  cat <<EOF
Usage: $(basename "$0") [--include-default-model]

Prepares the macOS app runtime bundle (whisper-cli + manifest).

Default (Release): CLI + empty models/ directory, manifest with modelFileNames: [].
Dev/Smoke: pass --include-default-model to bundle ${DEFAULT_MODEL_FILE}.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --include-default-model)
      INCLUDE_DEFAULT_MODEL=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ ! -x "${SRC_CLI}" ]]; then
  echo "Missing executable whisper-cli at ${SRC_CLI}. Run ./scripts/build_whisper_xcframework.sh first."
  exit 1
fi

"${ROOT_DIR}/scripts/verify_whisper_cli_runtime.sh" "${SRC_CLI}"

mkdir -p "${DEST_MODELS_DIR}"
cp "${SRC_CLI}" "${DEST_RUNTIME_DIR}/whisper-cli"
chmod +x "${DEST_RUNTIME_DIR}/whisper-cli"
"${ROOT_DIR}/scripts/verify_whisper_cli_runtime.sh" "${DEST_RUNTIME_DIR}/whisper-cli"

rm -f "${DEST_MODELS_DIR}"/*.bin

if [[ "${INCLUDE_DEFAULT_MODEL}" -eq 1 ]]; then
  if [[ ! -d "${SRC_MODELS_DIR}" ]]; then
    echo "Missing models directory at ${SRC_MODELS_DIR}. Run ./scripts/download_models.sh first."
    exit 1
  fi
  if [[ ! -f "${SRC_MODELS_DIR}/${DEFAULT_MODEL_FILE}" ]]; then
    echo "Missing default model ${DEFAULT_MODEL_FILE} in ${SRC_MODELS_DIR}."
    exit 1
  fi
  cp "${SRC_MODELS_DIR}/${DEFAULT_MODEL_FILE}" "${DEST_MODELS_DIR}/"
  cat >"${MANIFEST_PATH}" <<EOF
{
  "defaultModelFileName": "${DEFAULT_MODEL_FILE}",
  "modelFileNames": ["${DEFAULT_MODEL_FILE}"]
}
EOF
  echo "Runtime bundle prepared (dev/smoke with default model):"
  echo "  CLI: ${DEST_RUNTIME_DIR}/whisper-cli"
  echo "  Default model: ${DEST_MODELS_DIR}/${DEFAULT_MODEL_FILE}"
else
  cat >"${MANIFEST_PATH}" <<EOF
{
  "defaultModelFileName": "${DEFAULT_MODEL_FILE}",
  "modelFileNames": []
}
EOF
  echo "Runtime bundle prepared (release, no bundled models):"
  echo "  CLI: ${DEST_RUNTIME_DIR}/whisper-cli"
  echo "  Models: (none — first-run download via onboarding)"
fi

echo "  Manifest: ${MANIFEST_PATH}"
