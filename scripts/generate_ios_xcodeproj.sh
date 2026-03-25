#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_DIR="${ROOT_DIR}/apps/ios/WisprLocaliOS"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "xcodegen not found. Installing via Homebrew..."
  brew install xcodegen
fi

(
  cd "${PROJECT_DIR}"
  xcodegen generate
)

echo "Generated: ${PROJECT_DIR}/WisprLocaliOS.xcodeproj"
