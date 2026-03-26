#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_DIR="${ROOT_DIR}/apps/macos/WisprLocalMac"
PROJECT_PATH="${PROJECT_DIR}/WisprLocalMac.xcodeproj"
APP_MARKETING_VERSION="$(cat "${ROOT_DIR}/VERSION")"
APP_BUILD_NUMBER="$(echo "${APP_MARKETING_VERSION}" | tr -cd '0-9')"
APP_BUILD_NUMBER="$(echo "${APP_BUILD_NUMBER}" | sed 's/^0*//')"
SPARKLE_FEED_URL="${SPARKLE_FEED_URL:-}"
SPARKLE_PUBLIC_ED_KEY="${SPARKLE_PUBLIC_ED_KEY:-}"
WISPR_LICENSE_PUBLIC_KEY_BASE64="${WISPR_LICENSE_PUBLIC_KEY_BASE64:-}"

if [[ -z "${APP_BUILD_NUMBER}" ]]; then
  APP_BUILD_NUMBER="1"
fi

print_xcodegen_install_help() {
  cat >&2 <<'EOF'
xcodegen not found.

This project needs XcodeGen to generate the macOS Xcode project:
  ./apps/macos/WisprLocalMac/WisprLocalMac.xcodeproj

Install one of the following, then re-run this script:
  1. Homebrew: brew install xcodegen
  2. Mint:      mint install yonaskolb/XcodeGen
  3. Manual:    download the binary from https://github.com/yonaskolb/XcodeGen/releases

After installation, make sure the `xcodegen` binary is available on your PATH.
EOF
}

resolve_tool() {
  local tool_name="$1"
  shift

  if command -v "${tool_name}" >/dev/null 2>&1; then
    command -v "${tool_name}"
    return 0
  fi

  local candidate
  for candidate in "$@"; do
    if [[ -x "${candidate}" ]]; then
      echo "${candidate}"
      return 0
    fi
  done

  return 1
}

XCODEGEN_BIN="$(resolve_tool xcodegen /opt/homebrew/bin/xcodegen /usr/local/bin/xcodegen || true)"

if [[ -z "${XCODEGEN_BIN}" ]]; then
  BREW_BIN="$(resolve_tool brew /opt/homebrew/bin/brew /usr/local/bin/brew || true)"

  if [[ -n "${PROJECT_PATH}" && -d "${PROJECT_PATH}" ]]; then
    echo "xcodegen not found. Reusing existing project at ${PROJECT_PATH}."
    echo "Install xcodegen later if you need to regenerate the project."
    exit 0
  fi

  if [[ -n "${BREW_BIN}" ]]; then
    echo "xcodegen not found. Installing via Homebrew..."
    "${BREW_BIN}" install xcodegen
    XCODEGEN_BIN="$(resolve_tool xcodegen /opt/homebrew/bin/xcodegen /usr/local/bin/xcodegen || true)"
  else
    print_xcodegen_install_help
    exit 1
  fi
fi

if [[ -z "${XCODEGEN_BIN}" ]]; then
  print_xcodegen_install_help
  exit 1
fi

(
  cd "${PROJECT_DIR}"
  APP_MARKETING_VERSION="${APP_MARKETING_VERSION}" \
  APP_BUILD_NUMBER="${APP_BUILD_NUMBER}" \
  SPARKLE_FEED_URL="${SPARKLE_FEED_URL}" \
  SPARKLE_PUBLIC_ED_KEY="${SPARKLE_PUBLIC_ED_KEY}" \
  WISPR_LICENSE_PUBLIC_KEY_BASE64="${WISPR_LICENSE_PUBLIC_KEY_BASE64}" \
  "${XCODEGEN_BIN}" generate
)

echo "Generated: ${PROJECT_PATH}"
