# iOS / iPadOS Plan (Keyboard Extension)

## Product reality

iOS/iPadOS do not allow macOS-style Accessibility injection across arbitrary apps.
Insertion must happen through system-supported surfaces.

## Primary path: Keyboard Extension

1. Provide dictation button in custom keyboard.
2. Capture audio and run local ASR via shared core.
3. Insert committed text using `textDocumentProxy`.
4. Apply snippet replacements before insertion.

## Secondary path: Host app Share/Clipboard flow

1. Record in host app.
2. Transcribe locally.
3. Copy or share transcript.

## Shared modules

- `ASRCore`
- `AudioCore` (adapted session behavior)
- `SessionCore`
- `SnippetCore`
- `CapabilityCore`

## App Group strategy

Use app group container for shared settings and snippets:

- snippet JSON store
- transcript history JSON store
- local audit log
- selected model ID
- user profile flags

Current implementation status:

- host app reads/writes shared snippets
- host app reads/writes shared transcript history
- keyboard extension reads shared snippets and latest transcript
- host app and extension are configured for `group.com.wisprlocal.shared`

## Limitations to document

- No unrestricted cross-app target lock like macOS AX snapshot.
- Keyboard lifecycle and memory limits are stricter.
- Background execution is constrained.
- keyboard extension currently exposes shared-data insertion helpers, not full on-device whisper runtime parity yet

## Release path

Initial distribution: Developer provisioning sideload for app + extension.
