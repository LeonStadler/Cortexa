# API Design (Swift Protocols)

## ASR

```swift
public protocol WhisperEngine: AnyObject {
    func loadModel(at path: URL, config: ASRConfig) throws
    func startStreaming() throws
    func pushAudioPCM16kMono(_ buffer: UnsafePointer<Float>, frameCount: Int) throws
    func stopStreaming() async throws -> FinalTranscript
    func transcribeFile(url: URL) async throws -> FinalTranscript
    var onPartial: ((PartialTranscript) -> Void)? { get set }
    var onFinalSegment: ((FinalSegment) -> Void)? { get set }
}
```

Additional concrete API on `WhisperCppEngine` for bundled runtime flow:

```swift
public func loadBundledModel(
    fileName: String,
    config: ASRConfig,
    bundle: Bundle = .main,
    appName: String = "WisprLocal"
) throws
```

This installs `Runtime/whisper-cli` + `Runtime/models/*.bin` from app resources into local app-support and loads the requested model.

## Audio

```swift
public protocol AudioCapture: AnyObject {
    func requestPermissions() async -> Bool
    func start() throws
    func stop() throws
    var onChunk: ((AudioChunk) -> Void)? { get set }
    var onInterruption: ((AudioInterruptionEvent) -> Void)? { get set }
}
```

## Text target (macOS)

```swift
public protocol TextTargetResolver {
    func snapshotFocusedTarget() throws -> TextTargetSnapshot
}

public protocol TextInserter {
    func insertFinalize(_ text: String, into target: TextTargetSnapshot) throws
    func applyStreamingPatch(committed: String, tail: String, into target: TextTargetSnapshot) throws
}
```

## Snippets

```swift
public protocol SnippetMatcher {
    func applyToFinal(_ text: String, locale: Locale) -> String
    func consumeCommittedToken(_ token: String) -> [SnippetReplacementOp]
}
```

## AppShell Runtime Options (macOS)

```swift
struct DictationStartOptions {
    let mode: DictationMode            // .finalize | .streaming
    let language: DictationLanguage    // de | en | auto
    let translationOutput: TranslationOutputMode
    let performance: DictationPerformance // auto | fast | balanced | accurate
    let liveRewriteScope: LiveRewriteScope
    let snippetRules: [SnippetRule]
    let finalResultDeliveryMode: FinalResultDeliveryMode
    let clipboardFallbackWhenNoTarget: Bool
    let aiProcessing: AIProcessingConfiguration
    let muteMusicWhileDictating: Bool
    let asrInitialPrompt: String?
    let dictionaryTerms: [String]
    let appContextText: String?
}
```

The macOS app shell uses these options to:
- select model/config dynamically before session start
- apply stable streaming patching with a bounded mutable tail
- apply snippet substitutions for streaming commits and final transcript
- pass bounded dictionary/context hints into ASR and AI processing
- choose whether the final transcript is inserted or copied, and whether clipboard fallback is allowed when no text target is available
- expose clipboard fallback as an explicit privacy tradeoff rather than a silent background path
