#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_DIR="${ROOT_DIR}/apps/macos/WisprLocalMac"
APP_MARKETING_VERSION="$(cat "${ROOT_DIR}/VERSION")"
APP_BUILD_NUMBER="$(echo "${APP_MARKETING_VERSION}" | tr -cd '0-9')"
APP_BUILD_NUMBER="$(echo "${APP_BUILD_NUMBER}" | sed 's/^0*//')"
SPARKLE_FEED_URL="${SPARKLE_FEED_URL:-}"
SPARKLE_PUBLIC_ED_KEY="${SPARKLE_PUBLIC_ED_KEY:-}"
WISPR_LICENSE_PUBLIC_KEY_BASE64="${WISPR_LICENSE_PUBLIC_KEY_BASE64:-}"

if [[ -z "${APP_BUILD_NUMBER}" ]]; then
  APP_BUILD_NUMBER="1"
fi

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "xcodegen not found. Installing via Homebrew..."
  brew install xcodegen
fi

(
  cd "${PROJECT_DIR}"
  APP_MARKETING_VERSION="${APP_MARKETING_VERSION}" \
  APP_BUILD_NUMBER="${APP_BUILD_NUMBER}" \
  SPARKLE_FEED_URL="${SPARKLE_FEED_URL}" \
  SPARKLE_PUBLIC_ED_KEY="${SPARKLE_PUBLIC_ED_KEY}" \
  WISPR_LICENSE_PUBLIC_KEY_BASE64="${WISPR_LICENSE_PUBLIC_KEY_BASE64}" \
  xcodegen generate
)

echo "Generated: ${PROJECT_DIR}/WisprLocalMac.xcodeproj"
