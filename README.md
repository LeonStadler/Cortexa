# Cortexa - Local Wisper

Offline-first Diktat und Transkription für **macOS** (Schwerpunkt) und **iOS/iPadOS** (Tastatur-Extension-Workflow). Technische Ziele und Modulgrenzen unten; **vollständige Funktions-/Implementierungsmatrix:** [`docs/features-and-implementation.md`](docs/features-and-implementation.md).

## Lizenz: Apache-2.0

Cortexa ist quelloffen und unter der [Apache License 2.0](LICENSE) lizenziert. Copyright- und Markenhinweise stehen in [`NOTICE`](NOTICE); Drittanbieterkomponenten und Modelle behalten ihre jeweiligen Lizenzen. Details: [`docs/licensing.md`](docs/licensing.md).

## Dokumentation (Index)

| Ressource                                                                    | Zweck                                           |
| ---------------------------------------------------------------------------- | ----------------------------------------------- |
| [`docs/README.md`](docs/README.md)                                           | Alle Docs im Überblick                          |
| [`docs/features-and-implementation.md`](docs/features-and-implementation.md) | Funktionen ↔ Module ↔ AppShell                  |
| [`docs/system-design.md`](docs/system-design.md)                             | Architektur, Datenflüsse, State Machine         |
| [`docs/api-design.md`](docs/api-design.md)                                   | Swift-Protokolle, Konfiguration, Pipeline       |
| [`docs/permissions-macos.md`](docs/permissions-macos.md)                     | Mikrofon, Bedienungshilfen                      |
| [`docs/build-xcframework.md`](docs/build-xcframework.md)                     | whisper.cpp / Runtime-Bundle                    |
| [`docs/distribution.md`](docs/distribution.md)                               | Offene macOS-DMG-Releases, optionale Signierung, Sparkle, iOS |
| [`docs/macos-release-checklist.md`](docs/macos-release-checklist.md)         | Release-Abnahme                                 |
| [`apps/macos/README.md`](apps/macos/README.md)                               | Menüleiste, Settings, Betrieb                   |
| [`apps/ios/README.md`](apps/ios/README.md)                                   | Host-App, Keyboard, App Group                   |
| [`changelog.md`](changelog.md)                                               | Release Notes (auch in der macOS-About-Ansicht) |

## Ziele (Produkt)

- **100 % lokale** Spracherkennung per whisper.cpp — **kein Cloud-ASR**, keine Telemetrie für die Kernfunktion
- **Apple-Silicon**-orientierte Laufzeit-Presets (`CapabilityCore`)
- **Deterministisches Einfügen** auf macOS: Accessibility zuerst, optional Paste-Fallback
- **Gemeinsame Swift-Pakete** für macOS und iOS (`Package.swift`)
- **Optionale** KI-Nachbearbeitung: Apple On-Device und/oder **OpenAI-kompatible** APIs (Netz nur bei aktivem API-Betrieb)

## Repository-Layout

- `Package.swift` — Swift Package (Libraries)
- `Sources/ASRCore` — Whisper, Modell-Registry, Runtime-Installer
- `Sources/AudioCore` — AVAudioEngine, Preprocessing-Hooks
- `Sources/SessionCore` — Session-State-Machine, Streaming-Stabilisator
- `Sources/SnippetCore` — Snippets, Persistenz
- `Sources/TextTargetMac` — AX-Ziel, Einfügen (macOS)
- `Sources/CapabilityCore` — Geräteprofil, adaptive Presets
- `Sources/AIProcessingCore` — KI-Nachbearbeitung, Provider, Apple Foundation Models
- `apps/macos` — Cortexa (MenuBarExtra; technical target `WisprLocalMac`)
- `apps/ios` — Host-App + Keyboard Extension
- `docs/` — Architektur, Build, Distribution, Permissions
- `scripts/` — whisper.cpp, XcodeGen, Release-Helfer

## Build & Tests (Swift Package)

```bash
swift build
swift test
```

## Endnutzer-Modell

Nutzer installieren nur die **App**. Runtime (`whisper-cli`) und Modelle liegen **im App-Bundle**; beim ersten Gebrauch werden sie ins Application Support installiert — **kein Homebrew/CMake** auf dem Zielrechner nötig.

## Runtime einmalig bauen (Entwickler)

```bash
./scripts/bootstrap_whisper_submodule.sh
./scripts/build_whisper_xcframework.sh
./scripts/download_models.sh
./scripts/prepare_runtime_bundle.sh
```

Anschließend `apps/macos/AppShell/Resources/Runtime` ins Xcode-Target einbinden. Details: [`docs/build-xcframework.md`](docs/build-xcframework.md).

## macOS: lokal starten

1. Am schnellsten direkt per Script starten:
   ```bash
   ./scripts/smoke_test_macos_app.sh
   ```
2. Runtime wie oben vorbereiten, dann:
   ```bash
   ./scripts/generate_macos_xcodeproj.sh
   ```
3. Projekt öffnen: `apps/macos/WisprLocalMac/WisprLocalMac.xcodeproj`
4. Target **WisprLocalMac** starten
5. **Berechtigungen:** Mikrofon, Bedienungshilfen (für direktes Einfügen)
6. **Diktat:** Menüleisten-Button oder globaler Hotkey (Standard **⌥ Space**)
7. **Agent-App:** `LSUIElement` — standardmäßig keine Dock-Ikone (optional in den Settings aktivierbar)

Ohne Script geht es direkt in Xcode so:

1. Runtime wie oben vorbereiten.
2. `./scripts/generate_macos_xcodeproj.sh` ausführen, damit das Xcode-Projekt aktuell ist.
3. `apps/macos/WisprLocalMac/WisprLocalMac.xcodeproj` in Xcode öffnen.
4. Scheme `WisprLocalMac` auswählen und auf `Run` drücken.

### macOS — implementierte Funktionen (Kurzliste)

Features implemented in macOS app shell:

- Finalize Insert at locked original cursor target
- Streaming Insert with immutable target binding
- Snippet replacement + snippet import/export (JSON)
- Transkript-History mit Copy/Delete/Clear + Export (TXT), lokal persistent
- Language switch (`de`, `en`, `auto`) and profile presets (`auto`, `fast`, `balanced`, `accurate`)
- Optional formatting/AI post-processing with configurable context awareness (`off`, `finalOnly`, `liveOnly`, `liveAndFinal`)
- Personal dictionary with category-based terms, review queue, and JSON import/export
- Dictionary-driven ASR prompt hints and dictionary-preservation hints for AI revisions
- Optional best-effort music pause/resume while dictating (Apple Music, Spotify)
- Lokales Audit-Log mit Rotation (`~/Library/Application Support/WisprLocal/audit.log`)
- Diagnostics-Export (`wispr-diagnostics.txt`) und Audit-Log-Export aus der macOS-UI
- Sparkle-kompatibler Auto-Updater mit permanent sichtbarem manuellen Check im Menü und in den Settings
- Lifecycle-Refresh nach App-Aktivierung und System-Wake für Berechtigungen, Runtime und Hotkey-Registrierung
- Eingeschränkter Transkriptionsmodus ohne Bedienungshilfen; direktes Einfügen bleibt dann deaktiviert, Verlauf und Zwischenablage bleiben nutzbar
- Interner Speicher für Snippets, Verlauf und Audit-Dateien wird lokal gehärtet; Zwischenablage-Fallback bleibt absichtlich optional und ist als weniger privater Zustellpfad gekennzeichnet

- Finalize- und Streaming-Modus mit **festem Textziel** pro Session; Snippets + Verlauf (Export TXT)
- Sprache, Qualität, **explizite Übersetzung** (getrennt von Auto-Sprache)
- AI-Nachbearbeitung (Apple / Remote), dynamische Provider & Modelle, Keys in Keychain
- Audio-Preprocessing, Sound-Feedback, **Sparkle**-Updates mit **permanent sichtbarem manuellen Check** im Menü und in den Settings
- Dock, Login-Item, Diagnose-Export, Audit-Log, optional Debug-Log
- Eingeschränkter Modus ohne Bedienungshilfen (Transkription/Verlauf weiter nutzbar)

## macOS: Release

Für die aktuelle Open-Source-Distribution ist kein Apple-Developer-Konto erforderlich. Auf einem Apple-Silicon-Mac erstellt das folgende Skript einen arm64-Release-DMG ohne Developer-ID-Zertifikat oder Notarisierung. macOS zeigt beim ersten Öffnen möglicherweise eine Sicherheitswarnung; Installationshinweise liegen neben dem DMG.

```bash
./scripts/build_macos_open_source_release.sh
```

Das Skript bereinigt alte lokale macOS-Build-Artefakte, baut Runtime und App neu und erzeugt einen DMG, eine SHA-256-Datei sowie kurze Installationshinweise unter `artifacts/mac/`. Den getesteten DMG kann man anschließend manuell als GitHub Release veröffentlichen. Details: [`docs/distribution.md`](docs/distribution.md) und [`docs/macos-release-checklist.md`](docs/macos-release-checklist.md).

Ein Developer-ID-signierter und notarisiert ausgelieferter Release bleibt als optionaler Distributionsweg dokumentiert; er ist für die aktuellen Open-Source-Releases nicht erforderlich.

Legacy-Export / Appcast:

```bash
DEVELOPMENT_TEAM=YOURTEAMID CODE_SIGN_IDENTITY="Developer ID Application" ./scripts/archive_macos_release.sh
DEVELOPMENT_TEAM=YOURTEAMID ./scripts/export_macos_release.sh
CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/create_macos_dmg.sh
SPARKLE_PRIVATE_KEY_FILE=/path/to/sparkle_private_key SPARKLE_BIN_DIR=/path/to/generate_appcast \
  ./scripts/generate_sparkle_appcast.sh
```

Bundle prüfen:

```bash
./scripts/verify_macos_release_bundle.sh artifacts/mac/release/Cortexa.app
```

## macOS: Smoke-Test

```bash
./scripts/smoke_test_macos_app.sh
```

Prüft u. a. Debug-Build, Bundle, `whisper-cli`, Modelle, kurzer Lauf; optional UI-Aktivierung. Varianten: `--keep-running`, `--skip-build`, `--no-ui`, `--skip-launch`.

Schneller Dev-Loop ohne Rebuild (TCC-Einträge bleiben stabil):

```bash
./scripts/smoke_test_macos_app.sh --skip-build --keep-running
```

## iOS / iPadOS

```bash
bash ./scripts/generate_ios_xcodeproj.sh
```

Projekt: `apps/ios/WisprLocaliOS/WisprLocaliOS.xcodeproj` — Targets **WisprLocaliOS** und **WisprLocalKeyboard**, App Group `group.com.wisprlocal.shared`. Details: [`apps/ios/README.md`](apps/ios/README.md).

---

**English summary:** Cortexa is an open-source, local-first dictation stack for Apple platforms, licensed under the [Apache License 2.0](LICENSE). Third-party components and models retain their own licenses; see [`docs/licensing.md`](docs/licensing.md), [`docs/third-party-notices.md`](docs/third-party-notices.md), [`docs/README.md`](docs/README.md), and [`docs/features-and-implementation.md`](docs/features-and-implementation.md) for details.
