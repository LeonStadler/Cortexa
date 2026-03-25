# iOS / iPadOS App + Keyboard Extension

This folder now contains:

- host app state + SwiftUI shell for shared snippets, transcript history and offline license handling
- keyboard extension with latest-transcript insertion and quick snippet buttons
- XcodeGen project definition in `apps/ios/WisprLocaliOS/project.yml`
- app-group entitlements for host app and extension

Generate the project with:

```bash
bash ./scripts/generate_ios_xcodeproj.sh
```

Current practical constraints:

- no macOS-style cross-app AX injection on iOS/iPadOS
- insertion is limited to keyboard-extension context via `textDocumentProxy`
- local ASR integration inside the keyboard is still not at feature parity with the macOS runtime path
