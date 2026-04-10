# macOS Permissions Guide

## Required permissions

1. Microphone
- Purpose: local audio capture for ASR.
- Framework: AVFoundation.

2. Accessibility (System Settings -> Privacy & Security -> Accessibility)
- Purpose: resolve focused target and insert text via AX API.
- Framework: ApplicationServices (AXUIElement).

## Optional permissions

1. Automation
- Not required for MVP.
- Avoid until a specific app automation feature is introduced.

2. Screen Recording
- Not required for text insertion.
- Only needed if future UX adds visual overlays that inspect other windows.

## Suggested user-facing copy

Microphone prompt:

> Benötigt für lokale Offline-Transkription auf diesem Mac.

Accessibility onboarding text:

> Benötigt, um Transkripte an der ursprünglichen Cursorposition einzufügen.

## UX flow

1. First launch shows permission checklist.
2. User can open relevant System Settings directly from app.
3. Capability checks re-run whenever app returns from settings.
4. App stays functional in limited mode when AX is missing (transcribe only).

## Rebuild / TCC recovery

Nach einem Rebuild kann die Bedienungshilfe in den Systemeinstellungen zwar aktiv aussehen, aber fuer den neu gestarteten Build noch nicht wirksam sein.

Empfohlener Recovery-Flow:

1. `WisprLocalMac` in `System Settings -> Privacy & Security -> Accessibility` einmal entfernen.
2. Die App neu starten.
3. Einen frischen Diktatversuch starten, damit der aktuelle Build den Accessibility-Dialog erneut anstoßen kann.
4. `WisprLocalMac` neu hinzufügen und wieder in den Bedienungshilfen aktivieren.

Wenn der Eintrag bereits aktiviert ist, aber das Einfügen weiterhin nicht greift, ist das ein typisches Zeichen fuer einen alten TCC-Eintrag aus einem frueheren Build.

### Smoke scenarios for manual checks

- Fresh build without microphone or Accessibility permission.
- Rebuild with an existing Accessibility entry that looks enabled but is not effective yet.
- Accessibility toggled off and on without removing the entry.
- Accessibility removed and re-added for the current build.

Diese Szenarien gehoeren in den Smoke-Test vor einem Release.

### Praktische Schritte in der aktuellen App

Optional vor dem UI-Test:

```bash
./scripts/smoke_test_macos_app.sh --keep-running
```

Das baut die Debug-App, prüft das Bundle und startet `WisprLocalMac` direkt aus dem gebauten `.app`-Bundle.

1. App starten (`WisprLocalMac` Target).
2. Menüleisten-Icon öffnen -> `Open Settings`.
3. In `Permissions`:
- `Mikrofon öffnen` klicken und Zugriff erlauben.
- `Bedienungshilfen öffnen` klicken und `WisprLocalMac` aktivieren.
4. Zurück in die App, dann `Start Dictation` oder `Option + Space`.
5. `Current Status` muss auf `Recording` wechseln.
6. Nach Sleep/Wake oder Rückkehr in den Vordergrund aktualisiert die App Berechtigungen und registriert den Hotkey erneut automatisch.

## Failure behaviors

- Missing microphone permission:
  - block recording start
  - show actionable error + open settings button

- Missing AX permission:
  - allow transcription
  - disable finalize/stream insert actions
  - allow clipboard-only manual copy flow
  - if the app appears authorized but still cannot insert after a rebuild, instruct the user to remove and re-add the entry in Accessibility
