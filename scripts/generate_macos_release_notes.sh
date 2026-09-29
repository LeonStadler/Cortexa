#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 4 ]]; then
  echo "Usage: $0 <version> <source-commit> <previous-release-tag> <output-file>" >&2
  exit 2
fi

RELEASE_VERSION="$1"
SOURCE_COMMIT="$2"
PREVIOUS_TAG="$3"
OUTPUT_FILE="$4"
GITHUB_REPOSITORY_VALUE="${GITHUB_REPOSITORY:-LeonStadler/Cortexa}"
RELEASE_TAG="v${RELEASE_VERSION}"

[[ "${RELEASE_VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
  echo "Release version must use MAJOR.MINOR.PATCH: ${RELEASE_VERSION}" >&2
  exit 2
}
[[ "${SOURCE_COMMIT}" =~ ^[0-9a-f]{40}$ ]] || {
  echo "Source commit must be a full lowercase Git SHA: ${SOURCE_COMMIT}" >&2
  exit 2
}
[[ -n "${PREVIOUS_TAG}" ]] || {
  echo "A previous published release tag is required to generate release notes." >&2
  exit 2
}
git cat-file -e "${SOURCE_COMMIT}^{commit}"
git rev-parse --verify "refs/tags/${PREVIOUS_TAG}^{commit}" >/dev/null
git merge-base --is-ancestor "${PREVIOUS_TAG}" "${SOURCE_COMMIT}" || {
  echo "Previous release ${PREVIOUS_TAG} is not an ancestor of ${SOURCE_COMMIT}." >&2
  exit 1
}

NOTES_RESPONSE="$(gh api --method POST \
  "repos/${GITHUB_REPOSITORY_VALUE}/releases/generate-notes" \
  -f "tag_name=${RELEASE_TAG}" \
  -f "target_commitish=${SOURCE_COMMIT}" \
  -f "previous_tag_name=${PREVIOUS_TAG}" \
  -f "configuration_file_path=.github/release.yml")"
GENERATED_NOTES="$(jq -r '.body' <<<"${NOTES_RESPONSE}")"

DIRECT_COMMITS="$(git rev-list --no-merges "${PREVIOUS_TAG}..${SOURCE_COMMIT}")"
DIRECT_NOTES=()
while IFS= read -r COMMIT; do
  [[ -n "${COMMIT}" ]] || continue
  ASSOCIATED_PR_COUNT="$(gh api "repos/${GITHUB_REPOSITORY_VALUE}/commits/${COMMIT}/pulls" --jq 'length')"
  [[ "${ASSOCIATED_PR_COUNT}" == "0" ]] || continue

  SUBJECT="$(git show -s --format=%s "${COMMIT}")"
  AUTHOR="$(git show -s --format=%an "${COMMIT}")"
  DIRECT_NOTES+=("- ${SUBJECT} — ${AUTHOR} (${COMMIT:0:7})")
done <<<"${DIRECT_COMMITS}"

{
  printf '## Cortexa %s — macOS, Apple Silicon\n\n' "${RELEASE_VERSION}"

  if [[ "${#DIRECT_NOTES[@]}" -gt 0 ]]; then
    printf '### Direct commits\n\n'
    printf '%s\n' "${DIRECT_NOTES[@]}"
    printf '\n'
  fi

  printf '%s\n\n' "${GENERATED_NOTES}"

  cat <<'EOF'
### Download and install

The DMG targets Apple Silicon (arm64). This open-source build is ad-hoc signed and is not notarized; macOS may ask you to approve the first launch. See the included install notes. Speech models are downloaded by the app when needed.
EOF

  printf '\nSource commit: %s\n' "${SOURCE_COMMIT}"
} >"${OUTPUT_FILE}"
