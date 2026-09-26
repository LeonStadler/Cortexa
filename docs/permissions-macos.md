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
2. Der Nutzer klickt explizit auf `Freigabe anfragen`; nur diese Aktion ruft `AXIsProcessTrustedWithOptions` mit Apples Prompt-Option auf. Der macOS-Hinweis bietet den Weg zu den Systemeinstellungen an. Cortexa öffnet kein zweites Fenster automatisch.
3. Capability checks re-run whenever app returns from settings.
4. App stays functional in limited mode when AX is missing (transcribe only).
5. Starting a dictation only checks the existing AX state. It never repeatedly displays a system permission prompt.

## Updates and TCC identity

macOS binds Privacy & Security grants to the signed app identity, not just to the displayed name. Every Cortexa update must retain `com.wisprlocal.mac` and use the same Apple signing team. Distributable updates must use the same `Developer ID Application` identity and be notarized; a local development build can use `Apple Development` on the developer's own Mac.

The release archive and DMG scripts reject missing or ad-hoc signing identities. Never create an installable DMG from a Debug app signed with `Sign to Run Locally`; its ad-hoc signature has no stable team identity, so replacement can cause macOS to ask for protected-resource permissions again.

The normal Accessibility flow is one deliberate app action:

1. Click `Freigabe anfragen` in Cortexa.
2. Use the macOS hint to open `System Settings -> Privacy & Security -> Accessibility`, then enable Cortexa.
3. Return to Cortexa. It refreshes the permission state and enables direct insertion without a restart.

Das Entfernen und erneute Hinzufügen eines Eintrags ist **nicht der normale Ablauf**. Es ist nur der letzte Diagnoseschritt, wenn die Systemeinstellungen doppelte oder beschädigte Einträge zeigen und `AXIsProcessTrusted()` nach Aus- und Einschalten des aktuellen Cortexa-Eintrags sowie einem App-Neustart weiter `false` liefert. Vorher Cortexa-Diagnosen sichern.

### Smoke scenarios for manual checks

- Fresh build without microphone or Accessibility permission.
- Two consecutive archives signed with the same Apple identity: compare `Identifier`, `TeamIdentifier`, and designated requirements.
- Accessibility toggled off and on without removing the entry.
- A user declines the prompt, then uses `Freigabe anfragen` explicitly; starting a dictation does not prompt again.

Diese Szenarien gehoeren in den Smoke-Test vor einem Release.

### Praktische Schritte in der aktuellen App

Optional vor dem UI-Test:

```bash
./scripts/smoke_test_macos_app.sh --keep-running
```

Das baut die Debug-App, prüft das Bundle und startet Cortexa direkt aus dem gebauten `.app`-Bundle.

1. App starten (`WisprLocalMac` Target).
2. Menüleisten-Icon öffnen -> `Open Settings`.
3. In `Permissions`:
- `Mikrofon öffnen` klicken und Zugriff erlauben.
- `Freigabe anfragen` bei Bedienungshilfen klicken und `Cortexa` aktivieren.
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
  - offer the explicit `Freigabe anfragen` action and refresh after System Settings closes
  - only use remove/re-add as an investigated last-resort recovery for a duplicate/corrupt System Settings entry
