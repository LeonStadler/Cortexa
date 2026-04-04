# WisprLocal

Offline-first dictation and transcription stack for Apple platforms with a macOS-first UX.

## Goals

- 100% local/offline transcription (no cloud ASR, no telemetry)
- Apple Silicon optimized runtime presets
- Deterministic insertion behavior on macOS (AX-first, optional paste fallback)
- Shared core for macOS + iOS/iPadOS (keyboard extension workflow on iOS)
- Offline license key verification (Ed25519)

## Repository Layout

- `Package.swift`: Swift package workspace for core modules
- `Sources/ASRCore`: Whisper engine, model registry, runtime installer, ASR types
- `Sources/AudioCore`: AVAudioEngine capture pipeline
- `Sources/SessionCore`: session state machine + streaming stabilizer
- `Sources/SnippetCore`: snippet matching + persistence
- `Sources/TextTargetMac`: macOS Accessibility target capture/insertion
- `Sources/CapabilityCore`: capability profiling and adaptive presets
- `Sources/AIProcessingCore`: provider-agnostic AI post-processing, model catalog, Apple on-device integration, dynamic remote API providers
- `Sources/LicenseCore`: offline license key codec, verifier, secure storage
- `apps/macos`: macOS app shell blueprint
- `apps/ios`: iOS app + keyboard extension blueprint
- `docs`: architecture, permissions, licensing, build/distribution docs
- `scripts`: whisper.cpp bootstrap/build/package helpers

## End-user install model

Users only install the app.

- runtime (`whisper-cli`) and models are bundled inside app resources
- app installs runtime assets locally on first use
- no Homebrew/CMake dependency on user machines

## Build

```bash
swift build
```

```bash
swift test
```

## Runtime packaging flow (developer)

```bash
./scripts/bootstrap_whisper_submodule.sh
./scripts/build_whisper_xcframework.sh
./scripts/download_models.sh
./scripts/prepare_runtime_bundle.sh
```

Then include `apps/macos/AppShell/Resources/Runtime` in app resources.

Details: `docs/build-xcframework.md`.

## macOS App Run (Menu Bar + Hotkey)

1. Build runtime assets once:
```bash
./scripts/build_whisper_xcframework.sh
./scripts/download_models.sh
./scripts/prepare_runtime_bundle.sh
./scripts/generate_macos_xcodeproj.sh
```
2. Open:
- `apps/macos/WisprLocalMac/WisprLocalMac.xcodeproj`
3. Run target `WisprLocalMac`.
4. In app settings grant:
- Microphone
- Accessibility for direct text insertion
5. Start/stop dictation:
- Menu bar button
- Global hotkey `Option + Space`
6. Verhalten:
- Die App läuft als reine Menüleisten-App (`LSUIElement`) und erscheint nicht dauerhaft im Dock.

Features implemented in macOS app shell:
- Finalize Insert at locked original cursor target
- Streaming Insert with immutable target binding
- Snippet replacement + snippet import/export (JSON)
- Transkript-History mit Copy/Delete/Clear + Export (TXT), lokal persistent
- Language switch (`de`, `en`, `auto`) and profile presets (`auto`, `fast`, `balanced`, `accurate`)
- Explizite Translation-Ausgabe (`Keine Übersetzung` oder `Nach Englisch`), getrennt von der Sprachwahl
- Optionales AI Processing mit Apple-On-Device- und API-Modellkatalog, Stil/Ton, Anrede sowie getrennten Aktivierungen für Live-Einfügen und finales Ergebnis
- Dynamische API-Anbieter fuer Text-Postprocessing ohne fest verdrahtete Modellliste; OpenRouter und weitere Presets wie OpenAI, Groq, Mistral, DeepSeek, Together AI, Fireworks AI, xAI, Ollama und LM Studio lassen sich ueber dieselbe OpenAI-kompatible Surface anbinden, Modelle werden per `/models` geladen und API-Keys landen im Keychain
- App-internes Audio-Preprocessing mit Eingangsverstärkung, Stille-Entfernung und dynamischer Normalisierung sowie optionalem Soundfeedback fuer Start/Stop/Fehler mit einstellbarer Lautstärke
- Die macOS-Einstellungen sind jetzt semantisch in `Sound`, App-Verhalten, Texteingabe, Shortcuts, AI-Modelle und Verlauf gegliedert; neue Schalter fuer Dock-Sichtbarkeit, Login-Start, Update-Pruefung, Audio-Preprocessing, Soundeffekte, Auto-Send, Clipboard-Restore, History-Aufbewahrung und die Sprachmodell-Laufzeit unter `Erweitert` sind direkt in der UI sichtbar
- Offline licensing UI (key input, local verification, Keychain-only secret persistence with legacy cache cleanup)
- Lokales Audit-Log mit Rotation (`~/Library/Application Support/WisprLocal/audit.log`)
- Optionale technische Diagnoseprotokollierung mit detaillierten Runtime-/Subprozess-Logs (`~/Library/Application Support/WisprLocal/debug.log`) inklusive `whisper-cli`-Starts, Exit-Codes und Timeouts
- macOS-Lifecycle-Settings fuer Dock-Sichtbarkeit, Login-Start und automatische Update-Pruefung sowie lokale History-Aufbewahrung und den aktuellen App-Datenordner
- Diagnostics-Export (`wispr-diagnostics.txt`) und Audit-Log-Export aus der macOS-UI
- Sparkle-kompatibler Auto-Updater mit permanent sichtbarem manuellen Check im Menü und in den Settings
- Lifecycle-Refresh nach App-Aktivierung und System-Wake für Berechtigungen, Runtime und Hotkey-Registrierung
- Eingeschränkter Transkriptionsmodus ohne Bedienungshilfen; direktes Einfügen bleibt dann deaktiviert, Verlauf und Zwischenablage bleiben nutzbar
- Interner Speicher für Snippets, Verlauf und Audit-Dateien wird lokal gehärtet; Zwischenablage-Fallback bleibt absichtlich optional und ist als weniger privater Zustellpfad gekennzeichnet
- Auto-Spracherkennung steuert nur noch die Transkription; Ubersetzung nach Englisch wird ausschliesslich ueber die separate Translation-Option aktiviert

## macOS Release Archive

```bash
./scripts/archive_macos_release.sh
```

Optional for explicit signing on CI or another machine:

```bash
DEVELOPMENT_TEAM=YOURTEAMID CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
./scripts/archive_macos_release.sh
```

The archive is written to:
- `artifacts/mac/WisprLocalMac.xcarchive`

## macOS Release Export / DMG / Appcast

Die Release-Konfiguration wird über Build-Umgebungsvariablen in das generierte Xcode-Projekt injiziert:

- `WISPR_LICENSE_PUBLIC_KEY_BASE64`: echter Ed25519-Public-Key für Offline-Lizenzen
- `SPARKLE_FEED_URL`: HTTPS-Appcast-Feed für den Updater
- `SPARKLE_PUBLIC_ED_KEY`: Sparkle Public EdDSA Key

Vor dem eigentlichen Release-Lauf:

```bash
./scripts/preflight_macos_release.sh
```

Die vollständige manuelle Abnahme-Checkliste liegt in:
- `docs/macos-release-checklist.md`

Archiv exportieren:

```bash
DEVELOPMENT_TEAM=YOURTEAMID ./scripts/export_macos_release.sh
```

DMG erzeugen:

```bash
CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
./scripts/create_macos_dmg.sh
```

Sparkle-Appcast generieren:

```bash
SPARKLE_PRIVATE_KEY_FILE=/path/to/sparkle_private_key \
SPARKLE_BIN_DIR=/path/to/generate_appcast \
./scripts/generate_sparkle_appcast.sh
```

After export/notarization validate the resulting bundle with:

```bash
./scripts/verify_macos_release_bundle.sh artifacts/mac/release/WisprLocalMac.app
```

## macOS Smoke Test

For a local end-to-end development smoke test of the macOS app bundle:

```bash
./scripts/smoke_test_macos_app.sh
```

This verifies:
- debug app build succeeds
- `WisprLocalMac.app` exists
- bundled `Runtime/whisper-cli` exists in the app bundle
- bundled ggml model files exist
- app process launches and stays alive for a short sanity window
- app activation and the Settings shortcut exercise the live UI path when possible

If you want the app to remain running after the smoke test:

```bash
./scripts/smoke_test_macos_app.sh --keep-running
```

If you want to skip the automatic UI exercise and only validate build/runtime startup:

```bash
./scripts/smoke_test_macos_app.sh --no-ui
```

For CI or headless verification without launching the app process:

```bash
./scripts/smoke_test_macos_app.sh --skip-launch
```

## iOS / iPadOS Project Run

1. Generate the iOS project:
```bash
bash ./scripts/generate_ios_xcodeproj.sh
```
2. Open:
- `apps/ios/WisprLocaliOS/WisprLocaliOS.xcodeproj`
3. Configure your Apple account/team for:
- `WisprLocaliOS`
- `WisprLocalKeyboard`
4. Enable the shared app group:
- `group.com.wisprlocal.shared`
5. Build the app and extension on a real iPhone/iPad or iOS 17+ simulator.

Features implemented in iOS shell:
- Host app with shared snippets, transcript history and offline license UI
- Keyboard extension with latest approved transcript insert and shared snippet quick insert
- Shared App Group persistence is required; there is no silent local fallback when the group is unavailable
- Shared App Group files are written with platform file protection; raw license keys remain in Keychain instead of plaintext shared cache files, and iOS transcript history stays local to the host app
