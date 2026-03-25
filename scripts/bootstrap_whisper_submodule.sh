#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WHISPER_DIR="${ROOT_DIR}/third_party/whisper.cpp"
WHISPER_REPO="https://github.com/ggml-org/whisper.cpp.git"

mkdir -p "${ROOT_DIR}/third_party"

if [[ -d "${WHISPER_DIR}/.git" ]]; then
  echo "whisper.cpp submodule already present at ${WHISPER_DIR}"
else
  git submodule add "${WHISPER_REPO}" third_party/whisper.cpp
  git submodule update --init --recursive
fi

echo "Done. Next step: ./scripts/build_whisper_xcframework.sh"
