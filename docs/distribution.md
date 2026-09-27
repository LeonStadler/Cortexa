# Distribution Pipeline

## macOS release workflow

- The visible product name and generated app bundle are **Cortexa** (`Cortexa.app`); the target, project, and scheme retain their `WisprLocalMac` technical names, and the bundle identifier remains `com.wisprlocal.mac` for permission, preference, and update continuity.
- `Cortexa.icon` is the only Dock icon source. It provides automatic fill, translucency, and adaptive appearance rendering for the system's Liquid Glass icon treatment; its explicit dark specialization swaps in a white glyph so it remains readable on the dark glass background. The horizontal and stacked Cortexa logos are packaged separately as vector imagesets in the same asset catalog.
- The drag-and-drop DMG uses a Finder background SVG matching the configured 800 × 500 Finder window canvas. `create_macos_dmg.sh` converts it with `sips` and uses pinned `dmgbuild` settings to write the background, window size, and icon positions directly into the disk image's Finder metadata. The script creates a project-local Python environment from `scripts/requirements-macos-dmg.txt`; Quick Look thumbnails are intentionally not used because their dimensions can alter artwork scale and alignment.
- Cortexa remains a menu bar app (`LSUIElement = YES`). Release builds show a visible setup/settings window on first launch so opening the app from a DMG or GitHub download has an observable result even before the user notices the status item.
- GitHub Releases are the primary distribution channel. Update archives are never ad-hoc signed: local-only continuity tests use an Apple Development identity on the developer's Mac, while published DMGs use the same Developer ID identity, notarization, stapling, and verification.
- Sparkle is prepared but only active when both `SPARKLE_FEED_URL` and `SPARKLE_PUBLIC_ED_KEY` are set. Builds without those values show GitHub release guidance instead of a disabled manual-update button.
- `archive_macos_release.sh` requires `CODE_SIGN_IDENTITY` and verifies an Apple TeamIdentifier after archiving. It deliberately refuses ad-hoc archives because macOS TCC permissions are tied to the signed app identity.

1. **Build dependencies and runtime.**
   - Run `./scripts/build_whisper_xcframework.sh` (see `docs/build-xcframework.md`) to produce `artifacts/whisper/whisper-cli` and, when requested, `artifacts/whisper/whisper.xcframework`. The macOS CLI is linked statically against Whisper/GGML so it does not retain build-machine `@rpath` dependencies.
- The build and bundle preparation run `./scripts/verify_whisper_cli_runtime.sh`. This gate rejects non-system dynamic-library dependencies and proves that the copied CLI can launch before an app archive is created.
- `archive_macos_release.sh` and `smoke_test_macos_app.sh` validate the finished app bundle with `scripts/validate_macos_app_runtime.sh`: the bundled CLI must be executable and launch with `--help`, the models directory must exist, and `runtime-manifest.json` must parse as JSON. The packaging/smoke environment therefore needs Python 3 for the JSON check.
   - Download the required ggml models with `./scripts/download_models.sh`.
   - Bundle the CLI into `apps/macos/AppShell/Resources/Runtime` using `./scripts/prepare_runtime_bundle.sh` (Release: no bundled `.bin`; the standard model downloads during first-run onboarding).
   - Cortexa downloads a model into a private temporary workspace and then promotes it from a hidden `.partial` staging file into the models directory only after the download is complete. A later runtime sync removes only Cortexa's abandoned temporary workspaces and staging files; completed `.bin` models and unrelated temporary files remain untouched.
   - For local dev/smoke tests, pass `--include-default-model` to bundle `ggml-base.bin` alongside the CLI.
   - `./scripts/smoke_test_macos_app.sh` additionally synthesizes a spoken fixture and transcribes it with the CLI and model from the built app bundle. This is the automated ASR runtime E2E; microphone permission, focus retention, and insertion into TextEdit/Notes/VS Code remain the manual UI E2E layer in the release checklist.

2. **Regenerate the Xcode project if schema or package changes were introduced.**
   - `./scripts/generate_macos_xcodeproj.sh` keeps `apps/macos/WisprLocalMac/WisprLocalMac.xcodeproj` aligned with `project.yml`.
   - The script injects `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` from the repository `VERSION` file.
   - Before the first production archive on a machine, run:

```bash
./scripts/preflight_macos_release.sh
```

   - This validates release environment variables, bundled runtime assets and the generated project metadata before signing/notarization begins.

3. **Archive a signed release build.**
   - Preferred path: use the wrapper script, which prepares the runtime bundle, regenerates the project, and archives the release build in one step:

```bash
DEVELOPMENT_TEAM=YOURTEAMID CODE_SIGN_IDENTITY="Developer ID Application" \
./scripts/archive_macos_release.sh
```

   - The archive is written to `artifacts/mac/Cortexa.xcarchive`.
   - Manual equivalent for the generated Xcode project:

```bash
cd apps/macos/WisprLocalMac
xcodebuild -project WisprLocalMac.xcodeproj \
  -scheme WisprLocalMac \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -archivePath ../../artifacts/mac/Cortexa.xcarchive \
  archive
```

4. **Export the signed product.**
   - Preferred path: export via the wrapper script:

```bash
DEVELOPMENT_TEAM=YOURTEAMID ./scripts/export_macos_release.sh
```

   - The script writes the exported product into `artifacts/mac/release`.
   - Manual equivalent: use `xcodebuild -exportArchive` with an `exportOptions.plist` that specifies `method = developer-id`, `destination = export`, and the chosen `signingStyle`.

5. **Signing and hardening checks.**
   - Confirm the app is signed with `CODE_SIGN_IDENTITY = Developer ID Application`. The generated release target enables Hardened Runtime by default.
   - Ensure any additional entitlements are intentional; the base target is configured as a menu bar agent app (`LSUIElement = YES`) and does not require a Dock icon.
   - After the export, run gatekeeper verification:

```bash
./scripts/verify_macos_release_bundle.sh artifacts/mac/release/Cortexa.app
```

   - This script calls `codesign`, `spctl`, and `xcrun stapler validate`, so a failure surfaces before notarization.

6. **Notarize and staple.**
   - Submit the signed artifact to Apple with `xcrun notarytool submit artifacts/mac/release/Cortexa.app` using the `--keychain-profile` that points at the Developer ID credentials tied to your release team, and include `--wait` so the command only returns once processing is complete.
   - After Apple reports success, staple the ticket with:

```bash
xcrun stapler staple artifacts/mac/release/Cortexa.app
```

   - Re-run `./scripts/verify_macos_release_bundle.sh` after stapling to confirm the notarization flag is present.

7. **Package for distribution.**
   - Preferred path for drag-and-drop distribution:

```bash
CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
./scripts/create_macos_dmg.sh
```

   - This creates `artifacts/mac/Cortexa.dmg` from the exported `.app`.
   - Without a Developer ID identity and notarization, treat the DMG as a local-use artifact. Publish only notarized DMGs to GitHub Releases.
   - If an installer workflow is required, use `productbuild` with the matching Developer ID Installer certificate and re-run `./scripts/verify_macos_release_bundle.sh` on the resulting `.pkg`.

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
