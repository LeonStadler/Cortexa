#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WHISPER_DIR="${ROOT_DIR}/third_party/whisper.cpp"
MODELS_DIR="${ROOT_DIR}/models"

if [[ ! -d "${WHISPER_DIR}" ]]; then
  echo "whisper.cpp not found. Run ./scripts/bootstrap_whisper_submodule.sh first."
  exit 1
fi

mkdir -p "${MODELS_DIR}"

(
  cd "${WHISPER_DIR}"
  ./models/download-ggml-model.sh base
  ./models/download-ggml-model.sh small
)

cp "${WHISPER_DIR}"/models/ggml-base*.bin "${MODELS_DIR}" 2>/dev/null || true
cp "${WHISPER_DIR}"/models/ggml-small*.bin "${MODELS_DIR}" 2>/dev/null || true

echo "Downloaded models into ${MODELS_DIR}"
