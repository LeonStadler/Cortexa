# Building whisper.cpp XCFramework and Runtime Bundle

## Goal

End users should install only the app. No Homebrew/CMake setup is required on user machines.

Developer machines build and package the runtime once; the app ships it as resources.

## Prerequisites (developer only)

- Xcode command line tools
- CMake
- Python 3 (optional for model tooling)

## 1) Fetch source

```bash
./scripts/bootstrap_whisper_submodule.sh
```

## 2) Build XCFramework and CLI

```bash
./scripts/build_whisper_xcframework.sh
```

Outputs:

- `artifacts/whisper/whisper.xcframework` (when available)
- `artifacts/whisper/whisper-cli`

Notes:

- If full Xcode/iOS SDKs are missing, the script now skips XCFramework build and still builds `whisper-cli` for macOS.
- Force/disable behavior:
  - `ENABLE_XCFRAMEWORK_BUILD=ON ./scripts/build_whisper_xcframework.sh`
  - `ENABLE_XCFRAMEWORK_BUILD=OFF ./scripts/build_whisper_xcframework.sh`

## 3) Download models

```bash
./scripts/download_models.sh
```

## 4) Prepare app runtime resources

```bash
./scripts/prepare_runtime_bundle.sh
```

This copies runtime assets into:

- `apps/macos/AppShell/Resources/Runtime/whisper-cli`
- `apps/macos/AppShell/Resources/Runtime/models/*.bin`

## 5) App startup/runtime behavior

`WhisperCppEngine` now supports bundled runtime usage:

- `loadBundledModel(fileName:config:bundle:)` installs Runtime assets from app bundle to local app-support runtime and loads model.
- `loadModel(at:config:)` automatically tries bundled runtime installation if CLI is not already discoverable.

## 6) Optional environment override

For local debugging only:

```bash
export WHISPER_CLI_PATH="$(pwd)/artifacts/whisper/whisper-cli"
```

### Validation and hardening

- `cmake` is now required by `scripts/build_whisper_xcframework.sh` and the script will fail fast when it is missing rather than silently crashing mid-build.
- When you explicitly set `ENABLE_XCFRAMEWORK_BUILD=ON`, the script halts if `xcodebuild` is unavailable or the upstream XCFramework script exits with an error; this prevents release candidates from silently shipping without the dependency bundle.
- Always confirm the CLI executable landed under `artifacts/whisper/whisper-cli` and (if applicable) `artifacts/whisper/whisper.xcframework` exists before continuing with app packaging. Use `file` to inspect architectures if you need to vet the binary for Apple Silicon vs. Intel.
- The distribution checklist in `docs/distribution.md` bundles the release-level verification steps into `scripts/verify_macos_release_bundle.sh`, so run that script after the app is signed/notarized to double-check Gatekeeper expectations before creating the DMG/PKG.
