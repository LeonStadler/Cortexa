# WisprLocal System Design

## Scope

WisprLocal is an offline-first dictation/transcription product for Apple platforms.

- Primary platform: macOS (Apple Silicon optimized)
- Secondary platforms: iOS + iPadOS (keyboard-extension based insertion)
- ASR backend: `whisper.cpp` (primary), Core ML/ANE optional strategy

## High-level Components

1. `ASRCore`
- Whisper engine protocol
- runtime backend strategy
- model registry/checksum verification
- bundled runtime installer (app resources -> local app-support runtime)

2. `AudioCore`
- AVAudioEngine capture
- 16k mono normalized chunk output
- interruption and route change signals

3. `SessionCore`
- transcription state machine
- streaming commit stabilizer
- deterministic insert invariant enforcement

4. `TextTargetMac`
- focused AX target snapshot
- immutable target binding for session
- AX value patching and optional paste fallback

5. `SnippetCore`
- phrase/word replacement rules
- longest-match wins
- final transcript replacement + streaming replacement ops

6. `CapabilityCore`
- device profile collection
- adaptive presets (streaming/quality/fallback)

7. `LicenseCore`
- offline key format + verification
- keychain storage for raw keys without plaintext disk fallback

8. `AppShell`
- macOS menu bar app + settings
- iOS host app + keyboard extension shell
- current macOS shell includes runtime install bootstrap, permission deep-links,
  snippet persistence/import/export UI, personal dictionary persistence/import/export UI,
  language/performance selection, transcript history, license activation UI, and hotkey control
- optional context-aware AI post-processing (`off`, `finalOnly`, `liveOnly`, `liveAndFinal`)
- optional media auto-pause/resume during dictation (best effort for Apple Music and Spotify)
- local audit log for session/diagnostic/license events with simple rotation and hardened file permissions / file protection
- persistent user settings (mode/language/performance/context/media-mute) via `UserDefaults`
 - iOS shell now includes a host app backed by app-group storage and a keyboard extension
   that can insert the latest shared transcript and shared snippet replacements

## Data Flows

### 1) Finalize Insert (macOS)

1. Hotkey starts session.
2. AX target snapshot captured once (`bindingID` immutable).
3. Audio captured and sent to ASR.
4. Optional ASR dictionary prompt hints are applied before decode.
5. Final transcript returned.
6. Optional AI receives bounded app-context and dictionary term preservation hints.
7. Snippet replacement applied.
8. Single deterministic insert into original target.
9. Session transitions to completed.

### 2) Streaming Insert (macOS)

1. Start session and capture immutable target.
2. Partial segments arrive continuously.
3. Stabilizer computes `committedPrefix` and `tail`.
4. Inserter patches only the mutable tail while preserving committed text already shown to the user.
5. Focus changes are ignored (target remains locked).
6. Stop finalizes tail and closes session.

### 3) iOS/iPadOS Keyboard Flow

1. Keyboard extension triggers dictation.
2. Shared ASR core transcribes locally.
3. `textDocumentProxy` receives incremental patches.
4. Snippets apply on committed tokens.

## Session State Machine

States:

- `idle`
- `armingTarget`
- `recording`
- `transcribingStreaming`
- `finalizing`
- `inserting`
- `completed`
- `error(recoverable|fatal)`

Core invariants:

- `TargetBindingID` is immutable per session.
- `committedText` is append-only.
- Only `uncommittedTail` may be replaced.
- Insert operation IDs are idempotent.
- The live rewrite scope determines how much recent text may still be reshaped before it is considered committed.

## Permission / Security Matrix

- Microphone: required on all platforms for capture.
- Accessibility (macOS): required for AX insertion.
- Automation: not required by default.
- Network: not required by default for product function.

## Reliability Strategy

- explicit state machine transitions
- interruption handling (`audioInterrupted`, `permissionChanged`)
- deterministic insertion semantics
- optional fallback path isolated behind config
- clipboard-based fallback remains explicit because it is less private than direct insertion

## Performance Strategy

- capability profiling at startup
- profile-driven presets (`fast/balanced/accurate/auto`)
- thermal fallback for sustained usage
