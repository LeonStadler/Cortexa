# Security Best Practices Report

Date: 2026-04-01
Project: `wisper-local`
Scope: Swift macOS/iOS app review, with focus on the macOS dictation app and shared storage/runtime components

## Executive Summary

The reviewed codebase does not currently show an obvious remote-code-execution or server-side class of vulnerability. The highest-risk issues are local confidentiality weaknesses: the app stores license material in plaintext outside the Keychain, persists transcript history and audit data without explicit hardening, and relies on default filesystem permissions for sensitive local artifacts.

For a dictation app, these are meaningful security concerns because the stored data can include spoken content, operational history, and licensing secrets. The most important next step is to reduce plaintext persistence of secrets and harden storage for all sensitive local files.

## Findings

### High

#### SBP-001: License key is duplicated in plaintext outside the Keychain
Impact: Any process running as the same user can recover the full license key from the JSON cache, even though a Keychain-backed store already exists.

- Evidence:
  - [apps/macos/AppShell/LicenseController.swift](/Users/leonstadler/Development/wisper-local/apps/macos/AppShell/LicenseController.swift#L60) writes the validated license to both `LicenseStore` and `LicenseCache`.
  - [Sources/LicenseCore/LicenseStore.swift](/Users/leonstadler/Development/wisper-local/Sources/LicenseCore/LicenseStore.swift#L13) already persists the license in the Keychain.
  - [Sources/LicenseCore/LicenseCache.swift](/Users/leonstadler/Development/wisper-local/Sources/LicenseCore/LicenseCache.swift#L25) writes the full `licenseKey` into `license-cache.json`.
  - [apps/macos/AppShell/MacAppState.swift](/Users/leonstadler/Development/wisper-local/apps/macos/AppShell/MacAppState.swift#L1124) places that cache under the app's Application Support directory.
- Why this matters:
  - The cache does not add confidentiality; it weakens it by duplicating the secret outside the Keychain.
  - The `integrityTag` is not keyed cryptography, so it detects accidental changes but does not protect secrecy.
- Recommendation:
  - Stop caching the raw license key on disk.
  - If a fallback is required, cache only non-secret derived state such as tier, expiry, and last validation timestamp.
  - If the plaintext key must exist temporarily, protect it with stronger platform storage guarantees and a documented threat model.

### Medium

#### SBP-002: Transcript history is stored in plaintext without explicit file-permission hardening

- Evidence:
  - [apps/macos/AppShell/TranscriptHistoryStore.swift](/Users/leonstadler/Development/wisper-local/apps/macos/AppShell/TranscriptHistoryStore.swift#L32) writes all transcript entries as JSON.
  - [apps/macos/AppShell/MacAppState.swift](/Users/leonstadler/Development/wisper-local/apps/macos/AppShell/MacAppState.swift#L1116) stores the history file in Application Support as `transcript-history.json`.
- Why this matters:
  - Dictation history can contain passwords, personal messages, internal company text, or other sensitive dictated content.
  - The code relies on default directory/file permissions and does not encrypt or redact stored entries.
- Recommendation:
  - Define a retention policy and allow users to disable history by default or opt into it explicitly.
  - Apply explicit restrictive POSIX permissions to the directory and files used for transcript persistence.
  - Consider encrypting history at rest if persistence is a product requirement.

#### SBP-003: Audit and diagnostic persistence can expose operational metadata without storage hardening

- Evidence:
  - [apps/macos/AppShell/AuditLogger.swift](/Users/leonstadler/Development/wisper-local/apps/macos/AppShell/AuditLogger.swift#L19) appends audit lines to a local log file.
  - [apps/macos/AppShell/MacAppState.swift](/Users/leonstadler/Development/wisper-local/apps/macos/AppShell/MacAppState.swift#L972) mirrors many diagnostic events and writes them into the audit log via `appendAudit("diag ...")`.
  - [apps/macos/AppShell/MacAppState.swift](/Users/leonstadler/Development/wisper-local/apps/macos/AppShell/MacAppState.swift#L1120) stores the audit log under Application Support as `audit.log`.
- Why this matters:
  - Even without full transcript content, audit and diagnostic logs can reveal user behavior, app usage timing, license activation events, export paths, and target-app interactions.
  - The log files are created with default filesystem behavior and no explicit confidentiality controls.
- Recommendation:
  - Treat audit and diagnostics as sensitive local data.
  - Apply explicit restrictive permissions to the Application Support directory and log files.
  - Review whether path logging and lifecycle metadata should be reduced, redacted, or gated behind a debug/support mode.

### Low

#### SBP-004: Debug-only CLI path overrides trust local executables with no authenticity check

- Evidence:
  - [Sources/ASRCore/WhisperCLIExecutor.swift](/Users/leonstadler/Development/wisper-local/Sources/ASRCore/WhisperCLIExecutor.swift#L14) accepts `WHISPER_CLI_PATH` in `DEBUG`.
  - [Sources/ASRCore/WhisperCLIExecutor.swift](/Users/leonstadler/Development/wisper-local/Sources/ASRCore/WhisperCLIExecutor.swift#L20) also searches local build paths and common installation paths in `DEBUG`.
- Why this matters:
  - This is acceptable for development, but it lowers trust guarantees during local testing because any executable at those paths is accepted if it is marked executable.
  - That can hide supply-chain or path-confusion issues in developer environments.
- Recommendation:
  - Keep this behavior debug-only.
  - Document it clearly for contributors and prefer authenticated/bundled runtime paths in any shared QA or release-like environment.

## Positive Notes

- [apps/macos/AppShell/MacAppConfiguration.swift](/Users/leonstadler/Development/wisper-local/apps/macos/AppShell/MacAppConfiguration.swift#L35) correctly rejects non-HTTPS Sparkle feed URLs.
- [Sources/ASRCore/BundledWhisperRuntime.swift](/Users/leonstadler/Development/wisper-local/Sources/ASRCore/BundledWhisperRuntime.swift#L261) validates bundled runtime checksums when a manifest is present.
- [Sources/LicenseCore/LicenseStore.swift](/Users/leonstadler/Development/wisper-local/Sources/LicenseCore/LicenseStore.swift#L13) uses the Keychain for the primary license secret.
- [apps/macos/AppShell/DictationRuntime.swift](/Users/leonstadler/Development/wisper-local/apps/macos/AppShell/DictationRuntime.swift#L1110) checks the foreground app before paste fallback, which is a good safeguard against cross-app paste injection.

## Recommended Remediation Order

1. Remove plaintext disk caching of the license key and keep the secret only in the Keychain.
2. Harden Application Support storage permissions for transcript history, audit logs, snippets, and other sensitive files.
3. Revisit transcript retention defaults and add a clearer privacy control for persisted history.
4. Review diagnostic/audit entries and reduce sensitive metadata in normal operation.

## Notes

- This review focused on the app code present in this repository and did not include notarization, entitlements, release packaging, or external deployment configuration validation.
- The findings are primarily local confidentiality and privacy issues rather than network-exposed vulnerabilities.
