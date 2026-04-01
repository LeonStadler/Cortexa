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
An optional hold-to-dictate shortcut can be configured separately from the normal toggle shortcut and can also be disabled independently.
Final transcript delivery can be configured independently from recognition mode: insert into the current text target, or copy only to the clipboard.
The dictation settings also include a live rewrite scope that limits how far back partial transcripts may be reshaped while you keep speaking, so older sentences stabilize sooner instead of being rewritten wholesale.

Operational notes:

- The app is configured as an agent/menu bar app (`LSUIElement = YES`), so it should not stay visible in the Dock.
- If menu bar hints are disabled, the menu bar shows only the state icon and no shortcut text.
- The menu bar menu now uses a compact status header only for active/problem states, one primary dictation action, quick dictation controls, contextual permission actions, and explicit footer actions for settings, updates, and quitting.
- The menu bar menu uses status pills and card-like groups so controls, permissions, and the latest dictation are visually separated without expanding the menu excessively.
- `Settings…` from the menu bar opens an explicit preference-styled settings window, which is more reliable for the agent/menu bar app than relying on the default SwiftUI settings selector.
- The settings let you switch the visible app UI between German and English.
- The settings window is organized into tabs for general app preferences, dictation, shortcuts, history, and advanced options.
- The settings header now uses a native segmented control for those areas, so switching sections stays compact and visually aligned with current macOS preference patterns.
- Settings search now uses a native toolbar search field via SwiftUI `.searchable(...)`; when active, it searches across all tabs and shows grouped results per area instead of restricting the search to the currently selected tab.
- Search results reuse the same preference cards as the normal tabs, but without nesting full pane containers inside the search mode; this keeps the global search view flatter and closer to native macOS preferences behavior.
- The settings window keeps a fixed width so long history entries do not stretch the preferences layout horizontally.
- The settings window now leans more heavily on native macOS structures such as toolbar search, `Form`-based content flow, and restrained `GroupBox` grouping instead of a heavily custom header/search/card shell.
- The history tab shows compact transcript cards with short previews first; longer dictations can be expanded inline for the full text without destabilizing the window layout.
- Advanced options contain snippets, diagnostics, and license handling; the diagnostics preview can be expanded and copied.
- The search results view announces grouped matches and uses clearer accessibility labels for the search field, result grouping, and transcript history previews.
- Repeated list actions (copy/delete in history and snippets) now include explicit contextual VoiceOver labels, and truncated menu previews expose full text through accessibility labels.
- Update management stays in the menu bar menu instead of the Settings window; if an update state becomes available, the menu header can surface it as a compact badge while the rest of the menu remains visually restrained.
- The menu bar menu weights its primary dictation action more strongly than utility footer actions, so `Settings…`, updates, and quit read more like classic menu utilities than like equal-priority content blocks.
- The macOS target now includes an asset catalog under `apps/macos/AppShell/Resources/Assets.xcassets` with a first Accent Color and App Icon set, wired into XcodeGen via `ASSETCATALOG_COMPILER_APPICON_NAME` and `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME`.
- The bundled Whisper runtime is resolved robustly from either `Contents/Resources/Runtime` or a flattened `Contents/Resources` layout, so resource packaging changes do not break dictation startup.
- Diagnostics are shown in a compressed preview first and can be expanded for the full log text, which can also be copied to the clipboard.
- Streaming quality now uses the capability preset values for beam size, decode cadence, and thread count rather than only switching the model file; `balanced` and `accurate` also use a more conservative streaming commit strategy than `fast`.
- The live rewrite scope in settings lets you choose how aggressively the current streaming tail may adapt, from only the current sentence up to a much wider context.
- Basic speech-activity gating suppresses no-speech hallucinations so short idle outputs such as `Musik` are less likely to be inserted when the microphone captures no real dictation.
- If the focused text element briefly disappears during startup, the dictation runtime can recover by reusing the last known AX text target in the same frontmost app.
- Dictation can start even when no text field is currently active; streaming waits and inserts once a target is focused, and the final transcript waits up to five seconds after stop before either inserting, copying to the clipboard, or falling back to history-only retention depending on the chosen delivery mode.
- Recoverable streaming target errors no longer push the whole runtime into a broken state; the runtime keeps the current transcript buffered and resumes insertion when a writable text target becomes available again.
- Runtime start now guards against duplicate starts while initialization is in-flight and performs a full reset on audio push failures, reducing stuck `Diktat läuft bereits` error loops.
- Version metadata is injected into the generated Xcode project from the repo `VERSION` file.
- The macOS helper scripts look for `xcodegen` in common Homebrew locations and can reuse an already generated `WisprLocalMac.xcodeproj` if regeneration is not needed.
- Release archives can be created with `scripts/archive_macos_release.sh`.
- Release exports, DMG creation and Sparkle appcasts are scripted via `scripts/export_macos_release.sh`, `scripts/create_macos_dmg.sh` and `scripts/generate_sparkle_appcast.sh`.
- Optional production configuration is read from the app bundle `Info.plist`: `WLMLicensePublicKeyBase64`, `SUFeedURL`, `SUPublicEDKey`.
