# macOS Release Checklist

## Ziel

Diese Checkliste ist der letzte Nachweis, dass `WisprLocalMac` als reale macOS-Menüleisten-App stabil funktioniert und als signierter/notarisierter Download ausgeliefert werden kann.

## 1. Produktionsvariablen setzen

```bash
export WISPR_LICENSE_PUBLIC_KEY_BASE64='DEIN_ED25519_PUBLIC_KEY_BASE64'
export SPARKLE_FEED_URL='https://deine-domain.tld/appcast.xml'
export SPARKLE_PUBLIC_ED_KEY='DEIN_SPARKLE_PUBLIC_ED_KEY'
```

## 2. Release-Preflight

```bash
./scripts/preflight_macos_release.sh
```

Erwartung:
- `whisper-cli` ist im Runtime-Bundle vorhanden
- mindestens ein ggml-Modell ist vorhanden
- `WisprLocalMac.xcodeproj` wurde neu generiert
- `MARKETING_VERSION` entspricht `VERSION`

## 3. Debug-Smoke-Test

```bash
./scripts/smoke_test_macos_app.sh --keep-running
```

Erwartung:
- `WisprLocalMac.app` wurde gebaut
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
- wenn Bedienungshilfen sichtbar aktiv sind, aber das Einfügen nach einem Rebuild noch nicht klappt, die Accessibility-Entry einmal entfernen und neu hinzufügen

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
- Rebuild mit altem Accessibility-Eintrag -> Recovery-Hinweis führt zum Entfernen und erneuten Aktivieren
- Sleep/Wake -> Hotkey funktioniert weiter
- App-Neustart -> Runtime wird neu vorbereitet, Status bleibt konsistent

## 7. Release-Erstellung

```bash
./scripts/archive_macos_release.sh
DEVELOPMENT_TEAM=DEINTEAM ./scripts/export_macos_release.sh
CODE_SIGN_IDENTITY="Developer ID Application: Dein Name (TEAMID)" ./scripts/create_macos_dmg.sh
```

## 8. Notarisierung und Validierung

Beispiel:

```bash
xcrun notarytool submit artifacts/mac/WisprLocalMac.dmg --keychain-profile DEIN_PROFIL --wait
xcrun stapler staple artifacts/mac/WisprLocalMac.dmg
./scripts/verify_macos_release_bundle.sh artifacts/mac/WisprLocalMac.dmg
```

Erwartung:
- `spctl` erfolgreich
- `stapler validate` erfolgreich

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
