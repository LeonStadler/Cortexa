import AIProcessingCore
import ASRCore
import AVFoundation
import AppKit
import ApplicationServices
import AudioCore
import CapabilityCore
import Carbon
import Foundation
import SessionCore
import SnippetCore
import TextTargetMac

enum DictationMode {
    case finalize
    case streaming
}

enum DictationLanguage: String, CaseIterable, Identifiable {
    case german = "de"
    case english = "en"
    case french = "fr"
    case spanish = "es"
    case italian = "it"
    case dutch = "nl"
    case portuguese = "pt"
    case polish = "pl"
    case turkish = "tr"
    case czech = "cs"
    case chinese = "zh"
    case auto = "auto"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .german:
            return "Deutsch"
        case .english:
            return "Englisch"
        case .french:
            return "Französisch"
        case .spanish:
            return "Spanisch"
        case .italian:
            return "Italienisch"
        case .dutch:
            return "Niederländisch"
        case .portuguese:
            return "Portugiesisch"
        case .polish:
            return "Polnisch"
        case .turkish:
            return "Türkisch"
        case .czech:
            return "Tschechisch"
        case .chinese:
            return "Chinesisch"
        case .auto:
            return "Auto"
        }
    }

    func localizedDisplayName(interfaceLanguageCode: String) -> String {
        switch (interfaceLanguageCode, self) {
        case ("en", .german):
            return "German"
        case ("en", .english):
            return "English"
        case ("en", .french):
            return "French"
        case ("en", .spanish):
            return "Spanish"
        case ("en", .italian):
            return "Italian"
        case ("en", .dutch):
            return "Dutch"
        case ("en", .portuguese):
            return "Portuguese"
        case ("en", .polish):
            return "Polish"
        case ("en", .turkish):
            return "Turkish"
        case ("en", .czech):
            return "Czech"
        case ("en", .chinese):
            return "Chinese"
        case ("en", .auto):
            return "Auto"
        default:
            return displayName
        }
    }

    var asrHint: String? {
        switch self {
        case .german:
            return "de"
        case .english:
            return "en"
        case .french:
            return "fr"
        case .spanish:
            return "es"
        case .italian:
            return "it"
        case .dutch:
            return "nl"
        case .portuguese:
            return "pt"
        case .polish:
            return "pl"
        case .turkish:
            return "tr"
        case .czech:
            return "cs"
        case .chinese:
            return "zh"
        case .auto:
            return "auto"
        }
    }

    var locale: Locale {
        switch self {
        case .german:
            return Locale(identifier: "de_DE")
        case .english:
            return Locale(identifier: "en_US")
        case .french:
            return Locale(identifier: "fr_FR")
        case .spanish:
            return Locale(identifier: "es_ES")
        case .italian:
            return Locale(identifier: "it_IT")
        case .dutch:
            return Locale(identifier: "nl_NL")
        case .portuguese:
            return Locale(identifier: "pt_PT")
        case .polish:
            return Locale(identifier: "pl_PL")
        case .turkish:
            return Locale(identifier: "tr_TR")
        case .czech:
            return Locale(identifier: "cs_CZ")
        case .chinese:
            return Locale(identifier: "zh_CN")
        case .auto:
            return Locale.current
        }
    }
}

enum TranslationOutputMode: String, CaseIterable, Identifiable {
    case original
    case english

    var id: String { rawValue }

    func localizedDisplayName(interfaceLanguageCode: String) -> String {
        switch (interfaceLanguageCode, self) {
        case ("en", .original):
            return "Original"
        case ("en", .english):
            return "English"
        case (_, .original):
            return "Keine Übersetzung"
        case (_, .english):
            return "Nach Englisch"
        }
    }

    var asrTranslationMode: ASRTranslationMode {
        switch self {
        case .original:
            return .original
        case .english:
            return .toEnglish
        }
    }
}

enum DictationPerformance: String, CaseIterable, Identifiable {
    case auto
    case fast
    case balanced
    case accurate

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auto:
            return "Auto"
        case .fast:
            return "Schnell"
        case .balanced:
            return "Ausgeglichen"
        case .accurate:
            return "Präzise"
        }
    }

    func localizedDisplayName(interfaceLanguageCode: String) -> String {
        switch (interfaceLanguageCode, self) {
        case ("en", .auto):
            return "Auto"
        case ("en", .fast):
            return "Fast"
        case ("en", .balanced):
            return "Balanced"
        case ("en", .accurate):
            return "Accurate"
        default:
            return displayName
        }
    }
}

struct DictationStartOptions {
    let mode: DictationMode
    let language: DictationLanguage
    let translationOutput: TranslationOutputMode
    let performance: DictationPerformance
    let selectedVoiceProviderID: String
    let selectedVoiceModelID: String
    let liveRewriteScope: LiveRewriteScope
    let snippetRules: [SnippetRule]
    let finalResultDeliveryMode: FinalResultDeliveryMode
    let clipboardFallbackWhenNoTarget: Bool
    let simulateKeypresses: Bool
    let restoreClipboardAfterPaste: Bool
    let autoSendAfterPaste: Bool
    let aiProcessing: AIProcessingConfiguration
    let audioProcessing: AudioProcessingConfiguration
    let soundFeedback: SoundFeedbackConfiguration
}

enum FinalResultDeliveryMode: String, CaseIterable, Identifiable {
    case insert
    case clipboardOnly

    var id: String { rawValue }
}

enum FinalTranscriptDeliveryOutcome: Equatable {
    case inserted
    case copiedToClipboard
    case historyOnlyNoTarget
    case failed(String)
}

struct FinalTranscriptEvent {
    let text: String
    let languageCode: String
    let mode: DictationMode
    let deliveryOutcome: FinalTranscriptDeliveryOutcome
}

enum DictationRuntimeError: LocalizedError {
    case alreadyRunning
    case notRunning
    case microphonePermissionDenied
    case accessibilityPermissionDenied
    case focusedElementUnavailable
    case unsupportedTextTarget
    case invalidAudioPipeline
    case unsafePasteFallback

    var errorDescription: String? {
        switch self {
        case .alreadyRunning:
            return "Diktat läuft bereits."
        case .notRunning:
            return "Kein aktives Diktat."
        case .microphonePermissionDenied:
            return "Mikrofonberechtigung fehlt."
        case .accessibilityPermissionDenied:
            return "Bedienungshilfen-Berechtigung fehlt."
        case .focusedElementUnavailable:
            return "Kein fokussiertes Textfeld gefunden."
        case .unsupportedTextTarget:
            return "Das fokussierte Element unterstützt keine Texteingabe."
        case .invalidAudioPipeline:
            return "Audio-Pipeline konnte nicht initialisiert werden."
        case .unsafePasteFallback:
            return
                "Paste-Fallback wurde blockiert, weil der Fokus nicht mehr auf der ursprünglichen Ziel-App liegt."
        }
    }
}

private struct LockedTextTarget {
    let element: AXUIElement
    let insertionLocation: Int
    let originalSelectedLength: Int
    let fallbackBundleIdentifier: String?
    var insertedLength: Int
}

private struct FinalInsertionMetrics {
    let path: String
    let clipboardRestored: Bool
    let autoSent: Bool
}

private struct PasteboardSnapshot {
    let items: [NSPasteboardItem]

    static func capture(from pasteboard: NSPasteboard) -> PasteboardSnapshot {
        let copiedItems =
            pasteboard.pasteboardItems?.compactMap { item in
                item.copy() as? NSPasteboardItem
            } ?? []
        return PasteboardSnapshot(items: copiedItems)
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        guard !items.isEmpty else { return }
        pasteboard.writeObjects(items)
    }
}

final class DictationRuntime: @unchecked Sendable {
    var onStatus: ((String) -> Void)?
    var onDiagnostic: ((String) -> Void)?
    var onDebugEvent: ((String) -> Void)?
    var onTranscript: ((String) -> Void)?
    var onFinalTranscript: ((FinalTranscriptEvent) -> Void)?
    var onSessionActivityChanged: ((Bool) -> Void)?
    var onAccessibilityPermissionIssue: ((String) -> Void)?
    /// Mikrofon-/AX-Dialoge oder TCC-Updates: UI soll `authorizationStatus` / AX erneut lesen.
    var onPermissionInteractionFinished: (() -> Void)?

    private let whisperEngine = WhisperCppEngine()
    private let processQueue = DispatchQueue(label: "wispr.dictation.process", qos: .userInitiated)
    private let insertionQueue = DispatchQueue(label: "wispr.dictation.insert", qos: .userInitiated)
    private let capabilityProfiler = CapabilityProfiler()
    private var aiProcessingService = AIProcessingService()
    private let soundFeedbackPlayer = SoundFeedbackPlayer()
    private let sessionLock = NSLock()

    private let audioEngine = AVAudioEngine()
    private var converter: AVAudioConverter?
    private var audioPreprocessor = AudioPreprocessor()
    private var runningMode: DictationMode?
    private var runningLocale: Locale = Locale(identifier: "de_DE")
    private var target: LockedTextTarget?
    private var isRunning = false
    private var isStarting = false
    private var startTask: Task<Void, Never>?
    private var runtimePrepared = false
    private var latestInsertedPreview = ""
    private var stableCommitter = StreamingCommitStabilizer(stabilityThreshold: 2)
    private var snippetMatcher: DefaultSnippetMatcher?
    private var loadedModelPath: URL?
    private var loadedConfig: ASRConfig?
    private var currentOptions: DictationStartOptions?
    private var voiceModelActiveDuration: VoiceModelActiveDuration = .oneMinute
    private var lastKnownTarget: LockedTextTarget?
    private var waitingForInsertionTarget = false
    private var pendingStreamingInsertionTask: Task<Void, Never>?
    private var runtimeUnloadTask: Task<Void, Never>?
    private var speechActivityDetected = false
    private var speechChunkStreak = 0
    private var maxObservedRMS: Float = 0
    private var lastRecoverableInsertDiagnosticAt: Date?
    private var lastAccessibilityPermissionIssueAt: Date?
    private var accessibilityPermissionGranted = false
    private let focusedTargetRetryCount = 8
    private let focusedTargetRetryDelayNanoseconds: UInt64 = 150_000_000
    private let pendingInsertionTimeoutNanoseconds: UInt64 = 5_000_000_000
    private let pendingInsertionPollNanoseconds: UInt64 = 150_000_000
    private let speechRMSActivationThreshold: Float = 0.008
    private let speechRMSReleaseThreshold: Float = 0.004
    private let speechActivationChunkCount = 2

    private func withSessionLock<T>(_ work: () throws -> T) rethrows -> T {
        sessionLock.lock()
        defer { sessionLock.unlock() }
        return try work()
    }

    private func publishPermissionInteractionFinished() {
        DispatchQueue.main.async { [weak self] in
            self?.onPermissionInteractionFinished?()
        }
    }

    private func publishAccessibilityPermissionIssue(_ message: String, context: String) {
        let now = Date()
        if let lastAccessibilityPermissionIssueAt,
            now.timeIntervalSince(lastAccessibilityPermissionIssueAt) < 1.5
        {
            publishDebug("permissions.accessibility.issue.suppressed context=\(context)")
            return
        }

        lastAccessibilityPermissionIssueAt = now
        accessibilityPermissionGranted = false
        publishDebug("permissions.accessibility.issue context=\(context) message=\(message)")
        DispatchQueue.main.async { [weak self] in
            self?.onAccessibilityPermissionIssue?(message)
        }
    }

    private func publishStaleAccessibilityPermissionGuidance(context: String) {
        publishAccessibilityPermissionIssue(
            "Die Bedienungshilfen-Freigabe scheint zu einem frueheren Build zu gehoeren. Bitte entferne WisprLocal in den Bedienungshilfen kurz und fuege es erneut hinzu.",
            context: context
        )
    }

    private func reportAccessibilityIssueIfProbeLooksStale(context: String) {
        let snapshot = AXTextAccess.permissionSnapshot()
        switch snapshot.probeResult {
        case .apiDisabled, .probeFailed:
            publishStaleAccessibilityPermissionGuidance(context: context)
        default:
            break
        }
    }

    private func runOnMainThread<T>(_ work: () throws -> T) throws -> T {
        if Thread.isMainThread {
            return try work()
        }

        return try DispatchQueue.main.sync(execute: work)
    }

    func prepareRuntime() {
        cancelRuntimeUnloadTask()
        guard !runtimePrepared else { return }
        publishDebug("runtime.prepare.begin")

        do {
            let runtime = try BundledWhisperRuntimeInstaller.installBundledRuntime(
                bundle: .main, appName: "WisprLocal")
            let bootstrapModel = runtime.modelsDirectoryURL.appendingPathComponent(
                runtime.defaultModelFileName)
            let bootstrapConfig = ASRConfig(
                languageHint: "de",
                translationMode: .original,
                providerID: VoiceProviderID.whisperCpp.rawValue,
                catalogModelID: LocalVoiceModelCatalog.defaultModelID,
                modelID: runtime.defaultModelFileName,
                backend: .whisperCpp,
                latencyProfile: .streaming,
                threadCount: max(2, ProcessInfo.processInfo.activeProcessorCount / 2),
                beamSize: 1,
                chunkMilliseconds: 280
            )
            try whisperEngine.loadModel(at: bootstrapModel, config: bootstrapConfig)
            loadedModelPath = bootstrapModel
            loadedConfig = bootstrapConfig
            runtimePrepared = true
            publishDiagnostic("ASR runtime ready (bundled model loaded).")
            publishDebug("runtime.prepare.ready model=\(bootstrapModel.lastPathComponent)")
            scheduleRuntimeUnloadIfNeeded()

            whisperEngine.onPartial = { [weak self] partial in
                self?.handlePartialText(partial.text)
            }
            whisperEngine.onDebugEvent = { [weak self] event in
                self?.publishDebug(event)
            }
        } catch {
            publishStatus("Error")
            publishDiagnostic("ASR init failed: \(error.localizedDescription)")
            publishDebug("runtime.prepare.failed error=\(error.localizedDescription)")
        }
    }

    func setVoiceModelActiveDuration(_ duration: VoiceModelActiveDuration) {
        withSessionLock {
            voiceModelActiveDuration = duration
        }

        publishDebug("runtime.voiceModel.duration=\(duration.rawValue)")
        if !withSessionLock({ isRunning }) {
            scheduleRuntimeUnloadIfNeeded()
        }
    }

    func toggle(options: DictationStartOptions) {
        let snapshot = withSessionLock {
            (isStarting: isStarting, isRunning: isRunning)
        }

        if snapshot.isStarting {
            startTask?.cancel()
            cleanupSession()
            publishStatus("Idle")
            publishDiagnostic("Start wurde abgebrochen.")
            return
        }

        if snapshot.isRunning {
            Task {
                await stop()
            }
            return
        }

        start(options: options)
    }

    func cancel() {
        let snapshot = withSessionLock {
            (isStarting: isStarting, isRunning: isRunning)
        }

        guard snapshot.isStarting || snapshot.isRunning else {
            publishDiagnostic(DictationRuntimeError.notRunning.localizedDescription)
            return
        }

        publishDebug("dictation.cancel.begin")
        cleanupSession()
        publishStatus("Idle")
        publishDiagnostic("Diktat wurde abgebrochen.")
        publishDebug("dictation.cancel.completed")
    }

    func start(options: DictationStartOptions) {
        publishDebug(
            "dictation.start.requested mode=\(options.mode == .streaming ? "streaming" : "finalize") language=\(options.language.rawValue) translation=\(options.translationOutput.rawValue) performance=\(options.performance.rawValue)"
        )
        let startPermissionMessage = withSessionLock { () -> String? in
            if isRunning {
                return DictationRuntimeError.alreadyRunning.localizedDescription
            }
            if isStarting {
                return "Diktat startet bereits."
            }
            isStarting = true
            return nil
        }

        if let startPermissionMessage {
            publishDiagnostic(startPermissionMessage)
            return
        }

        prepareRuntime()
        guard runtimePrepared else {
            withSessionLock {
                isStarting = false
            }
            return
        }

        startTask = Task { [weak self] in
            guard let self else { return }
            defer {
                self.withSessionLock {
                    self.isStarting = false
                    self.startTask = nil
                }
            }

            let micGranted = await requestMicrophonePermission()
            publishPermissionInteractionFinished()
            self.publishDebug("permissions.microphone granted=\(micGranted)")
            guard micGranted else {
                publishStatus("Error")
                publishDiagnostic(
                    DictationRuntimeError.microphonePermissionDenied.localizedDescription)
                return
            }

            do {
                let requiresDirectInsertion =
                    options.mode == .streaming
                    || options.finalResultDeliveryMode == .insert
                    || options.simulateKeypresses
                let accessibilityGranted = requestAccessibilityPermission(
                    promptIfNeeded: requiresDirectInsertion)
                publishPermissionInteractionFinished()
                publishDebug(
                    "permissions.accessibility granted=\(accessibilityGranted) requiresDirectInsertion=\(requiresDirectInsertion)"
                )
                accessibilityPermissionGranted = accessibilityGranted

                let effectiveMode: DictationMode = accessibilityGranted ? options.mode : .finalize
                try configureEngine(for: options, runtimeMode: effectiveMode)

                if accessibilityGranted {
                    let lockedTarget: LockedTextTarget?
                    do {
                        lockedTarget = try await captureFocusedTextTargetWithRetry(
                            emitWaitingDiagnostics: false)
                    } catch DictationRuntimeError.accessibilityPermissionDenied {
                        publishStaleAccessibilityPermissionGuidance(
                            context: "start.capture-focused-target"
                        )
                        throw DictationRuntimeError.accessibilityPermissionDenied
                    } catch {
                        lockedTarget = nil
                    }
                    withSessionLock {
                        self.target = lockedTarget
                        if let lockedTarget {
                            self.lastKnownTarget = lockedTarget
                            self.waitingForInsertionTarget = false
                        } else {
                            self.waitingForInsertionTarget = true
                        }
                    }
                    if lockedTarget == nil {
                        publishDiagnostic(
                            "Kein Textfeld aktiv. Das Diktat startet trotzdem und wartet auf ein fokussiertes Ziel."
                        )
                        schedulePendingStreamingInsertionIfNeeded()
                    }
                } else {
                    withSessionLock {
                        self.target = nil
                        self.waitingForInsertionTarget = false
                    }
                    if requiresDirectInsertion {
                        publishDiagnostic(
                            "Bedienungshilfen fehlen. Das Diktat läuft im eingeschränkten Modus ohne direktes Einfügen."
                        )
                    }
                }
                withSessionLock {
                    self.runningMode = effectiveMode
                    self.runningLocale = options.language.locale
                    self.currentOptions = options
                    self.latestInsertedPreview = ""
                    self.speechActivityDetected = false
                    self.speechChunkStreak = 0
                    self.maxObservedRMS = 0
                    self.audioPreprocessor.reset()
                    self.stableCommitter = self.makeStreamingCommitStabilizer(
                        for: options, runtimeMode: effectiveMode)
                    self.snippetMatcher = DefaultSnippetMatcher(rules: options.snippetRules)
                }

                try whisperEngine.startStreaming()
                try startAudioCapture()
                publishDebug(
                    "dictation.start.ready effectiveMode=\(effectiveMode == .streaming ? "streaming" : "finalize")"
                )

                withSessionLock {
                    self.isRunning = true
                }
                publishSessionActivity(true)
                publishStatus("Recording")
                playSoundFeedback(.started, settings: options.soundFeedback)
                let modeText = effectiveMode == .streaming ? "Streaming Insert" : "Finalize Insert"
                let translationText =
                    options.translationOutput == .english ? ", translated to English" : ""
                publishDiagnostic(
                    "Recording (\(modeText), \(options.language.displayName)\(translationText))")
            } catch {
                abortSession(reason: "Start failed: \(error.localizedDescription)")
            }
        }
    }

    func stop() async {
        let isCurrentlyRunning = withSessionLock { isRunning }
        guard isCurrentlyRunning else {
            publishDiagnostic(DictationRuntimeError.notRunning.localizedDescription)
            return
        }

        do {
            publishDebug("dictation.stop.begin")
            stopAudioCapture()
            let final = try await whisperEngine.stopStreaming()
            let detectedLanguageCode = resolvedLanguageCode(from: final)
            let effectiveLocale = locale(for: detectedLanguageCode) ?? runningLocale
            let normalized = sanitizeTranscriptArtifacts(
                in: normalizeText(final.text), stage: .final)
            let snippetAdjustedText = applySnippetsToFinalText(normalized, locale: effectiveLocale)
            let processingService = withSessionLock { aiProcessingService }
            let finalProcessingOutcome: AIProcessingOutcome
            if shouldRunFinalAIProcessing() {
                finalProcessingOutcome = await processingService.process(
                    AIProcessingRequest(
                        text: snippetAdjustedText,
                        stage: .final,
                        locale: effectiveLocale,
                        configuration: currentAIProcessingConfiguration()
                    )
                )
            } else {
                finalProcessingOutcome = .bypassed(
                    text: snippetAdjustedText,
                    reason: "Final AI processing is skipped while live insertion is active."
                )
            }
            let finalText = sanitizeTranscriptArtifacts(
                in: finalProcessingOutcome.text, stage: .final)

            if shouldDiscardTranscript(finalText) {
                publishTranscript("")
                publishStatus("Idle")
                publishDiagnostic(
                    "Kein verwertbares Sprachsignal erkannt. Das Transkript wurde verworfen.")
                playSoundFeedback(
                    .stopped, settings: withSessionLock { currentOptions?.soundFeedback })
                cleanupSession()
                return
            }

            let deliveryOutcome = await deliverFinalText(finalText)

            publishTranscript(finalText)
            emitProcessingDiagnosticIfNeeded(finalProcessingOutcome, stage: .final)
            let finalEventMetadata = withSessionLock {
                (
                    languageCode: detectedLanguageCode,
                    mode: currentOptions?.mode ?? .finalize
                )
            }
            publishFinalTranscript(
                FinalTranscriptEvent(
                    text: finalText,
                    languageCode: finalEventMetadata.languageCode,
                    mode: finalEventMetadata.mode,
                    deliveryOutcome: deliveryOutcome
                )
            )
            publishStatus("Idle")
            publishDiagnostic("Letztes Transkript verarbeitet.")
            playSoundFeedback(.stopped, settings: withSessionLock { currentOptions?.soundFeedback })
            publishDebug(
                "dictation.stop.completed textLength=\(finalText.count) delivery=\(String(describing: deliveryOutcome))"
            )
        } catch {
            abortSession(reason: "Stop failed: \(error.localizedDescription)")
            return
        }

        cleanupSession()
    }

    func openMicrophoneSettings() {
        guard
            let url = URL(
                string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
            )
        else { return }
        NSWorkspace.shared.open(url)
    }

    func openAccessibilitySettings() {
        guard
            let url = URL(
                string:
                    "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        else { return }
        NSWorkspace.shared.open(url)
    }

    /// Systemdialog für Bedienungshilfen anzeigen (ohne eine Diktatsitzung zu starten).
    func promptAccessibilityTrustFromUser() {
        _ = requestAccessibilityPermission(promptIfNeeded: true)
    }

    func setAIProcessingService(_ service: AIProcessingService) {
        withSessionLock {
            aiProcessingService = service
        }
    }

    private func handlePartialText(_ text: String) {
        let snapshot = withSessionLock {
            (
                isRunning: isRunning,
                runningMode: runningMode,
                speechActivityDetected: speechActivityDetected,
                hasLockedTarget: target != nil
            )
        }
        guard snapshot.isRunning, snapshot.runningMode == .streaming else { return }
        // Ohne gesichertes Textziel: RMS-Gate, sonst „Warten auf Ziel“ nur durch echten Sprachbeginn auslösen.
        // Mit Ziel: Partials sofort einfügen (sonst wirken leise Anfänge/Fernfeld-Mikros hackelig oder leer).
        if !snapshot.hasLockedTarget {
            guard snapshot.speechActivityDetected else { return }
        }

        let normalized = sanitizeTranscriptArtifacts(in: normalizeText(text), stage: .live)
        guard !normalized.isEmpty else { return }

        insertionQueue.async { [weak self] in
            guard let self else { return }
            var target = self.target
            var recoverablePatchText = normalized

            do {
                let stable = self.stableCommitter.ingestPartial(normalized)
                let committedWithSnippets = self.applySnippetsToFinalText(
                    stable.committedPrefix, locale: self.runningLocale)
                let mergedPatchText = self.sanitizeTranscriptArtifacts(
                    in: self.normalizeText(committedWithSnippets + stable.tail),
                    stage: .live
                )
                let patchText = self.processLiveTextIfNeeded(mergedPatchText)
                recoverablePatchText = patchText

                guard !patchText.isEmpty else { return }

                if target == nil {
                    if let resolvedTarget = self.resolveAvailableTextTarget() {
                        target = resolvedTarget
                    } else {
                        self.withSessionLock {
                            self.waitingForInsertionTarget = true
                            self.latestInsertedPreview = patchText
                        }
                        self.publishTranscript(patchText)
                        self.schedulePendingStreamingInsertionIfNeeded()
                        return
                    }
                }

                let maximumMutableCharacterCount = self.withSessionLock {
                    self.currentOptions?.liveRewriteScope.maximumMutableCharacterCount ?? 72
                }
                let preservePrefixLength =
                    self.target == nil
                    ? 0
                    : self.streamingPreservedPrefixLength(
                        previousText: self.latestInsertedPreview,
                        newText: patchText,
                        maximumMutableCharacterCount: maximumMutableCharacterCount
                    )

                if patchText == self.latestInsertedPreview, self.target != nil {
                    return
                }

                do {
                    guard var activeTarget = target else { return }
                    try self.replaceInsertedText(
                        patchText,
                        in: activeTarget,
                        allowFallbackPaste: false,
                        preservingPrefixLength: preservePrefixLength
                    )
                    activeTarget.insertedLength = patchText.count
                    self.withSessionLock {
                        self.target = activeTarget
                        self.lastKnownTarget = activeTarget
                        self.waitingForInsertionTarget = false
                        self.latestInsertedPreview = patchText
                    }
                    self.publishTranscript(patchText)
                } catch {
                    self.withSessionLock {
                        self.target = nil
                    }
                    if let resolvedTarget = self.resolveAvailableTextTarget() {
                        var reboundTarget = resolvedTarget
                        try self.replaceInsertedText(
                            patchText,
                            in: reboundTarget,
                            allowFallbackPaste: false,
                            preservingPrefixLength: preservePrefixLength
                        )
                        reboundTarget.insertedLength = patchText.count
                        self.withSessionLock {
                            self.target = reboundTarget
                            self.lastKnownTarget = reboundTarget
                            self.waitingForInsertionTarget = false
                            self.latestInsertedPreview = patchText
                        }
                        self.publishTranscript(patchText)
                    } else {
                        self.withSessionLock {
                            self.waitingForInsertionTarget = true
                            self.latestInsertedPreview = patchText
                        }
                        self.publishTranscript(patchText)
                        self.schedulePendingStreamingInsertionIfNeeded()
                    }
                }
            } catch {
                if self.handleRecoverableStreamingInsertionFailure(
                    error, patchText: recoverablePatchText)
                {
                    return
                }
                self.abortSession(reason: "Streaming insert failed: \(error.localizedDescription)")
            }
        }
    }

    private func requestMicrophonePermission() async -> Bool {
        #if os(macOS)
            let status = AVCaptureDevice.authorizationStatus(for: .audio)
            if status == .authorized {
                return true
            }
        #endif

        return await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    private func requestAccessibilityPermission(promptIfNeeded: Bool) -> Bool {
        AXTextAccess.permissionState(promptIfNeeded: promptIfNeeded) == .granted
    }

    private func captureFocusedTextTarget() throws -> LockedTextTarget {
        let probeResult = AXTextAccess.probeFocusedTarget()
        switch probeResult {
        case .target:
            let snapshot = try AXTextTargetResolver().snapshotFocusedTarget()
            let lockedTarget = makeLockedTextTarget(from: snapshot)
            lastKnownTarget = lockedTarget
            return lockedTarget
        case .apiDisabled(let frontmostBundleIdentifier):
            publishStaleAccessibilityPermissionGuidance(context: "capture-focused-target.api-disabled")
            AgentSessionDebugLog.append(
                hypothesisId: "H3",
                location: "DictationRuntime.captureFocusedTextTarget",
                message: "ax_api_disabled",
                data: [
                    "frontmostBundle": frontmostBundleIdentifier ?? "nil"
                ]
            )
            throw DictationRuntimeError.accessibilityPermissionDenied
        case .noFocusedElement(let frontmostBundleIdentifier):
            AgentSessionDebugLog.append(
                hypothesisId: "H3",
                location: "DictationRuntime.captureFocusedTextTarget",
                message: "ax_focused_unavailable",
                data: [
                    "frontmostBundle": frontmostBundleIdentifier ?? "nil"
                ]
            )
            throw DictationRuntimeError.focusedElementUnavailable
        case .unsupportedTarget(let frontmostBundleIdentifier, let role, let valueSettable):
            AgentSessionDebugLog.append(
                hypothesisId: "H4",
                location: "DictationRuntime.captureFocusedTextTarget",
                message: "validate_editable_failed",
                data: [
                    "role": role ?? "nil",
                    "valueSettable": "\(valueSettable)",
                    "frontmostBundle": frontmostBundleIdentifier ?? "nil"
                ]
            )
            throw DictationRuntimeError.unsupportedTextTarget
        case .unableToReadValue(let frontmostBundleIdentifier):
            AgentSessionDebugLog.append(
                hypothesisId: "H4",
                location: "DictationRuntime.captureFocusedTextTarget",
                message: "read_value_failed",
                data: [
                    "frontmostBundle": frontmostBundleIdentifier ?? "nil"
                ]
            )
            throw DictationRuntimeError.focusedElementUnavailable
        case .probeFailed(let frontmostBundleIdentifier, let reason):
            publishStaleAccessibilityPermissionGuidance(context: "capture-focused-target.probe-failed")
            AgentSessionDebugLog.append(
                hypothesisId: "H3",
                location: "DictationRuntime.captureFocusedTextTarget",
                message: "ax_probe_failed",
                data: [
                    "frontmostBundle": frontmostBundleIdentifier ?? "nil",
                    "reason": reason.rawValue,
                ]
            )
            throw DictationRuntimeError.accessibilityPermissionDenied
        }
    }

    private func makeLockedTextTarget(from snapshot: TextTargetSnapshot) -> LockedTextTarget {
        LockedTextTarget(
            element: snapshot.element,
            insertionLocation: snapshot.insertionRange.location,
            originalSelectedLength: snapshot.insertionRange.length,
            fallbackBundleIdentifier: snapshot.fallbackBundleIdentifier,
            insertedLength: snapshot.insertionRange.length
        )
    }

    private func readSelectedRange(for element: AXUIElement, currentValueLength: Int) -> CFRange {
        var selectedRangeRef: CFTypeRef?
        let rangeResult = AXUIElementCopyAttributeValue(
            element, kAXSelectedTextRangeAttribute as CFString, &selectedRangeRef)

        if rangeResult == .success,
            let selectedRangeRef,
            CFGetTypeID(selectedRangeRef) == AXValueGetTypeID()
        {
            let axValue = selectedRangeRef as! AXValue
            var range = CFRange()
            if AXValueGetType(axValue) == .cfRange, AXValueGetValue(axValue, .cfRange, &range) {
                return CFRange(location: max(0, range.location), length: max(0, range.length))
            }
        }

        return CFRange(location: currentValueLength, length: 0)
    }

    private func captureFocusedTextTargetWithRetry(emitWaitingDiagnostics: Bool = true) async throws
        -> LockedTextTarget
    {
        var lastError: Error = DictationRuntimeError.focusedElementUnavailable

        for attempt in 0..<focusedTargetRetryCount {
            do {
                let target = try captureFocusedTextTarget()
                lastKnownTarget = target
                return target
            } catch {
                lastError = error
                if let recoveredTarget = try? recoverLastKnownTarget() {
                    lastKnownTarget = recoveredTarget
                    publishDiagnostic("Verwende zuletzt bekanntes Textziel erneut.")
                    return recoveredTarget
                }
                guard case DictationRuntimeError.focusedElementUnavailable = error,
                    attempt < focusedTargetRetryCount - 1
                else {
                    throw error
                }

                if emitWaitingDiagnostics {
                    publishDiagnostic(
                        "Warte auf fokussiertes Textfeld (\(attempt + 1)/\(focusedTargetRetryCount))..."
                    )
                }
                try? await Task.sleep(nanoseconds: focusedTargetRetryDelayNanoseconds)
            }
        }

        throw lastError
    }

    private func recoverLastKnownTarget() throws -> LockedTextTarget {
        guard let lastKnownTarget else {
            throw DictationRuntimeError.focusedElementUnavailable
        }

        return try refreshLockedTextTarget(lastKnownTarget)
    }

    private func refreshLockedTextTarget(_ target: LockedTextTarget) throws -> LockedTextTarget {
        try runOnMainThread {
            if let expectedBundleIdentifier = target.fallbackBundleIdentifier,
                NSWorkspace.shared.frontmostApplication?.bundleIdentifier
                    != expectedBundleIdentifier
            {
                throw DictationRuntimeError.focusedElementUnavailable
            }

            var isValueSettable = DarwinBoolean(false)
            let settableResult = AXUIElementIsAttributeSettable(
                target.element, kAXValueAttribute as CFString, &isValueSettable)
            guard settableResult == .success, isValueSettable.boolValue else {
                reportAccessibilityIssueIfProbeLooksStale(context: "refresh-locked-target.settable")
                throw DictationRuntimeError.unsupportedTextTarget
            }

            var valueRef: CFTypeRef?
            let readResult = AXUIElementCopyAttributeValue(
                target.element, kAXValueAttribute as CFString, &valueRef)
            guard readResult == .success else {
                reportAccessibilityIssueIfProbeLooksStale(context: "refresh-locked-target.read")
                throw DictationRuntimeError.focusedElementUnavailable
            }

            let currentValue = (valueRef as? String) ?? ""
            let range = readSelectedRange(for: target.element, currentValueLength: currentValue.count)

            return LockedTextTarget(
                element: target.element,
                insertionLocation: range.location,
                originalSelectedLength: range.length,
                fallbackBundleIdentifier: target.fallbackBundleIdentifier,
                insertedLength: max(range.length, target.insertedLength)
            )
        }
    }

    private func resolveAvailableTextTarget() -> LockedTextTarget? {
        if let target,
            let refreshed = try? refreshLockedTextTarget(target)
        {
            return refreshed
        }
        if let focused = try? captureFocusedTextTarget() {
            return focused
        }
        if let recovered = try? recoverLastKnownTarget() {
            return recovered
        }
        return nil
    }

    private func waitForAvailableTextTarget(timeoutNanoseconds: UInt64) async -> LockedTextTarget? {
        let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
        while DispatchTime.now().uptimeNanoseconds < deadline {
            if let target = resolveAvailableTextTarget() {
                return target
            }
            try? await Task.sleep(nanoseconds: pendingInsertionPollNanoseconds)
        }
        return nil
    }

    private func deliverFinalText(_ finalText: String) async -> FinalTranscriptDeliveryOutcome {
        guard let currentOptions = withSessionLock({ currentOptions }) else {
            return .failed("Fehlende Diktat-Optionen.")
        }

        if currentOptions.finalResultDeliveryMode == .clipboardOnly {
            copyTranscriptToClipboard(finalText)
            publishDiagnostic("Finales Transkript wurde in die Zwischenablage kopiert.")
            withSessionLock {
                waitingForInsertionTarget = false
            }
            return .copiedToClipboard
        }

        // Live-Abfrage: nach Freigabe in den Systemeinstellungen ohne Neustart gültig (nicht nur Session-Cache).
        if !AccessibilityTrust.isClientProcessTrusted() {
            if currentOptions.finalResultDeliveryMode == .insert || currentOptions.simulateKeypresses {
                publishStaleAccessibilityPermissionGuidance(context: "deliver-final-text.permission-check")
            }
            if currentOptions.clipboardFallbackWhenNoTarget {
                copyTranscriptToClipboard(finalText)
                publishDiagnostic(
                    "Bedienungshilfen fehlen. Das finale Transkript wurde in die Zwischenablage kopiert und in der History gespeichert."
                )
                return .copiedToClipboard
            }

            publishDiagnostic(
                "Bedienungshilfen fehlen. Das finale Transkript bleibt in der History verfügbar.")
            return .historyOnlyNoTarget
        }

        if let activeStreamingTarget = target {
            do {
                let metrics = try insertFinalText(
                    finalText,
                    into: activeStreamingTarget,
                    options: currentOptions,
                    allowFallbackPaste: true
                )
                publishFinalDeliveryMetrics(metrics)
                withSessionLock {
                    waitingForInsertionTarget = false
                }
                return .inserted
            } catch {
                publishDiagnostic(
                    "Vorhandenes Live-Textziel konnte nicht aktualisiert werden. Versuche das aktuelle Fokusziel erneut."
                )
            }
        }

        if let resolvedTarget = resolveAvailableTextTarget() {
            do {
                let metrics = try insertFinalText(
                    finalText,
                    into: resolvedTarget,
                    options: currentOptions,
                    allowFallbackPaste: true
                )
                publishFinalDeliveryMetrics(metrics)
                withSessionLock {
                    waitingForInsertionTarget = false
                }
                return .inserted
            } catch {
                return .failed(error.localizedDescription)
            }
        }

        withSessionLock {
            waitingForInsertionTarget = true
        }
        publishDiagnostic(
            "Kein Textfeld aktiv. Warte bis zu 5 Sekunden auf ein Ziel für das finale Transkript.")

        if let delayedTarget = await waitForAvailableTextTarget(
            timeoutNanoseconds: pendingInsertionTimeoutNanoseconds)
        {
            do {
                let metrics = try insertFinalText(
                    finalText,
                    into: delayedTarget,
                    options: currentOptions,
                    allowFallbackPaste: true
                )
                publishFinalDeliveryMetrics(metrics)
                withSessionLock {
                    waitingForInsertionTarget = false
                }
                publishDiagnostic("Textziel erkannt. Finales Transkript wurde eingefügt.")
                return .inserted
            } catch {
                withSessionLock {
                    waitingForInsertionTarget = false
                }
                return .failed(error.localizedDescription)
            }
        }

        withSessionLock {
            waitingForInsertionTarget = false
        }
        if currentOptions.clipboardFallbackWhenNoTarget {
            copyTranscriptToClipboard(finalText)
            publishDiagnostic(
                "Kein Textfeld gewählt. Das finale Transkript wurde in die Zwischenablage kopiert und in der History gespeichert."
            )
            return .copiedToClipboard
        }

        publishDiagnostic(
            "Kein Textfeld gewählt. Das finale Transkript bleibt in der History verfügbar.")
        return .historyOnlyNoTarget
    }

    private func publishFinalDeliveryMetrics(_ metrics: FinalInsertionMetrics) {
        publishDebug(
            "dictation.final_delivery path=\(metrics.path) clipboardRestored=\(metrics.clipboardRestored) autoSent=\(metrics.autoSent)"
        )
    }

    private func schedulePendingStreamingInsertionIfNeeded() {
        let shouldSchedule = withSessionLock { () -> Bool in
            guard pendingStreamingInsertionTask == nil, runningMode == .streaming else {
                return false
            }
            return true
        }
        guard shouldSchedule else { return }

        let task = Task { [weak self] in
            defer {
                self?.withSessionLock {
                    self?.pendingStreamingInsertionTask = nil
                }
            }

            while let self {
                let loopSnapshot = self.withSessionLock {
                    (
                        isRunning: self.isRunning,
                        waitingForInsertionTarget: self.waitingForInsertionTarget,
                        runningMode: self.runningMode
                    )
                }
                guard loopSnapshot.isRunning,
                    loopSnapshot.waitingForInsertionTarget,
                    loopSnapshot.runningMode == .streaming
                else {
                    break
                }
                try? await Task.sleep(nanoseconds: pendingInsertionPollNanoseconds)

                self.insertionQueue.async { [weak self] in
                    guard let self else { return }
                    let insertionSnapshot = self.withSessionLock {
                        (
                            isRunning: self.isRunning,
                            waitingForInsertionTarget: self.waitingForInsertionTarget,
                            latestInsertedPreview: self.latestInsertedPreview
                        )
                    }
                    guard insertionSnapshot.isRunning, insertionSnapshot.waitingForInsertionTarget
                    else { return }
                    guard !insertionSnapshot.latestInsertedPreview.isEmpty else { return }
                    guard let resolvedTarget = self.resolveAvailableTextTarget() else { return }

                    do {
                        var activeTarget = resolvedTarget
                        // Wie `deliverFinalText`: Cmd+V-Fallback für Ziele, die kein zuverlässiges AX-Set liefern
                        try self.replaceInsertedText(
                            insertionSnapshot.latestInsertedPreview, in: activeTarget,
                            allowFallbackPaste: true)
                        activeTarget.insertedLength = insertionSnapshot.latestInsertedPreview.count
                        self.withSessionLock {
                            self.target = activeTarget
                            self.lastKnownTarget = activeTarget
                            self.waitingForInsertionTarget = false
                        }
                        self.publishDiagnostic(
                            "Textziel erkannt. Der aktuelle Streaming-Text wird jetzt eingefügt.")
                    } catch {
                        // Keep waiting; the target may have changed again.
                    }
                }
            }
        }
        withSessionLock {
            pendingStreamingInsertionTask = task
        }
    }

    private func startAudioCapture() throws {
        let input = audioEngine.inputNode
        let inputFormat = input.inputFormat(forBus: 0)

        guard
            let targetFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false
            )
        else {
            throw DictationRuntimeError.invalidAudioPipeline
        }

        converter = AVAudioConverter(from: inputFormat, to: targetFormat)
        guard converter != nil else {
            throw DictationRuntimeError.invalidAudioPipeline
        }

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            self?.processQueue.async {
                self?.handleAudioBuffer(
                    buffer, inputFormat: inputFormat, targetFormat: targetFormat)
            }
        }

        audioEngine.prepare()
        try audioEngine.start()
        publishDebug(
            "audio.capture.started inputRate=\(Int(inputFormat.sampleRate)) targetRate=\(Int(targetFormat.sampleRate))"
        )
    }

    private func stopAudioCapture() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        publishDebug("audio.capture.stopped")
    }

    private func handleAudioBuffer(
        _ buffer: AVAudioPCMBuffer, inputFormat: AVAudioFormat, targetFormat: AVAudioFormat
    ) {
        let isCurrentlyRunning = withSessionLock { isRunning }
        guard isCurrentlyRunning else { return }
        guard let converter else { return }

        let capacity =
            AVAudioFrameCount(
                (Double(buffer.frameLength) * targetFormat.sampleRate) / inputFormat.sampleRate)
            + 64
        guard let converted = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity)
        else {
            return
        }

        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        let status = converter.convert(to: converted, error: &error, withInputFrom: inputBlock)
        guard status != .error, error == nil else {
            return
        }

        guard let channelData = converted.floatChannelData?.pointee else {
            return
        }

        let frameCount = Int(converted.frameLength)
        updateSpeechActivityState(channelData: channelData, frameCount: frameCount)
        let audioSamples = Array(UnsafeBufferPointer(start: channelData, count: frameCount))
        let audioConfiguration = withSessionLock {
            currentOptions?.audioProcessing ?? AudioProcessingConfiguration()
        }
        guard
            let processed = audioPreprocessor.process(
                audioSamples, configuration: audioConfiguration)
        else {
            return
        }
        guard !processed.wasSilenceSuppressed else {
            return
        }
        do {
            try whisperEngine.pushAudioPCM16kMono(
                processed.samples, frameCount: processed.samples.count)
        } catch {
            abortSession(reason: "Audio push failed: \(error.localizedDescription)")
        }
    }

    private func updateSpeechActivityState(channelData: UnsafePointer<Float>, frameCount: Int) {
        guard frameCount > 0 else { return }

        var sumSquares: Float = 0
        for index in 0..<frameCount {
            let sample = channelData[index]
            sumSquares += sample * sample
        }

        let rms = sqrt(sumSquares / Float(frameCount))
        withSessionLock {
            maxObservedRMS = max(maxObservedRMS, rms)

            if rms >= speechRMSActivationThreshold {
                speechChunkStreak += 1
                if speechChunkStreak >= speechActivationChunkCount {
                    speechActivityDetected = true
                }
            } else if rms < speechRMSReleaseThreshold {
                speechChunkStreak = max(0, speechChunkStreak - 1)
            }
        }
    }

    private func handleRecoverableStreamingInsertionFailure(_ error: Error, patchText: String)
        -> Bool
    {
        guard isRecoverableStreamingInsertionError(error) else {
            return false
        }

        withSessionLock {
            target = nil
            waitingForInsertionTarget = true
            latestInsertedPreview = patchText
        }
        publishTranscript(patchText)
        schedulePendingStreamingInsertionIfNeeded()
        emitRecoverableInsertionDiagnosticIfNeeded(error)
        return true
    }

    private func isRecoverableStreamingInsertionError(_ error: Error) -> Bool {
        guard let runtimeError = error as? DictationRuntimeError else {
            return false
        }

        switch runtimeError {
        case .focusedElementUnavailable, .unsupportedTextTarget, .unsafePasteFallback:
            return true
        default:
            return false
        }
    }

    private func emitRecoverableInsertionDiagnosticIfNeeded(_ error: Error) {
        let now = Date()
        if let lastRecoverableInsertDiagnosticAt,
            now.timeIntervalSince(lastRecoverableInsertDiagnosticAt) < 1.5
        {
            return
        }
        lastRecoverableInsertDiagnosticAt = now
        publishDiagnostic(
            "Streaming wartet auf ein geeignetes Textfeld. Der bisherige Text bleibt erhalten.")
    }

    private func shouldDiscardTranscript(_ text: String) -> Bool {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return true }

        let lowered = normalized.lowercased()
        let normalizedToken = lowered.replacingOccurrences(
            of: "[^a-zA-ZäöüÄÖÜß]", with: "", options: .regularExpression)
        let suspiciousTokens: Set<String> = ["musik", "music", "you", "thanks"]
        let placeholderTokens: Set<String> = [
            "blank audio",
            "blankaudio",
            "blank-audio",
            "no audio",
            "noaudio",
            "no speech",
            "nospeech",
            "silence",
            "stille",
        ]

        if placeholderTokens.contains(lowered) || placeholderTokens.contains(normalizedToken) {
            return true
        }

        let speechSnapshot = withSessionLock {
            (speechActivityDetected: speechActivityDetected, maxObservedRMS: maxObservedRMS)
        }
        if !speechSnapshot.speechActivityDetected
            || speechSnapshot.maxObservedRMS < speechRMSActivationThreshold
        {
            if normalized.count <= 24 {
                return true
            }
            if suspiciousTokens.contains(normalizedToken) {
                return true
            }
        }

        return false
    }

    private func sanitizeTranscriptArtifacts(in text: String, stage: AIProcessingStage) -> String {
        guard !text.isEmpty else { return "" }

        var cleaned = text
        let artifactPatterns = [
            #"\((?:music|musik|silence|stille|noise|rauschen|background noise|husten|cough|laughing|laughter|applause|beep)\)"#,
            #"\[(?:music|musik|silence|stille|noise|rauschen|background noise|husten|cough|laughing|laughter|applause|beep)\]"#,
            #"\*(?:music|musik|noise|rauschen|cough|husten|laughing|laughter)\*"#,
        ]

        for pattern in artifactPatterns {
            cleaned = cleaned.replacingOccurrences(
                of: pattern,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
        }

        cleaned = cleaned.replacingOccurrences(
            of: #"\s{2,}"#, with: " ", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(
            of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        let lowered = cleaned.lowercased()
        let standaloneArtifacts: Set<String> = [
            "music", "musik", "silence", "stille", "background noise", "noise", "rauschen",
            "cough", "husten", "laughing", "laughter", "applause",
        ]

        if standaloneArtifacts.contains(lowered) {
            return ""
        }

        if stage == .live,
            cleaned.count <= 24,
            standaloneArtifacts.contains(
                lowered.replacingOccurrences(
                    of: "[^a-zA-ZäöüÄÖÜß ]", with: "", options: .regularExpression
                ).trimmingCharacters(in: .whitespacesAndNewlines))
        {
            return ""
        }

        return cleaned
    }

    private func replaceInsertedText(
        _ text: String,
        in lockedTarget: LockedTextTarget,
        allowFallbackPaste: Bool,
        preservingPrefixLength: Int = 0
    ) throws -> (path: String, clipboardRestored: Bool) {
        try runOnMainThread {
            var valueRef: CFTypeRef?
            let readResult = AXUIElementCopyAttributeValue(
                lockedTarget.element, kAXValueAttribute as CFString, &valueRef)
            if readResult != .success {
                reportAccessibilityIssueIfProbeLooksStale(context: "replace-inserted-text.read")
                if allowFallbackPaste {
                    let clipboardRestored = try pasteIntoFallbackTarget(lockedTarget, text: text)
                    var updated = lockedTarget
                    updated.insertedLength = text.count
                    target = updated
                    lastKnownTarget = updated
                    return ("clipboardPaste", clipboardRestored)
                }
                throw DictationRuntimeError.focusedElementUnavailable
            }

            let currentValue = (valueRef as? String) ?? ""
            let location = min(max(0, lockedTarget.insertionLocation), currentValue.count)
            let preservedLength = Swift.min(
                Swift.min(max(0, preservingPrefixLength), text.count),
                Swift.min(lockedTarget.insertedLength, max(0, currentValue.count - location))
            )
            let replacementStart = min(location + preservedLength, currentValue.count)
            let replacementEnd = min(
                location + max(0, lockedTarget.insertedLength), currentValue.count)

            let startIndex = currentValue.index(currentValue.startIndex, offsetBy: replacementStart)
            let endIndex = currentValue.index(currentValue.startIndex, offsetBy: replacementEnd)

            var updatedValue = currentValue
            updatedValue.replaceSubrange(
                startIndex..<endIndex, with: String(text.dropFirst(preservedLength)))

            let setResult = AXUIElementSetAttributeValue(
                lockedTarget.element, kAXValueAttribute as CFString, updatedValue as CFTypeRef)
            if setResult != .success {
                reportAccessibilityIssueIfProbeLooksStale(context: "replace-inserted-text.write")
                if allowFallbackPaste {
                    let clipboardRestored = try pasteIntoFallbackTarget(lockedTarget, text: text)
                    var updated = lockedTarget
                    updated.insertedLength = text.count
                    target = updated
                    lastKnownTarget = updated
                    return ("clipboardPaste", clipboardRestored)
                }
                throw DictationRuntimeError.focusedElementUnavailable
            }

            var updatedTarget = lockedTarget
            updatedTarget.insertedLength = text.count
            target = updatedTarget
            lastKnownTarget = updatedTarget

            let newCursor = location + text.count
            var range = CFRange(location: newCursor, length: 0)
            if let axRange = AXValueCreate(.cfRange, &range) {
                _ = AXUIElementSetAttributeValue(
                    lockedTarget.element, kAXSelectedTextRangeAttribute as CFString, axRange)
            }
            return ("axValueSet", false)
        }
    }

    private func streamingPreservedPrefixLength(
        previousText: String, newText: String, maximumMutableCharacterCount: Int
    ) -> Int {
        guard !previousText.isEmpty, !newText.isEmpty else { return 0 }

        let commonPrefixLength = previousText.commonPrefixLength(with: newText)
        let hardFloor = max(0, previousText.count - max(0, maximumMutableCharacterCount))
        return min(newText.count, max(commonPrefixLength, hardFloor))
    }

    private func pasteIntoFallbackTarget(_ target: LockedTextTarget, text: String) throws -> Bool {
        try pasteIntoFallbackTarget(
            target,
            text: text,
            restoreClipboard: withSessionLock { currentOptions?.restoreClipboardAfterPaste ?? true }
        )
    }

    private func pasteIntoFallbackTarget(
        _ target: LockedTextTarget, text: String, restoreClipboard: Bool
    ) throws -> Bool {
        if let expectedBundleIdentifier = target.fallbackBundleIdentifier {
            let frontmostBundleIdentifier = NSWorkspace.shared.frontmostApplication?
                .bundleIdentifier
            guard frontmostBundleIdentifier == expectedBundleIdentifier else {
                throw DictationRuntimeError.unsafePasteFallback
            }
        }

        let pasteboard = NSPasteboard.general
        let previousSnapshot = PasteboardSnapshot.capture(from: pasteboard)

        defer {
            if restoreClipboard {
                usleep(50_000)
                previousSnapshot.restore(to: pasteboard)
            }
        }

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        guard let source = CGEventSource(stateID: .combinedSessionState) else {
            throw DictationRuntimeError.focusedElementUnavailable
        }

        let keyV: CGKeyCode = 9
        let down = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: true)
        down?.flags = .maskCommand
        let up = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: false)
        up?.flags = .maskCommand

        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
        return restoreClipboard
    }

    private func insertFinalText(
        _ text: String,
        into lockedTarget: LockedTextTarget,
        options: DictationStartOptions,
        allowFallbackPaste: Bool
    ) throws -> FinalInsertionMetrics {
        let insertion: (path: String, clipboardRestored: Bool)
        if options.simulateKeypresses {
            do {
                try simulateKeyboardInsertion(text, into: lockedTarget)
                insertion = ("simulatedKeypresses", false)
            } catch {
                if allowFallbackPaste {
                    let clipboardRestored = try pasteIntoFallbackTarget(
                        lockedTarget,
                        text: text,
                        restoreClipboard: options.restoreClipboardAfterPaste
                    )
                    insertion = ("clipboardPaste", clipboardRestored)
                } else {
                    throw error
                }
            }
        } else {
            insertion = try replaceInsertedText(
                text,
                in: lockedTarget,
                allowFallbackPaste: allowFallbackPaste
            )
        }

        var autoSent = false
        if options.autoSendAfterPaste {
            try sendReturnKey()
            autoSent = true
        }
        return FinalInsertionMetrics(
            path: insertion.path,
            clipboardRestored: insertion.clipboardRestored,
            autoSent: autoSent
        )
    }

    private func simulateKeyboardInsertion(_ text: String, into target: LockedTextTarget) throws {
        if let expectedBundleIdentifier = target.fallbackBundleIdentifier {
            let frontmostBundleIdentifier = NSWorkspace.shared.frontmostApplication?
                .bundleIdentifier
            guard frontmostBundleIdentifier == expectedBundleIdentifier else {
                throw DictationRuntimeError.unsafePasteFallback
            }
        }

        guard
            let source = CGEventSource(stateID: .hidSystemState)
                ?? CGEventSource(stateID: .combinedSessionState)
        else {
            throw DictationRuntimeError.focusedElementUnavailable
        }

        let unicodeValues = Array(text.utf16)
        guard !unicodeValues.isEmpty else { return }

        let chunkSize = 48
        for chunkStart in stride(from: 0, to: unicodeValues.count, by: chunkSize) {
            let chunkEnd = min(chunkStart + chunkSize, unicodeValues.count)
            let chunk = Array(unicodeValues[chunkStart..<chunkEnd])

            guard let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
            else {
                throw DictationRuntimeError.focusedElementUnavailable
            }
            chunk.withUnsafeBufferPointer { buffer in
                if let baseAddress = buffer.baseAddress {
                    down.keyboardSetUnicodeString(
                        stringLength: buffer.count, unicodeString: baseAddress)
                }
            }
            down.post(tap: .cghidEventTap)

            guard let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
            else {
                throw DictationRuntimeError.focusedElementUnavailable
            }
            up.post(tap: .cghidEventTap)
        }
    }

    private func sendReturnKey() throws {
        guard
            let source = CGEventSource(stateID: .hidSystemState)
                ?? CGEventSource(stateID: .combinedSessionState)
        else {
            throw DictationRuntimeError.focusedElementUnavailable
        }

        let returnKey: CGKeyCode = CGKeyCode(kVK_Return)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: returnKey, keyDown: true),
            let up = CGEvent(keyboardEventSource: source, virtualKey: returnKey, keyDown: false)
        else {
            throw DictationRuntimeError.focusedElementUnavailable
        }

        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    private func copyTranscriptToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func configureEngine(for options: DictationStartOptions, runtimeMode: DictationMode)
        throws
    {
        let runtime = try BundledWhisperRuntimeInstaller.installBundledRuntime(
            bundle: .main, appName: "WisprLocal")
        let preset = selectEnginePreset(options: options, runtimeMode: runtimeMode)
        let modelDescriptor = selectedVoiceModelDescriptor(for: options, runtime: runtime)
        let modelFile = modelDescriptor.localFileName ?? runtime.defaultModelFileName
        let modelURL = runtime.modelsDirectoryURL.appendingPathComponent(modelFile)

        let latencyProfile = selectLatencyProfile(
            options: options, preset: preset, runtimeMode: runtimeMode)
        let translationMode: ASRTranslationMode =
            modelDescriptor.supportsTranslationToEnglish
            ? options.translationOutput.asrTranslationMode
            : .original
        let config = ASRConfig(
            languageHint: options.language.asrHint,
            translationMode: translationMode,
            providerID: modelDescriptor.providerID,
            catalogModelID: modelDescriptor.id,
            modelID: modelFile,
            backend: .whisperCpp,
            latencyProfile: latencyProfile,
            threadCount: preset.threadCount,
            beamSize: preset.beamSize,
            chunkMilliseconds: preset.chunkMilliseconds
        )

        if loadedModelPath == modelURL, loadedConfig == config {
            publishDebug("engine.configure.reuse model=\(modelURL.lastPathComponent)")
            return
        }

        try whisperEngine.loadModel(at: modelURL, config: config)
        loadedModelPath = modelURL
        loadedConfig = config
        publishDebug(
            "engine.configure.loaded model=\(modelURL.lastPathComponent) latency=\(config.latencyProfile.rawValue) threads=\(config.threadCount) beam=\(config.beamSize) chunkMs=\(config.chunkMilliseconds)"
        )
    }

    private func selectEnginePreset(
        options: DictationStartOptions, runtimeMode: DictationMode
    ) -> EnginePreset {
        let profile = capabilityProfiler.profile()
        let override: QualityOverride
        switch options.performance {
        case .auto:
            override = .auto
        case .fast:
            override = .fast
        case .balanced:
            override = .balanced
        case .accurate:
            override = .accurate
        }

        if runtimeMode == .streaming {
            return capabilityProfiler.streamingPreset(for: profile, override: override)
        }
        return capabilityProfiler.qualityPreset(for: profile, override: override)
    }

    private func selectLatencyProfile(
        options: DictationStartOptions, preset: EnginePreset, runtimeMode: DictationMode
    ) -> LatencyProfile {
        guard runtimeMode == .streaming else {
            return .quality
        }

        switch options.performance {
        case .fast:
            return .streaming
        case .balanced, .accurate:
            return .quality
        case .auto:
            return preset.beamSize > 1 ? .quality : .streaming
        }
    }

    private func makeStreamingCommitStabilizer(
        for options: DictationStartOptions, runtimeMode: DictationMode
    ) -> StreamingCommitStabilizer {
        let rewriteScope: StreamingRewriteScope
        switch options.liveRewriteScope {
        case .currentSentence:
            rewriteScope = .currentSentence
        case .currentSentenceAndPreviousSentence:
            rewriteScope = .recentContext
        case .currentSentenceAndTwoPreviousSentences:
            rewriteScope = .wideContext
        case .currentParagraph:
            rewriteScope = .currentParagraph
        }

        switch options.performance {
        case .fast:
            return StreamingCommitStabilizer(
                stabilityThreshold: 2,
                minimumCommitExtensionLength: 1,
                rewriteScope: rewriteScope
            )
        case .balanced:
            return StreamingCommitStabilizer(
                stabilityThreshold: 3,
                minimumCommitExtensionLength: 4,
                rewriteScope: rewriteScope
            )
        case .accurate:
            return StreamingCommitStabilizer(
                stabilityThreshold: 3,
                minimumCommitExtensionLength: 6,
                rewriteScope: rewriteScope
            )
        case .auto:
            let preset = selectEnginePreset(options: options, runtimeMode: runtimeMode)
            if preset.beamSize > 1 {
                return StreamingCommitStabilizer(
                    stabilityThreshold: 3,
                    minimumCommitExtensionLength: 4,
                    rewriteScope: rewriteScope
                )
            }
            return StreamingCommitStabilizer(
                stabilityThreshold: 2,
                minimumCommitExtensionLength: 2,
                rewriteScope: rewriteScope
            )
        }
    }

    private func selectedVoiceModelDescriptor(
        for options: DictationStartOptions,
        runtime: InstalledWhisperRuntime
    ) -> VoiceModelDescriptor {
        let includeParakeet = false
        let availableModelFiles = Set(runtime.availableModelFileNames)
        let catalogModels = LocalVoiceModelCatalog.availableModels(includeParakeet: includeParakeet)
        let fallbackDescriptor =
            LocalVoiceModelCatalog.model(
                id: LocalVoiceModelCatalog.defaultModelID, includeParakeet: includeParakeet)
            ?? catalogModels.first
            ?? VoiceModelDescriptor(
                id: LocalVoiceModelCatalog.defaultModelID,
                providerID: VoiceProviderID.whisperCpp.rawValue,
                displayName: "Standard",
                languageCode: nil,
                languageScope: .all,
                supportsTranslationToEnglish: true,
                speedScore: 8,
                accuracyScore: 5,
                sizeLabel: "500 MB",
                installState: .bundled,
                localFileName: runtime.defaultModelFileName,
                downloadIdentifier: "base"
            )

        let requestedDescriptor = LocalVoiceModelCatalog.model(
            id: options.selectedVoiceModelID, includeParakeet: includeParakeet)
        guard var resolvedDescriptor = requestedDescriptor else {
            return fallbackDescriptor
        }

        if resolvedDescriptor.providerID != VoiceProviderID.whisperCpp.rawValue {
            return fallbackDescriptor
        }

        if let requiredLanguageCode = resolvedDescriptor.languageCode,
            options.language != .auto,
            requiredLanguageCode != options.language.rawValue
        {
            let compatibleOverride = catalogModels.first {
                $0.providerID == resolvedDescriptor.providerID
                    && $0.id != resolvedDescriptor.id
                    && $0.languageCode == nil
                    && modelFileExists($0, availableModelFiles: availableModelFiles)
            }
            resolvedDescriptor = compatibleOverride ?? fallbackDescriptor
        }

        if modelFileExists(resolvedDescriptor, availableModelFiles: availableModelFiles) {
            return resolvedDescriptor
        }

        if modelFileExists(fallbackDescriptor, availableModelFiles: availableModelFiles) {
            return fallbackDescriptor
        }

        if let installedCatalogDescriptor = catalogModels.first(where: {
            modelFileExists($0, availableModelFiles: availableModelFiles)
        }) {
            return installedCatalogDescriptor
        }

        return fallbackDescriptor
    }

    private func modelFileExists(
        _ descriptor: VoiceModelDescriptor, availableModelFiles: Set<String>
    ) -> Bool {
        guard let localFileName = descriptor.localFileName else {
            return false
        }
        return availableModelFiles.contains(localFileName)
    }

    private func applySnippetsToFinalText(_ text: String, locale: Locale) -> String {
        guard let snippetMatcher else { return text }
        return snippetMatcher.applyToFinal(text, locale: locale)
    }

    private func normalizeText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func currentAIProcessingConfiguration() -> AIProcessingConfiguration {
        withSessionLock {
            currentOptions?.aiProcessing
                ?? AIProcessingConfiguration(enabled: false, selectedModelID: nil)
        }
    }

    private func playSoundFeedback(
        _ event: SoundFeedbackEvent, settings: SoundFeedbackConfiguration?
    ) {
        guard let settings, settings.enabled else { return }
        soundFeedbackPlayer.play(event: event, volume: settings.volume)
    }

    private func shouldRunFinalAIProcessing() -> Bool {
        withSessionLock {
            guard let currentOptions else { return false }
            return currentOptions.aiProcessing.applyToFinalResult
        }
    }

    private func processLiveTextIfNeeded(_ text: String) -> String {
        let request = AIProcessingRequest(
            text: text,
            stage: .live,
            locale: runningLocale,
            configuration: currentAIProcessingConfiguration()
        )
        let processingService = withSessionLock { aiProcessingService }

        let semaphore = DispatchSemaphore(value: 0)
        var outcome: AIProcessingOutcome = .bypassed(
            text: text, reason: "AI processing did not run.")

        Task {
            outcome = await processingService.process(request)
            semaphore.signal()
        }

        semaphore.wait()
        emitProcessingDiagnosticIfNeeded(outcome, stage: .live)
        return outcome.text
    }

    private func emitProcessingDiagnosticIfNeeded(
        _ outcome: AIProcessingOutcome, stage: AIProcessingStage
    ) {
        switch outcome {
        case .processed where stage == .final:
            if let message = outcome.diagnosticMessage {
                publishDiagnostic(message)
            }
        case .failedFallback:
            if let message = outcome.diagnosticMessage {
                publishDiagnostic(message)
            }
        default:
            break
        }
    }

    private func resolvedLanguageCode(from final: FinalTranscript) -> String {
        let detectedLanguage = final.language?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if let detectedLanguage, !detectedLanguage.isEmpty {
            return detectedLanguage
        }

        return withSessionLock {
            currentOptions?.language.rawValue ?? "auto"
        }
    }

    private func locale(for languageCode: String) -> Locale? {
        switch languageCode {
        case "de":
            return Locale(identifier: "de_DE")
        case "en":
            return Locale(identifier: "en_US")
        default:
            return nil
        }
    }

    private func cleanupSession() {
        publishDebug("dictation.cleanup.begin")
        let tasksToCancel = withSessionLock { () -> (Task<Void, Never>?, Task<Void, Never>?) in
            let startTask = self.startTask
            let pendingTask = self.pendingStreamingInsertionTask
            self.startTask = nil
            self.isStarting = false
            self.isRunning = false
            self.runningMode = nil
            self.currentOptions = nil
            self.target = nil
            self.latestInsertedPreview = ""
            self.snippetMatcher = nil
            self.waitingForInsertionTarget = false
            self.pendingStreamingInsertionTask = nil
            self.speechActivityDetected = false
            self.speechChunkStreak = 0
            self.maxObservedRMS = 0
            self.lastRecoverableInsertDiagnosticAt = nil
            self.accessibilityPermissionGranted = false
            return (startTask, pendingTask)
        }
        tasksToCancel.0?.cancel()
        tasksToCancel.1?.cancel()
        stopAudioCapture()
        audioEngine.reset()
        converter = nil
        audioPreprocessor.reset()
        whisperEngine.resetStreaming()
        stableCommitter.reset()
        publishSessionActivity(false)
        scheduleRuntimeUnloadIfNeeded()
        publishDebug("dictation.cleanup.end")
    }

    private func scheduleRuntimeUnloadIfNeeded() {
        guard withSessionLock({ runtimePrepared }) else {
            cancelRuntimeUnloadTask()
            return
        }

        let timeout = withSessionLock { voiceModelActiveDuration.seconds }
        guard let timeout else {
            cancelRuntimeUnloadTask()
            return
        }

        cancelRuntimeUnloadTask()
        let task = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            guard let self else { return }
            guard !Task.isCancelled else { return }
            self.unloadPreparedRuntimeIfNeeded()
        }

        withSessionLock {
            runtimeUnloadTask = task
        }
        publishDebug("runtime.unload.scheduled after=\(Int(timeout))s")
    }

    private func cancelRuntimeUnloadTask() {
        let task = withSessionLock {
            let task = runtimeUnloadTask
            runtimeUnloadTask = nil
            return task
        }
        task?.cancel()
    }

    private func unloadPreparedRuntimeIfNeeded() {
        let shouldUnload = withSessionLock {
            guard runtimePrepared else { return false }
            runtimePrepared = false
            loadedModelPath = nil
            loadedConfig = nil
            return true
        }

        guard shouldUnload else { return }

        whisperEngine.resetStreaming()
        publishDiagnostic(
            "ASR runtime war im Leerlauf zu lange inaktiv und wird beim nächsten Start neu geladen."
        )
        publishDebug("runtime.unload.completed")
    }

    private func abortSession(reason: String) {
        let feedback = withSessionLock { currentOptions?.soundFeedback }
        cleanupSession()
        publishStatus("Error")
        publishDiagnostic(reason)
        playSoundFeedback(.failed, settings: feedback)
    }

    private func publishStatus(_ value: String) {
        DispatchQueue.main.async { [weak self] in
            self?.onStatus?(value)
        }
    }

    private func publishDiagnostic(_ value: String) {
        DispatchQueue.main.async { [weak self] in
            self?.onDiagnostic?(value)
        }
    }

    private func publishDebug(_ value: String) {
        DispatchQueue.main.async { [weak self] in
            self?.onDebugEvent?(value)
        }
    }

    private func publishTranscript(_ value: String) {
        DispatchQueue.main.async { [weak self] in
            self?.onTranscript?(value)
        }
    }

    private func publishFinalTranscript(_ value: FinalTranscriptEvent) {
        DispatchQueue.main.async { [weak self] in
            self?.onFinalTranscript?(value)
        }
    }

    private func publishSessionActivity(_ isActive: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.onSessionActivityChanged?(isActive)
        }
    }
}

extension String {
    fileprivate func commonPrefixLength(with other: String) -> Int {
        var lhsIndex = startIndex
        let rhs = other
        var rhsIndex = rhs.startIndex
        var length = 0

        while lhsIndex < endIndex,
            rhsIndex < rhs.endIndex,
            self[lhsIndex] == rhs[rhsIndex]
        {
            length += 1
            formIndex(after: &lhsIndex)
            rhs.formIndex(after: &rhsIndex)
        }

        return length
    }
}
