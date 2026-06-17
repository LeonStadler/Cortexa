#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_DIR="${ROOT_DIR}/apps/macos/WisprLocalMac"
PROJECT_PATH="${PROJECT_DIR}/WisprLocalMac.xcodeproj"
RUNTIME_DIR="${ROOT_DIR}/apps/macos/AppShell/Resources/Runtime"
APP_MARKETING_VERSION="$(cat "${ROOT_DIR}/VERSION")"
APP_BUILD_NUMBER="$(echo "${APP_MARKETING_VERSION}" | tr -cd '0-9')"
APP_BUILD_NUMBER="$(echo "${APP_BUILD_NUMBER}" | sed 's/^0*//')"
SPARKLE_FEED_URL="${SPARKLE_FEED_URL:-}"
SPARKLE_PUBLIC_ED_KEY="${SPARKLE_PUBLIC_ED_KEY:-}"
CHECK_ONLY=0
REQUIRE_CLEAN=0

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

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check)
      CHECK_ONLY=1
      shift
      ;;
    --require-clean)
      REQUIRE_CLEAN=1
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

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
  print_xcodegen_install_help
  exit 1
fi

if [[ "${REQUIRE_CLEAN}" -eq 1 ]] && ! git diff --quiet -- "${PROJECT_PATH}"; then
  echo "Refusing to regenerate ${PROJECT_PATH} because it already has local modifications." >&2
  exit 1
fi

# XcodeGen validates source directories before CI prepares the runtime bundle.
mkdir -p "${RUNTIME_DIR}/models"

(
  cd "${PROJECT_DIR}"
  APP_MARKETING_VERSION="${APP_MARKETING_VERSION}" \
  APP_BUILD_NUMBER="${APP_BUILD_NUMBER}" \
  SPARKLE_FEED_URL="${SPARKLE_FEED_URL}" \
  SPARKLE_PUBLIC_ED_KEY="${SPARKLE_PUBLIC_ED_KEY}" \
  "${XCODEGEN_BIN}" generate
)

echo "Generated: ${PROJECT_PATH}"

if [[ "${CHECK_ONLY}" -eq 1 ]]; then
  if ! git diff --quiet -- "${PROJECT_PATH}"; then
    echo "Generated macOS project is out of date. Re-run scripts/generate_macos_xcodeproj.sh and commit the result." >&2
    git diff -- "${PROJECT_PATH}" || true
    exit 1
  fi

  echo "Project check passed: ${PROJECT_PATH}"
fi
