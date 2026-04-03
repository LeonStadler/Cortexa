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
- local speech-model catalog with explicit provider/model descriptors, install state, and per-language selection

2. `AudioCore`
- AVAudioEngine capture
- 16k mono normalized chunk output
- interruption and route change signals
- optional app-level preprocessing for input level compensation, silence removal, dynamic normalization, and adjustable noise suppression

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

7. `AIProcessingCore`
- provider-agnostic text post-processing abstractions
- Apple on-device Foundation Models integration for supported Macs
- model catalog and quick-settings eligibility filtering
- final-only or live-tail-plus-final processing modes

8. `LicenseCore`
- offline key format + verification
- keychain storage for raw keys without plaintext disk fallback

9. `AppShell`
- macOS menu bar app + settings
- iOS host app + keyboard extension shell
- current macOS shell includes runtime install bootstrap, permission deep-links,
  snippet persistence/import/export UI, explicit speech-provider/model selection, language/performance selection, translation selection,
  transcript history, AI processing model/goal/format controls, license activation UI, hotkey control,
  dedicated app-behavior, sound, text-input, history-retention, and model-visibility settings
- sound feedback controls are app-local cues for start/stop/failure states and do not control the system microphone volume or any global playback-pausing behavior
- local audit log for session/diagnostic/license events with simple rotation and hardened file permissions / file protection
- optional debug log for high-detail runtime/process tracing, including `whisper-cli` launch, exit, and timeout events
- persistent user settings (mode/language/performance/translation/AI processing) via `UserDefaults`
 - iOS shell now includes a host app backed by app-group storage and a keyboard extension
   that can insert the latest shared transcript and shared snippet replacements

## Data Flows

### 1) Finalize Insert (macOS)

1. Hotkey starts session.
2. AX target snapshot captured once (`bindingID` immutable).
3. Audio captured and sent to ASR.
   Optional preprocessing may adjust input level, suppress silence, attenuate weak background noise, or normalize dynamic gain before samples reach ASR.
4. The selected local speech model is resolved from the visible catalog, with optional language-specific overrides and fallback to bundled `Standard`.
5. Final transcript returned in the spoken language unless explicit translation is enabled and the selected model supports Whisper translation to English.
6. Snippet replacement applied.
7. Optional translation applied.
8. Optional AI processing applied.
9. Single deterministic insert into original target.
10. Session transitions to completed.

### 2) Streaming Insert (macOS)

1. Start session and capture immutable target.
2. The effective speech model is selected once for the session before streaming starts.
3. Partial segments arrive continuously.
4. Stabilizer computes `committedPrefix` and `tail`.
5. Snippet replacement applies to the current streaming text.
6. A transcript sanitizer removes common non-speech placeholders such as `silence`, `music`, `cough`, or `applause`.
7. Optional live AI processing can reshape only the current mutable tail, never previously committed text.
8. Inserter patches only the mutable tail while preserving committed text already shown to the user.
9. Focus changes are ignored (target remains locked).
10. Stop finalizes the tail, runs a final AI pass when enabled, and closes the session.

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
- Auto language detection controls recognition only and never implies translation.
- Translation is explicit and currently limited to Whisper's English translation path.
- Auto language detection controls recognition only and never implies translation.
- Speech-model selection is explicit and independent from the runtime quality preset.
- Quality presets tune chunking/beam/thread behavior but no longer silently switch between bundled Whisper models.
- Language-specific model variants may only be used when the input language matches or when the session runs in `Auto`.
- AI processing is optional post-processing and must fail closed to the raw transcript path.

## Permission / Security Matrix

- Microphone: required on all platforms for capture.
- Accessibility (macOS): required for AX insertion.
- Automation: not required by default.
- Network: not required by default for product function.
- Network: optional when the user explicitly enables remote AI providers such as OpenRouter or a custom OpenAI-compatible endpoint.

## Reliability Strategy

- explicit state machine transitions
- interruption handling (`audioInterrupted`, `permissionChanged`)
- deterministic insertion semantics
- explicit `Transcription -> optional Translation -> optional AI Processing` staging
- optional fallback path isolated behind config
- bundled `Standard` keeps first-run dictation available without extra downloads, while larger local Whisper variants are installed on demand
- the runtime installer preserves already downloaded local speech models when it syncs bundled runtime assets into app support
- provider-agnostic AI processing layer supports Apple on-device and dynamic remote API catalogs without baking remote model IDs into the app
- remote provider presets share one OpenAI-compatible transport layer, so brokers like OpenRouter and direct providers such as OpenAI, Groq, Mistral, DeepSeek or local runtimes like Ollama/LM Studio can be added without a separate model registry per vendor
- the menu bar shell persists semantically named settings groups for app lifecycle, audio preprocessing, sound feedback, text delivery, transcript retention, and explicit local speech-model selection, and some of them are applied immediately through the app state
- the voice-model active duration gives the runtime a warm/unload boundary, so loaded model state can be released after inactivity and rebuilt on demand without changing provider behavior
- AI provider errors degrade to untranslated/unprocessed text instead of blocking dictation
- clipboard-based fallback remains explicit because it is less private than direct insertion

## Performance Strategy

- capability profiling at startup
- profile-driven presets (`fast/balanced/accurate/auto`)
- thermal fallback for sustained usage
