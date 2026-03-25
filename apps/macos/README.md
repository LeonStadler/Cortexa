# macOS App Shell

This folder contains the SwiftUI MenuBarExtra-based macOS app target.

Planned Xcode target composition:

- `WisprLocalMacApp` (menu bar host)
- links to Swift packages from `/Sources/*`
- entitlements: microphone + accessibility prompt UX
- hardened runtime + notarization-ready signing settings

Global hotkey default: `Option + Space`.
The active global hotkey can be recorded directly in the app settings; valid shortcuts require at least one modifier key and are stored persistently.
The settings also warn when the chosen shortcut overlaps with common macOS/system shortcuts such as Spotlight, input-source switching, app switching, quit, or common `Command` editing shortcuts.
An emergency shortcut `Control + Option + Escape` is always reserved to stop an active dictation session quickly.

Operational notes:

- The app is configured as an agent/menu bar app (`LSUIElement = YES`), so it should not stay visible in the Dock.
- If menu bar hints are disabled, the menu bar shows only the state icon and no shortcut text.
- The menu bar stays intentionally compact and exposes only the primary actions: start/stop, copy the last dictation, open settings, and quit.
- `Open Settings` from the menu bar opens an explicit `WisprLocal Settings` window, which is more reliable for the agent/menu bar app than relying on the default SwiftUI settings selector.
- The settings let you switch the visible app UI between German and English.
- The settings window is organized into tabs for general app preferences, dictation, history, snippets, permissions, diagnostics, and license handling.
- Diagnostics are shown in a compressed preview first and can be expanded for the full log text, which can also be copied to the clipboard.
- Streaming quality now uses the capability preset values for beam size, decode cadence, and thread count rather than only switching the model file; `balanced` and `accurate` also use a more conservative streaming commit strategy than `fast`.
- If the focused text element briefly disappears during startup, the dictation runtime can recover by reusing the last known AX text target in the same frontmost app.
- Dictation can start even when no text field is currently active; streaming waits and inserts once a target is focused, and the final transcript waits up to five seconds after stop before falling back to history-only retention.
- Version metadata is injected into the generated Xcode project from the repo `VERSION` file.
- Release archives can be created with `scripts/archive_macos_release.sh`.
- Release exports, DMG creation and Sparkle appcasts are scripted via `scripts/export_macos_release.sh`, `scripts/create_macos_dmg.sh` and `scripts/generate_sparkle_appcast.sh`.
- Optional production configuration is read from the app bundle `Info.plist`: `WLMLicensePublicKeyBase64`, `SUFeedURL`, `SUPublicEDKey`.
