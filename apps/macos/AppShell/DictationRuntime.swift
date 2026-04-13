import ASRCore
import AIProcessingCore
import AVFoundation
import AppKit
import ApplicationServices
import CapabilityCore
import Foundation
import SessionCore
import SnippetCore

enum DictationMode {
    case finalize
    case streaming
}

enum DictationLanguage: String, CaseIterable, Identifiable {
    case german = "de"
    case english = "en"
    case auto = "auto"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .german:
            return "Deutsch"
        case .english:
            return "Englisch"
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
            return "Default"
        case ("en", .english):
            return "English"
        case (_, .original):
            return "Standard"
        case (_, .english):
            return "Englisch"
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
            return "Paste-Fallback wurde blockiert, weil der Fokus nicht mehr auf der ursprünglichen Ziel-App liegt."
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

final class DictationRuntime: @unchecked Sendable {
    var onStatus: ((String) -> Void)?
    var onDiagnostic: ((String) -> Void)?
    var onTranscript: ((String) -> Void)?
    var onFinalTranscript: ((FinalTranscriptEvent) -> Void)?
    var onSessionActivityChanged: ((Bool) -> Void)?

    private let whisperEngine = WhisperCppEngine()
    private let processQueue = DispatchQueue(label: "wispr.dictation.process", qos: .userInitiated)
    private let insertionQueue = DispatchQueue(label: "wispr.dictation.insert", qos: .userInitiated)
    private let capabilityProfiler = CapabilityProfiler()
    private let aiProcessingService = AIProcessingService()
    private let sessionLock = NSLock()

    private let audioEngine = AVAudioEngine()
    private var converter: AVAudioConverter?
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
    private var lastKnownTarget: LockedTextTarget?
    private var waitingForInsertionTarget = false
    private var pendingStreamingInsertionTask: Task<Void, Never>?
    private var speechActivityDetected = false
    private var speechChunkStreak = 0
    private var maxObservedRMS: Float = 0
    private var lastRecoverableInsertDiagnosticAt: Date?
    private var accessibilityPermissionGranted = false
    private var pausedMediaAppIdentifiers: Set<String> = []
    private let focusedTargetRetryCount = 8
    private let focusedTargetRetryDelayNanoseconds: UInt64 = 150_000_000
    private let pendingInsertionTimeoutNanoseconds: UInt64 = 5_000_000_000
    private let pendingInsertionPollNanoseconds: UInt64 = 150_000_000
    private let speechRMSActivationThreshold: Float = 0.008
    private let speechRMSReleaseThreshold: Float = 0.004
    private let speechActivationChunkCount = 3

    private func withSessionLock<T>(_ work: () throws -> T) rethrows -> T {
        sessionLock.lock()
        defer { sessionLock.unlock() }
        return try work()
    }

    private func runOnMainThread<T>(_ work: () throws -> T) throws -> T {
        if Thread.isMainThread {
            return try work()
        }

        return try DispatchQueue.main.sync(execute: work)
    }

    func prepareRuntime() {
        guard !runtimePrepared else { return }

        do {
            let runtime = try BundledWhisperRuntimeInstaller.installBundledRuntime(bundle: .main, appName: "WisprLocal")
            let bootstrapModel = runtime.modelsDirectoryURL.appendingPathComponent(runtime.defaultModelFileName)
            let bootstrapConfig = ASRConfig(
                languageHint: "de",
                translationMode: .original,
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

            whisperEngine.onPartial = { [weak self] partial in
                self?.handlePartialText(partial.text)
            }
        } catch {
            publishStatus("Error")
            publishDiagnostic("ASR init failed: \(error.localizedDescription)")
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

    func start(options: DictationStartOptions) {
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
            guard micGranted else {
                publishStatus("Error")
                publishDiagnostic(DictationRuntimeError.microphonePermissionDenied.localizedDescription)
                return
            }

            do {
                let requiresDirectInsertion = options.mode == .streaming || options.finalResultDeliveryMode == .insert
                let accessibilityGranted = requestAccessibilityPermission(promptIfNeeded: requiresDirectInsertion)
                accessibilityPermissionGranted = accessibilityGranted
                if options.muteMusicWhileDictating {
                    pauseMediaPlaybackBestEffort()
                }
                try configureEngine(for: options)

                let effectiveMode: DictationMode = accessibilityGranted ? options.mode : .finalize

                if accessibilityGranted {
                    let lockedTarget = try? await captureFocusedTextTargetWithRetry(emitWaitingDiagnostics: false)
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
                        publishDiagnostic("Kein Textfeld aktiv. Das Diktat startet trotzdem und wartet auf ein fokussiertes Ziel.")
                        schedulePendingStreamingInsertionIfNeeded()
                    }
                } else {
                    withSessionLock {
                        self.target = nil
                        self.waitingForInsertionTarget = false
                    }
                    if requiresDirectInsertion {
                        publishDiagnostic("Bedienungshilfen fehlen. Das Diktat läuft im eingeschränkten Modus ohne direktes Einfügen.")
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
                    self.stableCommitter = self.makeStreamingCommitStabilizer(for: options)
                    self.snippetMatcher = DefaultSnippetMatcher(rules: options.snippetRules)
                }

                try whisperEngine.startStreaming()
                try startAudioCapture()

                withSessionLock {
                    self.isRunning = true
                }
                publishSessionActivity(true)
                publishStatus("Recording")
                let modeText = effectiveMode == .streaming ? "Streaming Insert" : "Finalize Insert"
                let translationText = options.translationOutput == .english ? ", translated to English" : ""
                publishDiagnostic("Recording (\(modeText), \(options.language.displayName)\(translationText))")
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
            stopAudioCapture()
            let final = try await whisperEngine.stopStreaming()
            let detectedLanguageCode = resolvedLanguageCode(from: final)
            let effectiveLocale = locale(for: detectedLanguageCode) ?? runningLocale
            let normalized = normalizeText(final.text)
            let snippetAdjustedText = applySnippetsToFinalText(normalized, locale: effectiveLocale)
            let finalProcessingOutcome = await aiProcessingService.process(
                AIProcessingRequest(
                    text: snippetAdjustedText,
                    stage: .final,
                    locale: effectiveLocale,
                    configuration: currentAIProcessingConfiguration(),
                    appContextText: withSessionLock { currentOptions?.appContextText },
                    dictionaryTerms: withSessionLock { currentOptions?.dictionaryTerms ?? [] }
                )
            )
            let finalText = finalProcessingOutcome.text

            if shouldDiscardTranscript(finalText) {
                publishTranscript("")
                publishStatus("Idle")
                publishDiagnostic("Kein verwertbares Sprachsignal erkannt. Das Transkript wurde verworfen.")
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
        } catch {
            abortSession(reason: "Stop failed: \(error.localizedDescription)")
            return
        }

        cleanupSession()
    }

    func openMicrophoneSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") else { return }
        NSWorkspace.shared.open(url)
    }

    func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    private func handlePartialText(_ text: String) {
        let snapshot = withSessionLock {
            (
                isRunning: isRunning,
                runningMode: runningMode,
                speechActivityDetected: speechActivityDetected
            )
        }
        guard snapshot.isRunning, snapshot.runningMode == .streaming else { return }
        guard snapshot.speechActivityDetected else { return }

        let normalized = normalizeText(text)
        guard !normalized.isEmpty else { return }

        insertionQueue.async { [weak self] in
            guard let self else { return }
            var target = self.target
            var recoverablePatchText = normalized

            do {
                let stable = self.stableCommitter.ingestPartial(normalized)
                let committedWithSnippets = self.applySnippetsToFinalText(stable.committedPrefix, locale: self.runningLocale)
                let mergedPatchText = self.normalizeText(committedWithSnippets + stable.tail)
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
                let preservePrefixLength = self.target == nil
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
                if self.handleRecoverableStreamingInsertionFailure(error, patchText: recoverablePatchText) {
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
                continuation.resume(returning: granted)
            }
        }
    }

    private func requestAccessibilityPermission(promptIfNeeded: Bool) -> Bool {
        if AXIsProcessTrusted() {
            return true
        }
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: promptIfNeeded] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    private func readSelectedRange(from element: AXUIElement, currentValueLength: Int) -> CFRange {
        var selectedRangeRef: CFTypeRef?
        let rangeResult = AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &selectedRangeRef)

        if rangeResult == .success,
           let selectedRangeRef,
           CFGetTypeID(selectedRangeRef) == AXValueGetTypeID() {
            let axValue = selectedRangeRef as! AXValue
            var range = CFRange()
            if AXValueGetType(axValue) == .cfRange, AXValueGetValue(axValue, .cfRange, &range) {
                return CFRange(location: max(0, range.location), length: max(0, range.length))
            }
        }

        return CFRange(location: currentValueLength, length: 0)
    }

    private func captureFocusedTextTarget() throws -> LockedTextTarget {
        try runOnMainThread {
            let systemWide = AXUIElementCreateSystemWide()
            var focused: CFTypeRef?
            let focusedResult = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focused)

            guard focusedResult == .success, let focusedElement = focused else {
                throw DictationRuntimeError.focusedElementUnavailable
            }

            let element = focusedElement as! AXUIElement
            try validateEditableTextTarget(element)

            var valueRef: CFTypeRef?
            _ = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef)
            let value = (valueRef as? String) ?? ""
            let range = readSelectedRange(from: element, currentValueLength: value.count)

            var owningPID: pid_t = 0
            let owningPIDResult = AXUIElementGetPid(element, &owningPID)
            let app = owningPIDResult == .success ? NSRunningApplication(processIdentifier: owningPID) : NSWorkspace.shared.frontmostApplication
            return LockedTextTarget(
                element: element,
                insertionLocation: range.location,
                originalSelectedLength: range.length,
                fallbackBundleIdentifier: app?.bundleIdentifier,
                insertedLength: range.length
            )
        }
    }

    private func captureFocusedTextTargetWithRetry(emitWaitingDiagnostics: Bool = true) async throws -> LockedTextTarget {
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
                      attempt < focusedTargetRetryCount - 1 else {
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
               NSWorkspace.shared.frontmostApplication?.bundleIdentifier != expectedBundleIdentifier {
                throw DictationRuntimeError.focusedElementUnavailable
            }

            try validateEditableTextTarget(target.element)

            var valueRef: CFTypeRef?
            let readResult = AXUIElementCopyAttributeValue(target.element, kAXValueAttribute as CFString, &valueRef)
            guard readResult == .success else {
                throw DictationRuntimeError.focusedElementUnavailable
            }

            let currentValue = (valueRef as? String) ?? ""
            let range = readSelectedRange(from: target.element, currentValueLength: currentValue.count)

            return LockedTextTarget(
                element: target.element,
                insertionLocation: range.location,
                originalSelectedLength: range.length,
                fallbackBundleIdentifier: target.fallbackBundleIdentifier,
                insertedLength: max(range.length, target.insertedLength)
            )
        }
    }

    private func validateEditableTextTarget(_ element: AXUIElement) throws {
        var isValueSettable = DarwinBoolean(false)
        let settableResult = AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &isValueSettable)
        guard settableResult == .success, isValueSettable.boolValue else {
            throw DictationRuntimeError.unsupportedTextTarget
        }
    }

    private func resolveAvailableTextTarget() -> LockedTextTarget? {
        if let target,
           let refreshed = try? refreshLockedTextTarget(target) {
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

        if !accessibilityPermissionGranted {
            if currentOptions.clipboardFallbackWhenNoTarget {
                copyTranscriptToClipboard(finalText)
                publishDiagnostic("Bedienungshilfen fehlen. Das finale Transkript wurde in die Zwischenablage kopiert und in der History gespeichert.")
                return .copiedToClipboard
            }

            publishDiagnostic("Bedienungshilfen fehlen. Das finale Transkript bleibt in der History verfügbar.")
            return .historyOnlyNoTarget
        }

        if let activeStreamingTarget = target {
            do {
                try replaceInsertedText(finalText, in: activeStreamingTarget, allowFallbackPaste: true)
                withSessionLock {
                    waitingForInsertionTarget = false
                }
                return .inserted
            } catch {
                publishDiagnostic("Vorhandenes Live-Textziel konnte nicht aktualisiert werden. Versuche das aktuelle Fokusziel erneut.")
            }
        }

        if let resolvedTarget = resolveAvailableTextTarget() {
            do {
                try replaceInsertedText(finalText, in: resolvedTarget, allowFallbackPaste: true)
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
        publishDiagnostic("Kein Textfeld aktiv. Warte bis zu 5 Sekunden auf ein Ziel für das finale Transkript.")

        if let delayedTarget = await waitForAvailableTextTarget(timeoutNanoseconds: pendingInsertionTimeoutNanoseconds) {
            do {
                try replaceInsertedText(finalText, in: delayedTarget, allowFallbackPaste: true)
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
            publishDiagnostic("Kein Textfeld gewählt. Das finale Transkript wurde in die Zwischenablage kopiert und in der History gespeichert.")
            return .copiedToClipboard
        }

        publishDiagnostic("Kein Textfeld gewählt. Das finale Transkript bleibt in der History verfügbar.")
        return .historyOnlyNoTarget
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
                      loopSnapshot.runningMode == .streaming else {
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
                    guard insertionSnapshot.isRunning, insertionSnapshot.waitingForInsertionTarget else { return }
                    guard !insertionSnapshot.latestInsertedPreview.isEmpty else { return }
                    guard let resolvedTarget = self.resolveAvailableTextTarget() else { return }

                    do {
                        var activeTarget = resolvedTarget
                        try self.replaceInsertedText(insertionSnapshot.latestInsertedPreview, in: activeTarget, allowFallbackPaste: false)
                        activeTarget.insertedLength = insertionSnapshot.latestInsertedPreview.count
                        self.withSessionLock {
                            self.target = activeTarget
                            self.lastKnownTarget = activeTarget
                            self.waitingForInsertionTarget = false
                        }
                        self.publishDiagnostic("Textziel erkannt. Der aktuelle Streaming-Text wird jetzt eingefügt.")
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

        guard let targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false) else {
            throw DictationRuntimeError.invalidAudioPipeline
        }

        converter = AVAudioConverter(from: inputFormat, to: targetFormat)
        guard converter != nil else {
            throw DictationRuntimeError.invalidAudioPipeline
        }

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            self?.processQueue.async {
                self?.handleAudioBuffer(buffer, inputFormat: inputFormat, targetFormat: targetFormat)
            }
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    private func stopAudioCapture() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
    }

    private func handleAudioBuffer(_ buffer: AVAudioPCMBuffer, inputFormat: AVAudioFormat, targetFormat: AVAudioFormat) {
        let isCurrentlyRunning = withSessionLock { isRunning }
        guard isCurrentlyRunning else { return }
        guard let converter else { return }

        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * targetFormat.sampleRate) / inputFormat.sampleRate) + 64
        guard let converted = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else {
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
        do {
            try whisperEngine.pushAudioPCM16kMono(channelData, frameCount: frameCount)
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

    private func handleRecoverableStreamingInsertionFailure(_ error: Error, patchText: String) -> Bool {
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
        if let lastRecoverableInsertDiagnosticAt, now.timeIntervalSince(lastRecoverableInsertDiagnosticAt) < 1.5 {
            return
        }
        lastRecoverableInsertDiagnosticAt = now
        publishDiagnostic("Streaming wartet auf ein geeignetes Textfeld. Der bisherige Text bleibt erhalten.")
    }

    private func shouldDiscardTranscript(_ text: String) -> Bool {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return true }

        let lowered = normalized.lowercased()
        let normalizedToken = lowered.replacingOccurrences(of: "[^a-zA-ZäöüÄÖÜß]", with: "", options: .regularExpression)
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
            "stille"
        ]

        if placeholderTokens.contains(lowered) || placeholderTokens.contains(normalizedToken) {
            return true
        }

        let speechSnapshot = withSessionLock {
            (speechActivityDetected: speechActivityDetected, maxObservedRMS: maxObservedRMS)
        }
        if !speechSnapshot.speechActivityDetected || speechSnapshot.maxObservedRMS < speechRMSActivationThreshold {
            if normalized.count <= 24 {
                return true
            }
            if suspiciousTokens.contains(normalizedToken) {
                return true
            }
        }

        return false
    }

    private func replaceInsertedText(
        _ text: String,
        in lockedTarget: LockedTextTarget,
        allowFallbackPaste: Bool,
        preservingPrefixLength: Int = 0
    ) throws {
        try runOnMainThread {
            var valueRef: CFTypeRef?
            let readResult = AXUIElementCopyAttributeValue(lockedTarget.element, kAXValueAttribute as CFString, &valueRef)
            if readResult != .success {
                if allowFallbackPaste {
                    try pasteIntoFallbackTarget(lockedTarget, text: text)
                    var updated = lockedTarget
                    updated.insertedLength = text.count
                    target = updated
                    lastKnownTarget = updated
                    return
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
            let replacementEnd = min(location + max(0, lockedTarget.insertedLength), currentValue.count)

            let startIndex = currentValue.index(currentValue.startIndex, offsetBy: replacementStart)
            let endIndex = currentValue.index(currentValue.startIndex, offsetBy: replacementEnd)

            var updatedValue = currentValue
            updatedValue.replaceSubrange(startIndex..<endIndex, with: String(text.dropFirst(preservedLength)))

            let setResult = AXUIElementSetAttributeValue(lockedTarget.element, kAXValueAttribute as CFString, updatedValue as CFTypeRef)
            if setResult != .success {
                if allowFallbackPaste {
                    try pasteIntoFallbackTarget(lockedTarget, text: text)
                    var updated = lockedTarget
                    updated.insertedLength = text.count
                    target = updated
                    lastKnownTarget = updated
                    return
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
                _ = AXUIElementSetAttributeValue(lockedTarget.element, kAXSelectedTextRangeAttribute as CFString, axRange)
            }
        }
    }

    private func streamingPreservedPrefixLength(previousText: String, newText: String, maximumMutableCharacterCount: Int) -> Int {
        guard !previousText.isEmpty, !newText.isEmpty else { return 0 }

        let commonPrefixLength = previousText.commonPrefixLength(with: newText)
        let hardFloor = max(0, previousText.count - max(0, maximumMutableCharacterCount))
        return min(newText.count, max(commonPrefixLength, hardFloor))
    }

    private func pasteIntoFallbackTarget(_ target: LockedTextTarget, text: String) throws {
        if let expectedBundleIdentifier = target.fallbackBundleIdentifier {
            let frontmostBundleIdentifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            guard frontmostBundleIdentifier == expectedBundleIdentifier else {
                throw DictationRuntimeError.unsafePasteFallback
            }
        }

        let pasteboard = NSPasteboard.general
        let previousString = pasteboard.string(forType: .string)

        defer {
            usleep(50_000)
            pasteboard.clearContents()
            if let previousString {
                pasteboard.setString(previousString, forType: .string)
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
    }

    private func copyTranscriptToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func configureEngine(for options: DictationStartOptions) throws {
        let runtime = try BundledWhisperRuntimeInstaller.installBundledRuntime(bundle: .main, appName: "WisprLocal")
        let preset = selectEnginePreset(options: options)
        let modelFile = selectModelFileName(runtime: runtime, preset: preset, options: options)
        let modelURL = runtime.modelsDirectoryURL.appendingPathComponent(modelFile)

        let latencyProfile = selectLatencyProfile(options: options, preset: preset)
        let config = ASRConfig(
            languageHint: options.language.asrHint,
            initialPrompt: options.asrInitialPrompt,
            translationMode: options.translationOutput.asrTranslationMode,
            modelID: modelFile,
            backend: .whisperCpp,
            latencyProfile: latencyProfile,
            threadCount: preset.threadCount,
            beamSize: preset.beamSize,
            chunkMilliseconds: preset.chunkMilliseconds
        )

        if loadedModelPath == modelURL, loadedConfig == config {
            return
        }

        try whisperEngine.loadModel(at: modelURL, config: config)
        loadedModelPath = modelURL
        loadedConfig = config
    }

    private func selectEnginePreset(options: DictationStartOptions) -> EnginePreset {
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

        if options.mode == .streaming {
            return capabilityProfiler.streamingPreset(for: profile, override: override)
        }
        return capabilityProfiler.qualityPreset(for: profile, override: override)
    }

    private func selectLatencyProfile(options: DictationStartOptions, preset: EnginePreset) -> LatencyProfile {
        guard options.mode == .streaming else {
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

    private func makeStreamingCommitStabilizer(for options: DictationStartOptions) -> StreamingCommitStabilizer {
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
            let preset = selectEnginePreset(options: options)
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

    private func selectModelFileName(runtime: InstalledWhisperRuntime, preset: EnginePreset, options: DictationStartOptions) -> String {
        let names = Set(runtime.availableModelFileNames)

        let preferred: [String]
        if options.mode == .streaming && options.performance == .accurate {
            preferred = ["ggml-small.bin", "ggml-base.bin"]
        } else if options.mode == .finalize && options.performance == .balanced {
            preferred = ["ggml-small.bin", "ggml-base.bin"]
        } else if options.mode == .finalize && options.performance == .accurate {
            preferred = ["ggml-small.bin", "ggml-base.bin"]
        } else if preset.modelID.lowercased().contains("medium") {
            preferred = ["ggml-medium.bin", "ggml-small.bin", "ggml-base.bin"]
        } else if preset.modelID.lowercased().contains("small") || options.performance == .accurate {
            preferred = ["ggml-small.bin", "ggml-base.bin"]
        } else {
            preferred = ["ggml-base.bin", "ggml-small.bin"]
        }

        for candidate in preferred where names.contains(candidate) {
            return candidate
        }

        if names.contains(runtime.defaultModelFileName) {
            return runtime.defaultModelFileName
        }

        if let first = names.sorted().first {
            return first
        }

        return runtime.defaultModelFileName
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
            currentOptions?.aiProcessing ?? AIProcessingConfiguration(enabled: false, selectedModelID: nil)
        }
    }

    private func processLiveTextIfNeeded(_ text: String) -> String {
        let request = AIProcessingRequest(
            text: text,
            stage: .live,
            locale: runningLocale,
            configuration: currentAIProcessingConfiguration(),
            appContextText: withSessionLock { currentOptions?.appContextText },
            dictionaryTerms: withSessionLock { currentOptions?.dictionaryTerms ?? [] }
        )

        let semaphore = DispatchSemaphore(value: 0)
        var outcome: AIProcessingOutcome = .bypassed(text: text, reason: "AI processing did not run.")

        Task {
            outcome = await aiProcessingService.process(request)
            semaphore.signal()
        }

        semaphore.wait()
        emitProcessingDiagnosticIfNeeded(outcome, stage: .live)
        return outcome.text
    }

    private func emitProcessingDiagnosticIfNeeded(_ outcome: AIProcessingOutcome, stage: AIProcessingStage) {
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
        let detected = final.language?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if let detected, !detected.isEmpty {
            return detected
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
        whisperEngine.resetStreaming()
        resumeMediaPlaybackBestEffort()
        stableCommitter.reset()
        publishSessionActivity(false)
    }

    private func pauseMediaPlaybackBestEffort() {
        pauseMediaIfPlaying(appName: "Music", bundleIdentifier: "com.apple.Music")
        pauseMediaIfPlaying(appName: "Spotify", bundleIdentifier: "com.spotify.client")
    }

    private func resumeMediaPlaybackBestEffort() {
        let identifiers = pausedMediaAppIdentifiers
        guard !identifiers.isEmpty else { return }

        if identifiers.contains("com.apple.Music") {
            runAppleScriptBestEffort("""
            tell application "Music"
                play
            end tell
            """)
        }

        if identifiers.contains("com.spotify.client") {
            runAppleScriptBestEffort("""
            tell application "Spotify"
                play
            end tell
            """)
        }

        pausedMediaAppIdentifiers.removeAll()
    }

    private func pauseMediaIfPlaying(appName: String, bundleIdentifier: String) {
        guard !NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).isEmpty else {
            return
        }

        let descriptor = runAppleScriptBestEffort("""
        tell application "\(appName)"
            if player state is playing then
                pause
                return "paused"
            end if
            return "noop"
        end tell
        """)

        if descriptor?.stringValue == "paused" {
            pausedMediaAppIdentifiers.insert(bundleIdentifier)
        }
    }

    @discardableResult
    private func runAppleScriptBestEffort(_ source: String) -> NSAppleEventDescriptor? {
        guard let script = NSAppleScript(source: source) else {
            return nil
        }

        var error: NSDictionary?
        let descriptor = script.executeAndReturnError(&error)
        if let error {
            if let message = error[NSAppleScript.errorMessage] as? String {
                publishDiagnostic("Media control skipped: \(message)")
            }
            return nil
        }

        return descriptor
    }

    private func abortSession(reason: String) {
        cleanupSession()
        publishStatus("Error")
        publishDiagnostic(reason)
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

private extension String {
    func commonPrefixLength(with other: String) -> Int {
        var lhsIndex = startIndex
        let rhs = other
        var rhsIndex = rhs.startIndex
        var length = 0

        while lhsIndex < endIndex,
              rhsIndex < rhs.endIndex,
              self[lhsIndex] == rhs[rhsIndex] {
            length += 1
            formIndex(after: &lhsIndex)
            rhs.formIndex(after: &rhsIndex)
        }

        return length
    }
}
