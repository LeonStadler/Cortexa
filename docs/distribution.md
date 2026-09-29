# Distribution Pipeline

## macOS open-source release workflow

- The visible product name and generated app bundle are **Cortexa** (`Cortexa.app`); the target and scheme retain the technical name `WisprLocalMac`, and the bundle identifier remains `com.wisprlocal.mac`.
- The open-source release is built on GitHub Actions' standard `macos-26` Apple Silicon runner with Xcode 26 or later, so the Icon Composer app icon and Apple Foundation Models integration are compiled into the arm64 app. No self-hosted machine or Apple credentials are needed. The workflow runs only when manually dispatched from `main`: `action=prepare` builds and verifies the arm64 DMG and creates a draft release; after installation and acceptance testing, `action=publish` publishes that exact draft. It requires no Apple Developer Program membership, Developer ID certificate, Apple account secret, or notarization. The app and bundled Whisper CLI are both arm64.
- Repository Actions settings allow only `actions/checkout@v5`; the default `GITHUB_TOKEN` permission is read-only. Release jobs request `contents: write` to manage releases and `pull-requests: read` only to identify commits already represented by PRs. Workflows cannot create or approve pull requests. Pull Requests are enabled and are the integration path for future changes.
- The app bundle receives an ad-hoc code signature to seal its files and verify that packaging did not alter it. This is not an Apple developer identity. Gatekeeper may block the first launch; the user must choose **Open** from the app's context menu or approve it in **System Settings → Privacy & Security**.
- Ad-hoc signing has no stable Apple team identity. macOS may ask again for protected-resource permissions after a future app replacement. The bundle identifier stays `com.wisprlocal.mac`, but this does not guarantee TCC permission continuity without the same persistent signing identity.
- The local release command cleans previous files in this checkout's `artifacts/mac/`, verifies Xcode 26+ and the FoundationModels SDK, initializes the pinned Whisper submodule when needed, builds the CLI and app, validates the compiled `Cortexa.icns`, the `FoundationModels.framework` link, and runtime contents, creates a drag-and-drop DMG, verifies it, and writes a SHA-256 checksum and install notes. CI runs the same command on a fresh hosted runner, then attaches these three assets to the draft release.

```bash
./scripts/build_macos_open_source_release.sh
```

Expected assets:

- `artifacts/mac/Cortexa-<VERSION>.dmg`
- `artifacts/mac/Cortexa-<VERSION>.dmg.sha256`
- `artifacts/mac/Cortexa-<VERSION>-install-notes.txt`

The Finder DMG layout uses the matching 800 × 500 SVG background and `dmgbuild` metadata. `create_macos_dmg.sh` verifies the app's ad-hoc signature after packaging. Release builds contain no speech model; onboarding downloads one on first launch. The Whisper CLI is linked statically against Whisper/GGML, and `validate_macos_app_runtime.sh` verifies the executable and runtime manifest.

To prepare a draft from `main`, run **Actions → macOS Release** with `action=prepare` and the value from `VERSION`. The workflow finds the previous published release, asks GitHub's Release Notes API to summarize merged PRs, groups them using `.github/release.yml`, and includes contributors plus a full changelog link. A helper adds commit subjects and authors for direct commits that have no associated PR, so older work is not lost. PR titles must be descriptive on their own; apply one category label listed in `.github/PULL_REQUEST_TEMPLATE.md` before merging. The generated body removes emoji characters from PR titles, commit subjects, author names, and category headings. It also includes concise install guidance and a machine-readable source commit used by the publish check. The notes are suitable both for the draft and published release; there is no internal “publish this draft” text.

GitHub does not create the release tag while the release is a draft. After installation testing, run the same workflow with `action=publish` and the same version. The workflow checks branch, version, source commit, draft state and assets, then verifies the downloaded checksum and DMG before creating the tag at the tested source commit while publishing. For manual local verification steps, see [`macos-release-checklist.md`](macos-release-checklist.md). The old Developer ID archive, export, notarization, stapling, and Sparkle appcast scripts remain available for a future signed distribution, but they are not part of the current release path.

## Updater configuration

- The generated macOS project exposes two build-time values that should be provided before a production release:
  - `SPARKLE_FEED_URL`
  - `SPARKLE_PUBLIC_ED_KEY`
- `scripts/generate_macos_xcodeproj.sh` injects these values into the app `Info.plist`.
- The macOS app enables the updater only when both `SUFeedURL` and `SUPublicEDKey` are present.
- To generate a Sparkle appcast for a signed `.dmg`/`.zip`, use:

```bash
SPARKLE_PRIVATE_KEY_FILE=/path/to/sparkle_private_key \
SPARKLE_BIN_DIR=/path/to/sparkle/bin \
./scripts/generate_sparkle_appcast.sh
```

## iOS / iPadOS

1. **Regenerate the iOS project.**
   - Run `./scripts/generate_ios_xcodeproj.sh` whenever targets, extensions, or package references change so `apps/ios/WisprLocaliOS/WisprLocaliOS.xcodeproj` stays in sync with `project.yml`.

2. **Build host app + keyboard extension.**
   - Archive both the `WisprLocaliOS` and `WisprLocalKeyboard` targets via `xcodebuild`.
   - Example:

```bash
cd apps/ios/WisprLocaliOS
xcodebuild -scheme WisprLocaliOS -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath ../../artifacts/ios/WisprLocaliOS.xcarchive \
  archive
xcodebuild -scheme WisprLocalKeyboard -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath ../../artifacts/ios/WisprLocalKeyboard.xcarchive \
  archive
```

   - Set `CODE_SIGN_STYLE=Manual`, `CODE_SIGN_IDENTITY`, and provisioning specifiers for both the app and the keyboard extension. They must share the same Apple team and App Group `group.com.wisprlocal.shared` so the extension can exchange data with the host.

3. **Distribute via developer sideload.**
   - Export the archived packages via `xcodebuild -exportArchive` (method `ad-hoc` or `development` depending on the distribution channel) or upload to App Store Connect for internal/beta testing.
   - Ensure entitlements include the keyboard extension capability and that the `WisprLocaliOS.entitlements`/`WisprLocalKeyboard.entitlements` files reference the shared App Group.

## Update strategy

- macOS can provide an optional auto-update path via a Sparkle-style update feed. Sign every relaunchable updater build with the same Developer ID certificate and notarize before publishing update metadata.
- iOS updates follow the provisioning deployment process. Keep provisioning profiles current and regenerate archives whenever entitlements or App Group settings change.
