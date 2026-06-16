# Distribution Pipeline

## macOS release workflow

1. **Build dependencies and runtime.**
   - Run `./scripts/build_whisper_xcframework.sh` (see `docs/build-xcframework.md`) to produce `artifacts/whisper/whisper-cli` and, when requested, `artifacts/whisper/whisper.xcframework`.
   - Download the required ggml models with `./scripts/download_models.sh`.
   - Bundle the CLI and models into `apps/macos/AppShell/Resources/Runtime` using `./scripts/prepare_runtime_bundle.sh` so the app can install a bundled runtime at launch.

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
./scripts/archive_macos_release.sh
```

   - The archive is written to `artifacts/mac/WisprLocalMac.xcarchive`.
   - Manual equivalent for the generated Xcode project:

```bash
cd apps/macos/WisprLocalMac
xcodebuild -project WisprLocalMac.xcodeproj \
  -scheme WisprLocalMac \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -archivePath ../../artifacts/mac/WisprLocalMac.xcarchive \
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
./scripts/verify_macos_release_bundle.sh artifacts/mac/release/WisprLocalMac.app
```

   - This script calls `codesign`, `spctl`, and `xcrun stapler validate`, so a failure surfaces before notarization.

6. **Notarize and staple.**
   - Submit the signed artifact to Apple with `xcrun notarytool submit artifacts/mac/release/WisprLocalMac.app` using the `--keychain-profile` that points at the Developer ID credentials tied to your release team, and include `--wait` so the command only returns once processing is complete.
   - After Apple reports success, staple the ticket with:

```bash
xcrun stapler staple artifacts/mac/release/WisprLocalMac.app
```

   - Re-run `./scripts/verify_macos_release_bundle.sh` after stapling to confirm the notarization flag is present.

7. **Package for distribution.**
   - Preferred path for drag-and-drop distribution:

```bash
CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
./scripts/create_macos_dmg.sh
```

   - This creates `artifacts/mac/WisprLocalMac.dmg` from the exported `.app`.
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
