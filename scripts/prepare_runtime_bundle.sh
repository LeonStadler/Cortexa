#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_CLI="${ROOT_DIR}/artifacts/whisper/whisper-cli"
SRC_MODELS_DIR="${ROOT_DIR}/models"
DEST_RUNTIME_DIR="${ROOT_DIR}/apps/macos/AppShell/Resources/Runtime"
DEST_MODELS_DIR="${DEST_RUNTIME_DIR}/models"

if [[ ! -x "${SRC_CLI}" ]]; then
  echo "Missing executable whisper-cli at ${SRC_CLI}. Run ./scripts/build_whisper_xcframework.sh first."
  exit 1
fi

if [[ ! -d "${SRC_MODELS_DIR}" ]]; then
  echo "Missing models directory at ${SRC_MODELS_DIR}. Run ./scripts/download_models.sh first."
  exit 1
fi

mkdir -p "${DEST_MODELS_DIR}"
cp "${SRC_CLI}" "${DEST_RUNTIME_DIR}/whisper-cli"
chmod +x "${DEST_RUNTIME_DIR}/whisper-cli"

shopt -s nullglob
MODEL_FILES=("${SRC_MODELS_DIR}"/*.bin)
if (( ${#MODEL_FILES[@]} == 0 )); then
  echo "No .bin model files found in ${SRC_MODELS_DIR}."
  exit 1
fi

cp "${SRC_MODELS_DIR}"/*.bin "${DEST_MODELS_DIR}/"

echo "Runtime bundle prepared:"
echo "  CLI: ${DEST_RUNTIME_DIR}/whisper-cli"
echo "  Models: ${DEST_MODELS_DIR}"
