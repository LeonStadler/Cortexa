# Cortexa System Design

Ausführliche Zuordnung von Produktfunktionen zu Modulen: [features-and-implementation.md](features-and-implementation.md). Dokumentationsindex: [README.md](README.md).

## Scope

Cortexa is an offline-first dictation/transcription product for Apple platforms.

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
- optional NVIDIA NeMo-Speech.cpp Parakeet TDT v3 backend; model descriptors declare runtime dependencies, and the pinned 0.1.0 Apple Silicon Metal runtime is SHA-256 verified and installed atomically in Cortexa Application Support when no compatible external runtime is found. External runtimes are read-only and never removed. GGUF model files stay in the separate NeMo model cache. A runtime dependency scan removes the Cortexa-owned runtime after the final dependent model is removed, synchronized with active NeMo subprocesses. Model capabilities drive language, live-mode, translation, and maximum-recording-duration compatibility; the engine fails explicitly at model duration limits instead of truncating the oldest captured audio. Parakeet uses automatic language detection and full-utterance offline transcription.
- model capability selection is shared by Settings, the menu bar, and session configuration. It resolves a valid installed language override before the global model, then checks the descriptor's language, automatic detection, translation, live-text, and quality flags. An unsupported user choice proposes the declared counterpart or a compatible installed/downloadable model. The requested model and option are applied only after confirmation and successful installation; a changed selection revision invalidates pending switches. Incompatible live-text, translation, and quality preferences remain stored while the session configuration uses safe effective values.

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

8. `AppShell`

- macOS menu bar app + settings
- iOS host app + keyboard extension shell
- current macOS shell includes runtime install bootstrap, permission deep-links,
  snippet persistence/import/export UI, personal dictionary persistence/import/export UI,
  language/performance selection, transcript history, and hotkey control
- full uninstall is initiated from Advanced settings and handed to a second app process; after the main app exits, it removes both legacy-named app storage/cache directories, catalogued Parakeet weights and partials, validated managed NeMo runtimes plus Cortexa-named interrupted install/upgrade transactions, prefixed download workspaces, preferences and Keychain credentials, resets Cortexa's Microphone and Accessibility consent, then moves the app bundle to Trash. External runtimes, unrecognized shared model-cache files and unrelated temporary files remain untouched.
- optional context-aware AI post-processing (`off`, `finalOnly`, `liveOnly`, `liveAndFinal`)
- optional media auto-pause/resume during dictation (best effort for Apple Music and Spotify)
- local audit log for session/diagnostic events with simple rotation and hardened file permissions / file protection
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
2. The effective speech model is selected once for the session before streaming starts.
3. Partial segments arrive continuously.
4. Stabilizer computes `committedPrefix` and `tail`.
5. Snippet replacement applies to the current streaming text.
6. A transcript sanitizer removes common non-speech placeholders such as `silence`, `music`, `cough`, or `applause`.
7. Optional live AI processing can reshape only the current mutable tail, never previously committed text.
8. Inserter patches only the mutable tail while preserving committed text already shown to the user.
9. Focus changes are ignored (target remains locked).
10. Stop finalizes the tail, runs a final AI pass when enabled, and closes the session.

Note: the current macOS implementation deliberately skips the separate final AI pass when live AI shaping is active for the same session, preferring one consistent rewrite path over a second post-pass.

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
