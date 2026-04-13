# API Design (Swift Protocols)

Funktionsübersicht mit Produktbezug: [features-and-implementation.md](features-and-implementation.md).

## ASR

```swift
public enum VoiceProviderID: String {
    case whisperCpp
    case nvidiaParakeet
}

public struct VoiceProviderDescriptor {
    let id: String
    let displayName: String
    let summary: String
    let isAvailable: Bool
}

public struct VoiceModelDescriptor {
    let id: String
    let providerID: String
    let displayName: String
    let languageCode: String?
    let supportsTranslationToEnglish: Bool
    let speedScore: Int
    let accuracyScore: Int
    let sizeLabel: String
    let installState: VoiceModelInstallState
    let localFileName: String?
    let downloadIdentifier: String?
}

public struct VoiceLanguageOverride {
    let languageCode: String
    let modelID: String
}

public enum LocalVoiceModelCatalog {
    static let defaultProviderID: String
    static let defaultModelID: String
    static func availableProviders(parakeetBinaryURL: URL? = nil) -> [VoiceProviderDescriptor]
    static func availableModels(includeParakeet: Bool = false) -> [VoiceModelDescriptor]
}

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

Current local speech-model surface:

- bundled default: `Standard` -> `ggml-base.bin`
- additional whisper.cpp-backed local models are installable on demand via a catalog layer
- `Translate` support always means Whisper translation to English only
- language-specific `.en` variants are modeled explicitly and do not expose translation
- NVIDIA Parakeet descriptors can exist in the catalog contract, but only surface in the UI when a real local backend is present

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

public enum AIRevisionGoal {
    case cleanup
    case adjustTone
    case adjustSalutation
    case adaptFormat
}

public enum AIFormattingMode {
    case plainText
    case email
    case message
    case whatsapp
    case documentation
    case scientificPaper
}

public struct AIProcessingConfiguration {
    let enabled: Bool
    let selectedModelID: String?
    let applyDuringLiveInsertion: Bool
    let applyToFinalResult: Bool
    let revisionGoal: AIRevisionGoal
    let formattingMode: AIFormattingMode
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
- The macOS shell shows AI models directly without a separate model-visibility toggle; the catalog keeps only the provider metadata required for selection and quick settings.
- The macOS shell keeps a configurable voice-model active duration so the runtime can unload idle model state after a short warm window instead of keeping it resident forever.
- AI configuration now separates the default cleanup goal from optional tone, salutation, and output-format adaptation. Formatting modes such as email, message, WhatsApp, documentation, and scientific writing are propagated into the shared prompt builder for both Apple and remote providers.
- Writing-style options are constrained by the selected formatting mode so the shell does not offer obviously incompatible combinations such as casual scientific writing or businesslike documentation.
- If AI processing is disabled, unavailable, or fails at runtime, the raw transcript path remains the fallback and dictation continues.

## AppShell Runtime Options (macOS)

```swift
struct DictationStartOptions {
    let mode: DictationMode            // .finalize | .streaming
    let language: DictationLanguage    // de | en | fr | es | it | nl | pt | pl | tr | cs | zh | auto
    let performance: DictationPerformance // auto | fast | balanced | accurate
    let translationOutput: TranslationOutputMode // .original | .english
    let selectedVoiceProviderID: String
    let selectedVoiceModelID: String
    let liveRewriteScope: LiveRewriteScope
    let aiProcessing: AIProcessingConfiguration
    let audioProcessing: AudioProcessingConfiguration
    let snippetRules: [SnippetRule]
    let finalResultDeliveryMode: FinalResultDeliveryMode
    let clipboardFallbackWhenNoTarget: Bool
    let muteMusicWhileDictating: Bool
    let asrInitialPrompt: String?
    let dictionaryTerms: [String]
    let liveContextText: String?
    let finalContextText: String?
}
```

```swift
struct AudioProcessingConfiguration {
    let inputLevelCompensationEnabled: Bool
    let silenceRemovalEnabled: Bool
    let dynamicNormalizationEnabled: Bool
    let noiseSuppressionLevel: Float
}
```

The macOS app shell uses these options to:

- resolve the effective local speech model before session start, including optional per-language overrides
- select model/config dynamically before session start
- pass explicit Whisper auto-detect (`auto`) instead of silently mapping auto language selection to English
- keep transcription, translation, and AI processing as separate runtime stages
- apply app-level audio preprocessing before ASR, including adjustable noise suppression
- apply stable streaming patching with a bounded mutable tail
- sanitize common non-speech placeholders such as `(silence)` or `[music]` before live insertion and final delivery
- apply snippet substitutions before optional translation and optional AI processing
- optionally translate Whisper output to English only when `translationOutput == .english` and the selected voice model supports it
- optionally run AI processing separately for live insertion updates and for the final result
- optionally feed Whisper with a bounded preferred-terms prompt derived from the personal dictionary
- optionally pass bounded app context and dictionary terms into AI prompt construction for live and/or final processing
- optionally pause Apple Music and Spotify during dictation and resume only players paused by Wispr itself
- maintain one provider-agnostic AI model picker across Apple on-device and remote API-backed providers
- maintain a separate local speech-model picker with provider/model IDs, install state, and language-specific defaults
- expose optional technical diagnostic logging that captures detailed runtime diagnostics plus ASR subprocess lifecycle events for support cases
- choose whether the final transcript is inserted or copied, and whether clipboard fallback is allowed when no text target is available
- expose clipboard fallback as an explicit privacy tradeoff rather than a silent background path
- use the same AX focused-target probe for permission readiness and direct insertion, so the shell does not present insertion as available when AX later answers with `apiDisabled`
- record final-delivery telemetry for insertion path, clipboard restore, and auto-send execution

Runtime pipeline order:

1. raw Whisper transcript
2. snippet replacement
3. optional translation
4. optional AI processing
5. insert / clipboard / history delivery

Current macOS AI delivery rule:

- Live AI processing only runs when `applyDuringLiveInsertion == true`.
- Final AI processing only runs when `applyToFinalResult == true`.
- In the current macOS runtime, a live-streaming session skips the separate final AI pass to avoid re-rewriting text that was already shaped during live insertion.
