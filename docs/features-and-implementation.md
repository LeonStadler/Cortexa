# Funktionen und technische Umsetzung

Stand: 2026-04-04. Diese Seite ordnet **sichtbare Produktfunktionen** den **Swift-Modulen** und der **macOS-/iOS-AppShell** zu. Für Ablaufdiagramme und Invarianten siehe [system-design.md](system-design.md); für Typ- und Protokollsignaturen [api-design.md](api-design.md).

## Plattform-Matrix

| Bereich                  | macOS                                                     | iOS / iPadOS                                                                                                                     |
| ------------------------ | --------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| Lokale ASR (whisper.cpp) | Vollständig über gebündelten Runtime-Installer + Katalog  | Host/Extension-Blueprint; Parität mit macOS-Laufzeitpfad laut [apps/ios/README.md](../apps/ios/README.md) noch nicht vollständig |
| Text einfügen            | Accessibility (`TextTargetMac`) + optional Paste-Fallback | Nur im Extension-Kontext über `textDocumentProxy`                                                                                |
| Globales Diktat-Hotkey   | Ja (`GlobalHotkeyManager`, konfigurierbar)                | Nicht anwendbar                                                                                                                  |
| Snippets                 | `SnippetCore` + UI, Import/Export JSON                    | Geteilt über App Group                                                                                                           |
| Verlauf                  | Lokal in App Support, Export TXT                          | Nur Host-App, nicht vollständig in der Group exponiert                                                                           |
| AI-Nachbearbeitung       | `AIProcessingCore` + Keychain für API-Keys                | Abhängig von Host-App-Stand                                                                                                      |
| Offline-Lizenz           | `LicenseCore` + UI (interner UI-Schalter über Bundle-Key) | Host-App                                                                                                                         |
| Auto-Update              | Sparkle (wenn Feed + Public Key gesetzt)                  | Wie iOS-Verteilungskanal                                                                                                         |

## Swift-Pakete (`Package.swift`)

| Modul                | Rolle                                                                | Wesentliche Umsetzung                                                                  |
| -------------------- | -------------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| **ASRCore**          | Whisper-Engine, CLI-Ausführung, Modell-Registry, gebündelter Runtime | `WhisperCppEngine`, `BundledWhisperRuntime`, Katalog für Provider/Modelle, Checksummen |
| **AudioCore**        | Aufnahme 16 kHz mono, Unterbrechungen                                | `AVAudioEngine`, optional Preprocessing (siehe unten)                                  |
| **SessionCore**      | Zustandsmaschine, Streaming-Stabilisator, Commit-Regeln              | Koordiniert mit Snippets und Insert-Pfad                                               |
| **SnippetCore**      | Regeln, Matcher, Persistenz, sichere Dateirechte                     | Longest-match, Streaming + Final                                                       |
| **TextTargetMac**    | AX-Snapshot, Binding, Insert/Patch                                   | Nur macOS-Target                                                                       |
| **CapabilityCore**   | Geräteprofil, Presets fast/balanced/accurate/auto                    | Thermik/CPU/RAM → Laufzeitparameter                                                    |
| **AIProcessingCore** | Apple On-Device + Remote OpenAI-kompatibel                           | Provider-Presets, `/models`, Prompt-Baukasten, Konfiguration                           |
| **LicenseCore**      | WISPR1-Schlüssel, Ed25519, Keychain                                  | Kein Klartext-Fallback für Rohschlüssel                                                |

Tests: jeweils unter `Tests/<Module>Tests`.

## macOS AppShell — Funktionsgruppen

Pfad: `apps/macos/AppShell/`. Zentrale Orchestrierung u. a. in `MacAppState.swift`, `DictationRuntime.swift`, `WisprLocalMacApp.swift`.

### Diktat & Sprache

- Modi **Finalize** vs. **Streaming**; immutable Textziel-Binding pro Session.
- Sprachen inkl. **Auto** (nur Erkennung, keine implizite Übersetzung).
- **Übersetzung** explizit: Original vs. Whisper-Übersetzung nach Englisch (abhängig vom gewählten Sprachmodell).
- **Live-Rewrite-Scope**: wie weit der Streaming-Tail noch umformuliert werden darf.
- **Qualitäts-Preset** (auto/fast/balanced/accurate): Chunking, Threads, Beam, Commit-Verhalten — getrennt von der expliziten **Sprachmodellwahl** (Katalog + ggf. sprachspezifische Overrides).
- **Finaler Output**: Insert ins Fokusfeld vs. nur Zwischenablage; **Clipboard-Fallback** wenn kein Ziel, optional und als datenschutzrelevanter Pfad dokumentiert.
- **Auto-Send** / **Clipboard-Restore** / simulierte Tastatur-Eingabe: getrennt konfigurierbar (Texteingabe-Semantik).

### Audio

- App-internes **Preprocessing**: Eingangsverstärkung, Stille entfernen, dynamische Normalisierung, **Rauschunterdrückungs-Level** (vor ASR).
- **Soundeffekte** Start/Stop/Fehler mit Lautstärke (keine globale System-Mikrofonlautstärke).

### Snippets & Verlauf

- Snippet-Editor, Import/Export **JSON**; Engine in `SnippetCore`.
- **Transkript-Verlauf**: Kopieren, Löschen, leeren, Export **TXT**; Aufbewahrungs-Policy in den Settings.

### AI-Nachbearbeitung

- Modellauswahl über Katalog: **Apple On-Device** (wenn verfügbar) + dynamische Remote-Provider (OpenRouter, OpenAI, Groq, Mistral, DeepSeek, Together, Fireworks, xAI, Ollama, LM Studio, **Custom** OpenAI-kompatibel).
- Getrennte Schalter: während **Live-Insertion** vs. **finales Ergebnis**.
- Ziele: Bereinigung, Ton, Anrede, **Format** (E-Mail, Chat, Doku, …); Stil-Optionen abhängig vom Format.
- API-Keys in **Keychain**; Modelle über Provider-**`/models`**; Auswahl-ID `providerID::modelID`.
- Fehler: **Fail-closed** auf Rohtranskript, Diktat läuft weiter.

### Shortcuts & Menüleiste

- Globaler **Toggle**-Shortcut (Standard Option+Space), **Hold-to-Dictate** optional separat.
- Validierung gegen System-Konflikte (Spotlight, App-Wechsel, …).
- **MenuBarExtra**: Status, Diktat start/stop, Quick-Settings, kompaktes Layout optional, Berechtigungen, Settings, Update, Beenden.
- **Kurzbefehl-Hinweise** in der Menüleiste optional abschaltbar.

### App-Lebenszyklus & System

- **LSUIElement** (Agent); optional **Dock-Sichtbarkeit**.
- **Start bei Login**.
- **Update-Prüfung** (Sparkle): Hintergrund + **permanent sichtbarem manuellen Check** im Menü und in den Settings (wenn konfiguriert).
- Reaktivierung nach App-Fokus und **Wake from Sleep**: Berechtigungen, Runtime, Hotkey.
- **Sprachmodell-Warmhaltezeit**: Entladen nach Inaktivität.

### Berechtigungen & eingeschränkter Betrieb

- Mikrofon + Bedienungshilfen für direktes Einfügen; ohne AX: **Transkription** möglich, direktes Einfügen deaktiviert (Verlauf/Zwischenablage je nach Einstellung).
- Deep Links in **Systemeinstellungen**.

### Lizenz, Diagnose, Sicherheit

- Lizenz-UI nur wenn `WLMEnableInternalLicenseUI` gesetzt; Produktions-Key `WLMLicensePublicKeyBase64`.
- Aktivierung: **Keychain-only secret persistence with legacy cache cleanup** bei alten Builds.
- **Audit-Log** mit Rotation unter Application Support; optional **debug.log** (Runtime, `whisper-cli` Lifecycle).
- Export **wispr-diagnostics.txt**; gehärtete Dateirechte für sensible lokale Dateien.
- Transcript-Sanitizer für typische Nicht-Sprach-Platzhalter vor Anzeige/Einfügen.

### Lokalisierung

- UI-Sprache **Deutsch / Englisch** in den Settings umschaltbar.

## iOS / iPadOS

Siehe [../apps/ios/README.md](../apps/ios/README.md) und [ios-keyboard-plan.md](ios-keyboard-plan.md). App Group `group.com.wisprlocal.shared` ist **Pflicht** — kein stiller Fallback.

## Release & Konfiguration (Kurz)

- Version: Datei `VERSION` im Repo-Root; XcodeGen übernimmt Marketing/Build-Version.
- Release-Umgebung: `WISPR_LICENSE_PUBLIC_KEY_BASE64`, `SPARKLE_FEED_URL`, `SPARKLE_PUBLIC_ED_KEY` (siehe [distribution.md](distribution.md), Root-README).

## Abhängigkeiten Dritter (Laufzeit)

- **whisper.cpp** (lokal gebaut, als CLI/XCFramework ins Bundle) — Lizenz siehe Upstream-Projekt im Submodule/Build-Pfad.
- **Sparkle** (macOS-Updater) — eingebettet im App-Bundle.

Proprietärer Gesamtstatus: [licensing.md](licensing.md#proprietary).
