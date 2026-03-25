# Offline Licensing Design

## Goals

- No mandatory phone-home activation.
- Fully local verification.
- One-time purchase first.
- Forward-compatible payload for future subscription mode.

## Key format

`WISPR1-<payload-base32>-<signature-base32>`

- Payload: canonical JSON
- Signature: Ed25519 over raw payload bytes

## Payload fields

- `productTier` (e.g. basic, pro)
- `issueDate` (ISO-8601)
- `expiryDate` (optional; for future time-boxed tokens)
- `featureFlags` (array)

## Verification flow

1. Parse key format.
2. Base32 decode payload + signature.
3. Decode payload JSON.
4. Verify Ed25519 signature using embedded public key.
5. Validate expiry if present.

## Storage

- primary: Keychain (`kSecClassGenericPassword`)
- secondary: local cache with integrity tag (tamper-light detection)

## Anti-tamper (lightweight)

- signed payload verification is the primary protection
- local cache integrity tag prevents simple cache edits
- no kernel hooks, no invasive anti-debug controls

## Operational policy

- License verification is local and synchronous.
- App remains offline-functional after successful activation.
- Invalid/expired licenses degrade gracefully with clear user messaging.

## Current app integration (macOS)

- Settings UI exposes:
  - license key input
  - activate/deactivate actions
  - current validation status text
- successful activation stores key in Keychain and writes integrity-protected cache file
- on startup app tries Keychain first, then cache fallback, then validates locally
- the macOS app reads the production public key from the bundle key `WLMLicensePublicKeyBase64`
- if no production key is injected, the UI stays usable but marks licensing as "not configured"

## Production requirement before release

- inject `WISPR_LICENSE_PUBLIC_KEY_BASE64` before generating the macOS Xcode project so `WLMLicensePublicKeyBase64` is present in the app bundle.
- without injecting this key, activation UI works technically but real production keys cannot validate.
