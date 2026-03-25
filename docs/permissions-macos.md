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
