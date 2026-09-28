# macOS Release Checklist

## Ziel

Diese Checkliste prüft einen lokal gebauten Open-Source-DMG vor einem manuellen GitHub-Release. Der aktuelle Release benötigt kein Apple-Developer-Programm, Developer-ID-Zertifikat oder Notarisierung. Target, Scheme und Bundle-ID bleiben technisch `WisprLocalMac` bzw. `com.wisprlocal.mac`.

## 1. Voraussetzungen

Xcode, XcodeGen, CMake, Python 3 und Git müssen auf dem Apple-Silicon-Mac verfügbar sein. Das Whisper-Submodul wird bei Bedarf vom Build-Skript initialisiert. Für den arm64-Open-Source-DMG werden keine Release-Secrets benötigt.

## 2. Open-Source-Build

```bash
./scripts/build_macos_open_source_release.sh
```

Das Skript baut Runtime und Release-App ohne Apple-Anmeldedaten und schreibt DMG, SHA-256 sowie Installationshinweise nach `artifacts/mac/`.

## 2b. First-Run-Onboarding (manuell)

1. Frische Installation (oder Onboarding-Key löschen: `wispr.onboarding.completedVersion`) → Onboarding-Fenster erscheint, kein Modell vor Download.
2. Standard-Download: Größe in Details ≈ Progress-Total (~141 MB).
3. Pro-Download (optional in Settings): Progress steigt ohne Sprung von 0→50 %.
4. Bestehende Installation mit `ggml-base.bin` in Application Support → kein Onboarding.
5. Pro entfernen → bleibt nach Neustart weg.

## 3. Debug-Smoke-Test

```bash
./scripts/smoke_test_macos_app.sh --keep-running
```

Erwartung:
- `Cortexa.app` wurde gebaut
- Das Release-Bundle startet und transkribiert mit dem enthaltenen CLI und Modell; die Open-Source-DMG-Signatur dient der Integritätsprüfung und ist keine Apple-Entwickleridentität
- die im App-Bundle enthaltene CLI transkribiert synthetisierte Sprache mit dem gebündelten Standardmodell zu einem nicht-leeren Text
- Dock-Icon wird aus `Cortexa.icon` kompiliert und zeigt die Liquid-Glass-/Appearance-Varianten korrekt
- App startet aus dem gebauten Bundle
- kein dauerhaftes Dock-Icon
- Menüleisten-Icon erscheint
- die App wird einmal aktiviert und versucht, den Settings-Shortcut auszulösen
- zwei aufeinanderfolgende Builds behalten nach Moeglichkeit eine stabile Signing-/Requirement-Identitaet
- zwei Debug-Builds lassen sich mit `codesign -dvvv` vergleichen, ohne dass sich die relevante Requirement ungewollt aendert

## 4. Berechtigungen

In der laufenden App:
- `Open Settings`
- Mikrofon erlauben
- Bedienungshilfen erlauben

Erwartung:
- Permission-Hinweise verschwinden ohne Neustart
- `Option + Space` bleibt nach Rückkehr aus den Systemeinstellungen funktionsfähig
- `Freigabe anfragen` löst den macOS-Hinweis nur nach diesem expliziten Klick aus; ein Diktatstart fragt nicht erneut
- der normale Ablauf benötigt kein Entfernen und Neu-Hinzufügen des Accessibility-Eintrags

## 5. Funktionstests in realen Ziel-Apps

Testziele:
- `TextEdit`
- `Notes`
- `VS Code`

Pro App testen:
- `Finalize Insert`
- `Streaming Insert`
- Fokuswechsel während Streaming
- Snippet-Ersetzung
- History-Eintrag nach finalem Diktat

Erwartung:
- Einfügung passiert nur in das ursprüngliche Ziel
- kein falsches Paste in fremde App
- History enthält nur finale Transkripte

## 6. Fehlerfälle

Prüfen:
- Mikrofonrecht entziehen -> Aufnahme blockiert mit klarer UI
- AX-Recht entziehen -> Insert blockiert mit klarer UI
- bei einem Update kann macOS die erneute Freigabe geschützter Ressourcen verlangen, da der Open-Source-Release keine persistente Team-Signatur besitzt
- Accessibility-Freigabe anfragen -> der macOS-Hinweis erscheint; Cortexa öffnet Systemeinstellungen nicht zusätzlich automatisch
- Sleep/Wake -> Hotkey funktioniert weiter
- App-Neustart -> Runtime wird neu vorbereitet, Status bleibt konsistent
- CLI absichtlich durch ein nicht startbares Artefakt ersetzen -> kein „ASR CLI runtime ready“, sondern ein konkreter Initialisierungsfehler

## 7. Open-Source-Release bauen

```bash
./scripts/build_macos_open_source_release.sh
```

Das Skript räumt alte Dateien unter `artifacts/mac/` in diesem Checkout auf und erstellt DMG, SHA-256-Prüfsumme sowie Installationshinweise. Vor dem GitHub-Upload:

```bash
hdiutil verify artifacts/mac/Cortexa-*.dmg
(cd artifacts/mac && shasum -a 256 -c Cortexa-*.dmg.sha256)
```

Die App trägt eine ad-hoc-Signatur zur Integritätsprüfung. `TeamIdentifier` ist absichtlich nicht gesetzt; Gatekeeper-Warnung beim Erststart ist damit zu erwarten. Ein optionaler künftiger Weg kann mit `Developer ID Application` signieren. GitHub Releases erhalten erst nach manueller Installation und Produktabnahme durch den Nutzer den getesteten DMG.

## 8. Erststart auf einem anderen Mac

1. `Cortexa.app` aus dem eingebundenen DMG nach `Programme` ziehen.
2. Cortexa per Rechtsklick → **Öffnen** starten und die macOS-Rückfrage bestätigen.
3. Falls macOS den Start weiter blockiert: den Startversuch wiederholen und anschließend **Systemeinstellungen → Datenschutz & Sicherheit → Dennoch öffnen** wählen.
4. Mikrofon- und Bedienungshilfenberechtigung erteilen und ein Diktat testen.

macOS-Versionen können den Wortlaut und Ort der Freigabe leicht ändern. Weisen Release-Hinweise darauf hin, dass Cortexa nicht von einem verifizierten Apple-Entwickler signiert ist. Bei künftigen DMG-Updates kann macOS wegen der wechselnden ad-hoc Signatur erneut um Mikrofon- oder Bedienungshilfenfreigabe bitten.

## 9. Optionaler Developer-ID-Weg

Die bisherigen Skripte `archive_macos_release.sh`, `export_macos_release.sh` und `verify_macos_release_bundle.sh` bleiben für einen späteren signierten/notarisierten Distributionsweg erhalten. Dort werden `codesign -dvvv`, `TeamIdentifier` und die designated requirement geprüft. Sie gehören nicht zum aktuellen Release-Ablauf.

## 9. Updater

Wenn die Appcast-Distribution aktiv ist:

```bash
SPARKLE_PRIVATE_KEY_FILE=/pfad/zum/sparkle_private_key \
SPARKLE_BIN_DIR=/pfad/zu/sparkle/bin \
./scripts/generate_sparkle_appcast.sh
```

In der App testen:
- `Check for Updates`

Erwartung:
- Update-Check startet ohne Crash
- Feed wird nur verwendet, wenn `SUFeedURL` und `SUPublicEDKey` gesetzt sind
