# macOS App Shell

This folder contains the SwiftUI MenuBarExtra-based macOS app target.

Planned Xcode target composition:

- `WisprLocalMacApp` (menu bar host)
- `SettingsWindowPresenter` (explicit settings window bootstrap for the agent app)
- `MenuBarContentView` (menu bar composition and quick settings surface)
- `SettingsViewShell` (sidebar + search + detail shell for settings)
- `MacAppState` (published UI state and orchestration)
- `MacAppPreferencesStore`, `SessionConfigurationBuilder`, `PermissionCoordinator`, `AppLifecycleCoordinator`, `SessionEntryController`, `TranscriptHistoryController` (internal app-state support services)
- `AIProviderController`, `SpeechModelController`, `SnippetController`, `DiagnosticsController` (remaining AppState feature clusters extracted behind the same published surface)
- `DictationRuntimeServices` (permission, focused-target, streaming insertion, final delivery helpers behind `DictationRuntime`)
- `SettingsSearchPresentation`, `SettingsFormPages`, `SearchResultsSettingsPage` (settings search/presentation and page composition helpers)
- links to Swift packages from `/Sources/*`
- entitlements: microphone + accessibility prompt UX
- hardened runtime + notarization-ready signing settings

Global hotkey default: `Option + Space`.
The active global hotkey can be recorded directly in the app settings; valid shortcuts require at least one modifier key and are stored persistently.
The settings also warn when the chosen shortcut overlaps with common macOS/system shortcuts such as Spotlight, input-source switching, app switching, quit, or common `Command` editing shortcuts.
An optional hold-to-dictate shortcut can be configured separately from the normal toggle shortcut and can also be disabled independently.
Final transcript delivery can be configured independently from recognition mode: insert into the current text target, or copy only to the clipboard.
The dictation settings also include a live rewrite scope that limits how far back partial transcripts may be reshaped while you keep speaking, so older sentences stabilize sooner instead of being rewritten wholesale.
Translation remains part of the dictation settings and is separate from language recognition: `Default` keeps the spoken language, `English` enables Whisper translation.
The settings now also include a dedicated `AI` area for post-processing with provider/model selection, style/tone, salutation, and separate toggles for live insertion and the final result.
The AI settings can host both Apple on-device processing and remote API providers without hardcoding a fixed model list; OpenRouter, OpenAI, Groq, Mistral, DeepSeek, Together AI, Fireworks AI, xAI, Ollama and LM Studio are available as presets, and custom OpenAI-compatible endpoints can be configured manually.
The `Sound` tab covers app-internal input level compensation, silence removal, dynamic normalization, and sound effects with volume control; it intentionally avoids global system microphone volume control or ambiguous playback-pausing behavior.
The settings now also split out a dedicated `Sound` tab plus separate app-behavior, text-input, model-warm-retention, and history-retention controls, so the sidebar reflects the app's own semantics instead of a copied foreign layout.
Text input keeps delivery, auto-send, clipboard restore, and simulated keystroke behavior separate so insertion semantics stay explicit.
App behavior now exposes Dock visibility, launch on login, and automatic update checks directly in the preferences UI.
The diagnostics area also includes optional technical logging that records detailed runtime and `whisper-cli` lifecycle events, including subprocess starts, exits, timeouts, and exportable diagnostic logs.

Operational notes:

- The app is configured as an agent/menu bar app (`LSUIElement = YES`), so it should not stay visible in the Dock.
- If menu bar hints are disabled, the menu bar shows only the state icon and no shortcut text.
- The menu bar menu now uses a compact status header only for active/problem states, one primary dictation action, quick dictation controls, contextual permission actions, and explicit footer actions for settings, updates, and quitting.
- The menu bar menu uses status pills and card-like groups so controls, permissions, and the latest dictation are visually separated without expanding the menu excessively.
- The menu bar quick settings group dictation inputs under a small `Application` section and only reveal the AI model, live/final toggles, style, and salutation controls once AI processing is enabled.
- `Settings…` from the menu bar opens an explicit preference-styled settings window, which is more reliable for the agent/menu bar app than relying on the default SwiftUI settings selector.
- The settings let you switch the visible app UI between German and English.
- The settings window is organized into a sidebar-driven preferences layout for general app preferences, dictation, shortcuts, history, about, snippets, and advanced options.
- The settings shell and the menu bar content are now split into dedicated files so UI structure stays separate from app bootstrap and state orchestration.
- The settings sidebar now also includes a dedicated `AI` tab, while translation remains under `Diktat` because it belongs to the ASR/transcription path rather than the text-rewrite provider layer.
- The settings use a fixed source-list sidebar plus a global native search field above the detail view, so switching sections and searching across areas stays compact and predictable.
- Settings search scans across all top-level areas and shows grouped results per section instead of restricting the search to the currently selected area.
- Menu bar quick settings expose the AI processing toggle plus, when enabled, the eligible model choice, live/final application toggles, style, salutation, and translation output without surfacing unavailable local models or remote models whose provider is disabled or missing credentials.
- When compact mode is disabled, the menu bar exposes direct pickers for LLM, AI mode, style, salutation, voice model, and voice quality; compact mode hides only the extra AI detail controls and keeps the core dictation actions visible.
- A compact menu bar design option keeps history, copy last dictation, separators, and update checks visible while moving AI application details into an `Apply for` flyout and an `AI settings…` shortcut to the preferences window.
- Search results reuse the same preference cards as the normal tabs, but without nesting full pane containers inside the search mode; this keeps the global search view flatter and closer to native macOS preferences behavior.
- The settings window keeps a fixed width so long history entries do not stretch the preferences layout horizontally.
- The settings window now leans more heavily on native macOS structures such as toolbar search, `Form`-based content flow, and restrained `GroupBox` grouping instead of a heavily custom header/search/card shell.
- The history tab shows compact transcript cards with short previews first; longer dictations can be expanded inline for the full text without destabilizing the window layout.
- The `About` tab introduces the product and author, includes a short profile of Leon Stadler based on his website, and links out to his personal site for more background; WisprLocal is proprietary software (see `docs/licensing.md`).
- The `About` tab also renders the bundled release notes from `changelog.md` in a styled changelog section, with a development fallback to the source tree when the bundle resource is temporarily unavailable.
- Advanced options contain updates and diagnostics; the diagnostics preview can be expanded and copied.
- The search results view announces grouped matches and uses clearer accessibility labels for the search field, result grouping, and transcript history previews.
- Repeated list actions (copy/delete in history and snippets) now include explicit contextual VoiceOver labels, and truncated menu previews expose full text through accessibility labels.
- Update management lives in the `Advanced` settings tab; Sparkle checks in the background, GitHub Releases act as the publication source, and the manual check can be triggered there as well.
- The menu bar menu weights its primary dictation action more strongly than utility footer actions, so `Settings…`, updates, and quit read more like classic menu utilities than like equal-priority content blocks.
- The general, sound, history, and advanced settings tabs now cover Dock visibility, launch on login, automatic update checks, audio preprocessing, sound effects, transcript-history retention, and the current app data folder reveal path. Relocating the data folder itself remains a later migration step because the snippets/history/logs layout must be migrated together.
- The macOS target now includes an asset catalog under `apps/macos/AppShell/Resources/Assets.xcassets` with a first Accent Color and App Icon set, wired into XcodeGen via `ASSETCATALOG_COMPILER_APPICON_NAME` and `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME`.
- The bundled Whisper runtime is resolved robustly from either `Contents/Resources/Runtime` or a flattened `Contents/Resources` layout, so resource packaging changes do not break dictation startup.
- Diagnostics are shown in a compressed preview first and can be expanded for the full log text, which can also be copied to the clipboard.
- Streaming quality now uses the capability preset values for beam size, decode cadence, and thread count rather than only switching the model file; `balanced` and `accurate` also use a more conservative streaming commit strategy than `fast`.
- The live rewrite scope in settings lets you choose how aggressively the current streaming tail may adapt, from only the current sentence up to a much wider context.
- Apple on-device AI processing is offered as an optional post-processing layer only on supported Macs; if the Apple model is unavailable or fails, dictation falls back to the raw transcript instead of failing the session.
- Remote AI processing can be added through provider presets or custom OpenAI-compatible API endpoints. Models are discovered dynamically from the provider catalog, API keys are stored in the macOS Keychain, and providers without credentials stay out of the quick settings until they are operational. Local OpenAI-compatible servers such as Ollama or LM Studio can also run without an API key.
- Auto language detection no longer implies translation. The spoken language is preserved unless translation is explicitly enabled.
- Basic speech-activity gating suppresses no-speech hallucinations so short idle outputs such as `Musik` are less likely to be inserted when the microphone captures no real dictation.
- Accessibility readiness now uses the same focused-target AX probe as the insertion pipeline. The UI only reports direct insertion as available when the system-wide AX focus path is actually readable, which avoids false-positive "granted" states where insertion later fails with `kAXErrorAPIDisabled`.
- If the focused text element briefly disappears during startup, the dictation runtime can recover by reusing the last known AX text target in the same frontmost app.
- Dictation can start even when no text field is currently active; streaming waits and inserts once a target is focused, and the final transcript waits up to five seconds after stop before either inserting, copying to the clipboard, or falling back to history-only retention depending on the chosen delivery mode.
- Recoverable streaming target errors no longer push the whole runtime into a broken state; the runtime keeps the current transcript buffered and resumes insertion when a writable text target becomes available again.
- Final-delivery diagnostics now record whether the result was written via direct AX value-set, clipboard paste fallback, or simulated keyboard input, and whether clipboard restore plus auto-send actually ran.
- Clipboard restoration now snapshots and restores the full pasteboard item list for clipboard-based delivery instead of only restoring a plain string value.
- AppShell refactors are guarded by a dedicated `AppShellSupport` SwiftPM target plus characterization and controller tests so permission flows, history retention, session entry, provider editing, settings search, and the extracted AppShell controllers can be validated without shipping behavior changes.
- Runtime start now guards against duplicate starts while initialization is in-flight and performs a full reset on audio push failures, reducing stuck `Diktat läuft bereits` error loops.
- Version metadata is injected into the generated Xcode project from the repo `VERSION` file.
- The macOS helper scripts look for `xcodegen` in common Homebrew locations and can reuse an already generated `WisprLocalMac.xcodeproj` if regeneration is not needed.
- Release archives can be created with `scripts/archive_macos_release.sh`.
- Release exports, DMG creation and Sparkle appcasts are scripted via `scripts/export_macos_release.sh`, `scripts/create_macos_dmg.sh` and `scripts/generate_sparkle_appcast.sh`.
- Sparkle is embedded into the app rather than run as a separate helper; the appcast/feed points at your release artifacts and the app handles checking and installing updates itself.
- Optional production configuration is read from the app bundle `Info.plist`: `WLMLicensePublicKeyBase64`, `SUFeedURL`, `SUPublicEDKey`, `WLMEnableInternalLicenseUI`.
- The license infrastructure is kept in the codebase for future internal development, but the public settings UI hides license and support controls unless `WLMEnableInternalLicenseUI` is explicitly enabled.
