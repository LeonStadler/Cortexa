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

## AI Processing

```swift
public enum AIProviderKind {
    case appleFoundation
    case localDownloaded
    case remoteAPI
}

public struct AIModelDescriptor {
    let id: String
    let providerID: String
    let requestModelID: String
    let displayName: String
    let providerKind: AIProviderKind
    let availability: AIModelAvailability
    let quickSettingsEligible: Bool
}

public enum AIRemoteProviderPreset {
    case openRouter
    case openAI
    case groq
    case mistral
    case deepSeek
    case togetherAI
    case fireworksAI
    case xAI
    case ollama
    case lmStudio
    case customOpenAICompatible
}

public struct AIRemoteProviderConfiguration {
    let id: String
    let preset: AIRemoteProviderPreset
    let displayName: String
    let baseURLString: String
    let modelsPath: String
    let chatCompletionsPath: String
    let requiresAPIKey: Bool
    let isEnabled: Bool
    let appReferer: String?
    let appTitle: String?
    let discoveredModels: [AIRemoteModel]
}

public struct AIRemoteModel {
    let id: String
    let displayName: String
    let quickSettingsEligible: Bool
}

public enum AIWritingStyle {
    case none
    case simple
    case business
    case academic
    case casual
    case enthusiastic
    case friendlyConfident
    case diplomatic
}

public enum AISalutation {
    case none
    case formal
    case informal
}

public struct AIProcessingConfiguration {
    let enabled: Bool
    let selectedModelID: String?
    let applyDuringLiveInsertion: Bool
    let applyToFinalResult: Bool
    let style: AIWritingStyle
    let salutation: AISalutation
}
```

Current provider surface:
- Apple on-device processing is exposed as a single runtime-discovered model entry (`Apple On-Device`) when the platform supports the Foundation Models runtime.
- Remote API providers are configured dynamically and are not backed by a hardcoded model list. The current macOS shell ships presets for OpenRouter, OpenAI, Groq, Mistral, DeepSeek, Together AI, Fireworks AI, xAI, Ollama and LM Studio, plus a generic OpenAI-compatible provider editor (`baseURL`, `modelsPath`, `chatCompletionsPath`).
- Remote models are discovered from the provider's `/models` endpoint and mapped into the shared model catalog via a provider-qualified selection ID (`providerID::modelID`), while the transport uses the provider's raw `requestModelID`.
- Providers can declare whether they require an API key. This keeps local OpenAI-compatible runtimes such as Ollama or LM Studio usable without fake credentials while still filtering unavailable authenticated providers out of quick settings.
- Models that are unavailable locally, unsupported on the current device, or missing required credentials are excluded from quick settings.
- If AI processing is disabled, unavailable, or fails at runtime, the raw transcript path remains the fallback and dictation continues.

## AppShell Runtime Options (macOS)

```swift
struct DictationStartOptions {
    let mode: DictationMode            // .finalize | .streaming
    let language: DictationLanguage    // de | en | auto
    let performance: DictationPerformance // auto | fast | balanced | accurate
    let translationOutput: TranslationOutputMode // .original | .english
    let liveRewriteScope: LiveRewriteScope
    let aiProcessing: AIProcessingConfiguration
    let snippetRules: [SnippetRule]
    let finalResultDeliveryMode: FinalResultDeliveryMode
    let clipboardFallbackWhenNoTarget: Bool
}
```

The macOS app shell uses these options to:
- select model/config dynamically before session start
- pass explicit Whisper auto-detect (`auto`) instead of silently mapping auto language selection to English
- keep transcription, translation, and AI processing as separate runtime stages
- apply stable streaming patching with a bounded mutable tail
- apply snippet substitutions before optional translation and optional AI processing
- optionally translate Whisper output to English only when `translationOutput == .english`
- optionally run AI processing separately for live insertion updates and for the final result
- maintain one provider-agnostic AI model picker across Apple on-device and remote API-backed providers
- expose an optional debug mode that captures detailed runtime diagnostics plus ASR subprocess lifecycle events for support cases
- choose whether the final transcript is inserted or copied, and whether clipboard fallback is allowed when no text target is available
- expose clipboard fallback as an explicit privacy tradeoff rather than a silent background path

Runtime pipeline order:
1. raw Whisper transcript
2. snippet replacement
3. optional translation
4. optional AI processing
5. insert / clipboard / history delivery
