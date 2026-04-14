import AIProcessingCore
import ASRCore
import AVFoundation
import AppKit
import ApplicationServices
import AudioCore
import CapabilityCore
import Carbon
import Foundation
import LicenseCore
import ServiceManagement
import SnippetCore
import SwiftUI
import UniformTypeIdentifiers

struct TranscriptHistoryEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let createdAt: Date
    let text: String
    let languageCode: String
    let mode: String

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        text: String,
        languageCode: String,
        mode: String
    ) {
        self.id = id
        self.createdAt = createdAt
        self.text = text
        self.languageCode = languageCode
        self.mode = mode
    }
}

enum LicensePresentationState {
    case notConfigured
    case notSet
    case active(tier: String)
    case invalid(reason: String)

    var label: String {
        switch self {
        case .notConfigured:
            return "Nicht konfiguriert"
        case .notSet:
            return "Nicht gesetzt"
        case .active(let tier):
            return "Aktiv: \(tier)"
        case .invalid(let reason):
            return "Ungültig: \(reason)"
        }
    }

    var color: Color {
        switch self {
        case .active:
            return .green
        case .notConfigured:
            return .orange
        case .invalid:
            return .red
        case .notSet:
            return .secondary
        }
    }
}

enum PermissionStatus: String {
    case granted = "Erteilt"
    case denied = "Verweigert"
    case notDetermined = "Noch nicht geprüft"
    case restricted = "Eingeschränkt"

    var label: String {
        rawValue
    }

    var color: Color {
        switch self {
        case .granted:
            return .green
        case .denied:
            return .orange
        case .notDetermined:
            return .secondary
        case .restricted:
            return .orange
        }
    }

    static func microphone(from status: AVAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .authorized:
            return .granted
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        @unknown default:
            return .notDetermined
        }
    }

    static func accessibility(isTrusted: Bool) -> PermissionStatus {
        isTrusted ? .granted : .denied
    }
}

protocol DictationRuntimeControlling: AnyObject {
    var onStatus: ((String) -> Void)? { get set }
    var onDiagnostic: ((String) -> Void)? { get set }
    var onDebugEvent: ((String) -> Void)? { get set }
    var onTranscript: ((String) -> Void)? { get set }
    var onFinalTranscript: ((FinalTranscriptEvent) -> Void)? { get set }
    var onSessionActivityChanged: ((Bool) -> Void)? { get set }
    var onPermissionInteractionFinished: (() -> Void)? { get set }

    func prepareRuntime()
    func setVoiceModelActiveDuration(_ duration: VoiceModelActiveDuration)
    func toggle(options: DictationStartOptions)
    func cancel()
    func start(options: DictationStartOptions)
    func openMicrophoneSettings()
    func openAccessibilitySettings()
    func promptAccessibilityTrustFromUser()
    func setAIProcessingService(_ service: AIProcessingService)
}

protocol GlobalHotkeyRegistering: AnyObject {
    var onToggle: (() -> Void)? { get set }
    var onHoldPress: (() -> Void)? { get set }
    var onHoldRelease: (() -> Void)? { get set }
    var onCancel: (() -> Void)? { get set }
    var onModeSwitch: (() -> Void)? { get set }

    @discardableResult
    func register(
        shortcut: HotkeyBinding,
        shortcutEnabled: Bool,
        holdShortcut: HotkeyBinding?,
        holdEnabled: Bool,
        cancelShortcut: HotkeyBinding?,
        cancelEnabled: Bool,
        modeShortcut: HotkeyBinding?,
        modeEnabled: Bool,
        force: Bool
    ) -> Bool
}

protocol AIRemoteProviderSecretStoring: AnyObject {
    func saveAPIKey(_ key: String, providerID: String) throws
    func loadAPIKey(providerID: String) -> String?
    func removeAPIKey(providerID: String)
}

enum LiveRewriteScope: String, CaseIterable, Identifiable {
    case currentSentence
    case currentSentenceAndPreviousSentence
    case currentSentenceAndTwoPreviousSentences
    case currentParagraph

    var id: String { rawValue }

    func localizedDisplayName(interfaceLanguageCode: String) -> String {
        if interfaceLanguageCode == "en" {
            switch self {
            case .currentSentence:
                return "Current sentence only"
            case .currentSentenceAndPreviousSentence:
                return "Current sentence + 1 previous sentence"
            case .currentSentenceAndTwoPreviousSentences:
                return "Current sentence + 2 previous sentences"
            case .currentParagraph:
                return "Current paragraph"
            }
        } else {
            switch self {
            case .currentSentence:
                return "Nur aktueller Satz"
            case .currentSentenceAndPreviousSentence:
                return "Aktueller Satz + 1 vorheriger Satz"
            case .currentSentenceAndTwoPreviousSentences:
                return "Aktueller Satz + 2 vorherige Sätze"
            case .currentParagraph:
                return "Ganzer aktueller Absatz"
            }
        }
    }

    var maximumMutableCharacterCount: Int {
        switch self {
        case .currentSentence:
            return 40
        case .currentSentenceAndPreviousSentence:
            return 72
        case .currentSentenceAndTwoPreviousSentences:
            return 128
        case .currentParagraph:
            return 220
        }
    }
}

enum VoiceModelActiveDuration: String, CaseIterable, Identifiable {
    case oneMinute
    case fiveMinutes
    case fifteenMinutes
    case forever

    var id: String { rawValue }

    var seconds: TimeInterval? {
        switch self {
        case .oneMinute:
            return 60
        case .fiveMinutes:
            return 5 * 60
        case .fifteenMinutes:
            return 15 * 60
        case .forever:
            return nil
        }
    }

    func localizedDisplayName(interfaceLanguageCode: String) -> String {
        if interfaceLanguageCode == "en" {
            switch self {
            case .oneMinute:
                return "1 minute"
            case .fiveMinutes:
                return "5 minutes"
            case .fifteenMinutes:
                return "15 minutes"
            case .forever:
                return "Forever"
            }
        } else {
            switch self {
            case .oneMinute:
                return "1 Minute"
            case .fiveMinutes:
                return "5 Minuten"
            case .fifteenMinutes:
                return "15 Minuten"
            case .forever:
                return "Für immer"
            }
        }
    }
}

enum HistoryRetentionPolicy: String, CaseIterable, Identifiable {
    case sevenDays
    case thirtyDays
    case ninetyDays
    case forever

    var id: String { rawValue }

    var retainedDays: Int? {
        switch self {
        case .sevenDays:
            return 7
        case .thirtyDays:
            return 30
        case .ninetyDays:
            return 90
        case .forever:
            return nil
        }
    }

    func localizedDisplayName(interfaceLanguageCode: String) -> String {
        if interfaceLanguageCode == "en" {
            switch self {
            case .sevenDays:
                return "7 days"
            case .thirtyDays:
                return "30 days"
            case .ninetyDays:
                return "90 days"
            case .forever:
                return "Forever"
            }
        } else {
            switch self {
            case .sevenDays:
                return "7 Tage"
            case .thirtyDays:
                return "30 Tage"
            case .ninetyDays:
                return "90 Tage"
            case .forever:
                return "Für immer"
            }
        }
    }
}

@MainActor
final class MacAppState: ObservableObject {
    @Published var streamingEnabled: Bool {
        didSet {
            userDefaults.set(streamingEnabled, forKey: UserDefaultsKeys.streamingEnabled)
        }
    }

    @Published var selectedLanguage: DictationLanguage {
        didSet {
            userDefaults.set(selectedLanguage.rawValue, forKey: UserDefaultsKeys.selectedLanguage)
            sanitizeSpeechModelSelections()
        }
    }

    @Published var translationOutputMode: TranslationOutputMode {
        didSet {
            userDefaults.set(
                translationOutputMode.rawValue, forKey: UserDefaultsKeys.translationOutputMode)
            sanitizeSpeechModelSelections()
        }
    }

    @Published var visibleMenuBarLanguages: [String] {
        didSet {
            userDefaults.set(
                visibleMenuBarLanguages, forKey: UserDefaultsKeys.visibleMenuBarLanguages)
            sanitizeVisibleMenuBarLanguages()
        }
    }

    @Published var performanceProfile: DictationPerformance {
        didSet {
            userDefaults.set(
                performanceProfile.rawValue, forKey: UserDefaultsKeys.performanceProfile)
        }
    }

    @Published var selectedVoiceProviderID: String {
        didSet {
            userDefaults.set(
                selectedVoiceProviderID, forKey: UserDefaultsKeys.selectedVoiceProviderID)
            sanitizeSpeechModelSelections()
        }
    }

    @Published var selectedVoiceModelID: String {
        didSet {
            userDefaults.set(selectedVoiceModelID, forKey: UserDefaultsKeys.selectedVoiceModelID)
            sanitizeSpeechModelSelections()
        }
    }

    @Published var voiceLanguageOverrides: [VoiceLanguageOverride] {
        didSet {
            persistVoiceLanguageOverrides()
        }
    }

    @Published var selectedHotkey: HotkeyBinding {
        didSet {
            userDefaults.set(selectedHotkey.rawValue, forKey: UserDefaultsKeys.selectedHotkey)
            registerSelectedHotkey(force: true)
        }
    }

    @Published var toggleShortcutEnabled: Bool {
        didSet {
            userDefaults.set(toggleShortcutEnabled, forKey: UserDefaultsKeys.toggleShortcutEnabled)
            registerSelectedHotkey(force: true)
        }
    }

    @Published var holdToDictateEnabled: Bool {
        didSet {
            userDefaults.set(holdToDictateEnabled, forKey: UserDefaultsKeys.holdToDictateEnabled)
            registerSelectedHotkey(force: true)
        }
    }

    @Published var holdShortcut: HotkeyBinding {
        didSet {
            userDefaults.set(holdShortcut.rawValue, forKey: UserDefaultsKeys.holdShortcut)
            registerSelectedHotkey(force: true)
        }
    }

    @Published var cancelShortcutEnabled: Bool {
        didSet {
            userDefaults.set(cancelShortcutEnabled, forKey: UserDefaultsKeys.cancelShortcutEnabled)
            registerSelectedHotkey(force: true)
        }
    }

    @Published var cancelShortcut: HotkeyBinding {
        didSet {
            userDefaults.set(cancelShortcut.rawValue, forKey: UserDefaultsKeys.cancelShortcut)
            registerSelectedHotkey(force: true)
        }
    }

    @Published var modeSwitchShortcutEnabled: Bool {
        didSet {
            userDefaults.set(
                modeSwitchShortcutEnabled, forKey: UserDefaultsKeys.modeSwitchShortcutEnabled)
            registerSelectedHotkey(force: true)
        }
    }

    @Published var modeSwitchShortcut: HotkeyBinding {
        didSet {
            userDefaults.set(
                modeSwitchShortcut.rawValue, forKey: UserDefaultsKeys.modeSwitchShortcut)
            registerSelectedHotkey(force: true)
        }
    }

    @Published var finalResultDeliveryMode: FinalResultDeliveryMode {
        didSet {
            userDefaults.set(
                finalResultDeliveryMode.rawValue, forKey: UserDefaultsKeys.finalResultDeliveryMode)
        }
    }

    @Published var clipboardFallbackWhenNoTarget: Bool {
        didSet {
            userDefaults.set(
                clipboardFallbackWhenNoTarget,
                forKey: UserDefaultsKeys.clipboardFallbackWhenNoTarget)
        }
    }

    @Published var liveRewriteScope: LiveRewriteScope {
        didSet {
            userDefaults.set(liveRewriteScope.rawValue, forKey: UserDefaultsKeys.liveRewriteScope)
        }
    }

    @Published var showMenuBarShortcutHints: Bool {
        didSet {
            userDefaults.set(
                showMenuBarShortcutHints, forKey: UserDefaultsKeys.showMenuBarShortcutHints)
        }
    }

    @Published var compactMenuBarDesign: Bool {
        didSet {
            userDefaults.set(compactMenuBarDesign, forKey: UserDefaultsKeys.compactMenuBarDesign)
        }
    }

    @Published var showInDock: Bool {
        didSet {
            userDefaults.set(showInDock, forKey: UserDefaultsKeys.showInDock)
            let policyApplied = applyActivationPolicy()
            if policyApplied {
                scheduleSettingsReopenAfterDockPolicyChange()
            }
        }
    }

    @Published var launchOnLoginEnabled: Bool {
        didSet {
            userDefaults.set(launchOnLoginEnabled, forKey: UserDefaultsKeys.launchOnLoginEnabled)
            syncLaunchOnLogin()
        }
    }

    @Published var automaticallyCheckForUpdates: Bool {
        didSet {
            userDefaults.set(
                automaticallyCheckForUpdates, forKey: UserDefaultsKeys.automaticallyCheckForUpdates)
            syncAutomaticUpdateChecks()
        }
    }

    @Published var debugModeEnabled: Bool {
        didSet {
            userDefaults.set(debugModeEnabled, forKey: UserDefaultsKeys.debugModeEnabled)
            if debugModeEnabled {
                appendDebug("debug-mode.enabled")
            } else {
                appendAudit("debug-mode.disabled")
            }
        }
    }

    @Published var aiProcessingEnabled: Bool {
        didSet {
            userDefaults.set(aiProcessingEnabled, forKey: UserDefaultsKeys.aiProcessingEnabled)
        }
    }

    @Published var selectedAIModelID: String? {
        didSet {
            userDefaults.set(selectedAIModelID, forKey: UserDefaultsKeys.selectedAIModelID)
            rebuildAIProcessingStack(reason: "model-selection")
        }
    }

    @Published var aiProcessingApplyDuringLiveInsertion: Bool {
        didSet {
            userDefaults.set(
                aiProcessingApplyDuringLiveInsertion,
                forKey: UserDefaultsKeys.aiProcessingApplyDuringLiveInsertion)
        }
    }

    @Published var aiProcessingApplyToFinalResult: Bool {
        didSet {
            userDefaults.set(
                aiProcessingApplyToFinalResult,
                forKey: UserDefaultsKeys.aiProcessingApplyToFinalResult)
        }
    }

    @Published var aiTaskCleanupEnabled: Bool {
        didSet {
            userDefaults.set(aiTaskCleanupEnabled, forKey: UserDefaultsKeys.aiTaskCleanupEnabled)
            sanitizeAIProcessingSelections()
        }
    }

    @Published var aiTaskToneEnabled: Bool {
        didSet {
            userDefaults.set(aiTaskToneEnabled, forKey: UserDefaultsKeys.aiTaskToneEnabled)
            sanitizeAIProcessingSelections()
        }
    }

    @Published var aiTaskSalutationEnabled: Bool {
        didSet {
            userDefaults.set(
                aiTaskSalutationEnabled, forKey: UserDefaultsKeys.aiTaskSalutationEnabled)
            sanitizeAIProcessingSelections()
        }
    }

    @Published var aiTaskFormatEnabled: Bool {
        didSet {
            userDefaults.set(aiTaskFormatEnabled, forKey: UserDefaultsKeys.aiTaskFormatEnabled)
            sanitizeAIProcessingSelections()
        }
    }

    @Published var aiRevisionGoal: AIRevisionGoal {
        didSet {
            userDefaults.set(aiRevisionGoal.rawValue, forKey: UserDefaultsKeys.aiRevisionGoal)
        }
    }

    @Published var aiFormattingMode: AIFormattingMode {
        didSet {
            userDefaults.set(aiFormattingMode.rawValue, forKey: UserDefaultsKeys.aiFormattingMode)
            sanitizeAIProcessingSelections()
        }
    }

    @Published var aiWritingStyle: AIWritingStyle {
        didSet {
            if !aiFormattingMode.allowedWritingStyles.contains(aiWritingStyle) {
                aiWritingStyle = .none
                return
            }
            userDefaults.set(aiWritingStyle.rawValue, forKey: UserDefaultsKeys.aiWritingStyle)
        }
    }

    @Published var aiSalutation: AISalutation {
        didSet {
            if !aiFormattingMode.supportsSalutation && aiSalutation != .none {
                aiSalutation = .none
                return
            }
            userDefaults.set(aiSalutation.rawValue, forKey: UserDefaultsKeys.aiSalutation)
        }
    }

    /// 0...1 — stärkere Bereinigung nach rechts; nur sinnvoll bei aktiver Bereinigungs-Aufgabe.
    @Published var aiCleanupIntensity: Double {
        didSet {
            let clamped = min(1, max(0, aiCleanupIntensity))
            if clamped != aiCleanupIntensity {
                aiCleanupIntensity = clamped
                return
            }
            userDefaults.set(aiCleanupIntensity, forKey: UserDefaultsKeys.aiCleanupIntensity)
        }
    }

    @Published var voiceModelActiveDuration: VoiceModelActiveDuration {
        didSet {
            userDefaults.set(
                voiceModelActiveDuration.rawValue, forKey: UserDefaultsKeys.voiceModelActiveDuration
            )
            dictationRuntime.setVoiceModelActiveDuration(voiceModelActiveDuration)
        }
    }

    @Published var automaticMicrophoneGainBoost: Bool {
        didSet {
            userDefaults.set(
                automaticMicrophoneGainBoost, forKey: UserDefaultsKeys.automaticMicrophoneGainBoost)
        }
    }

    @Published var silenceRemovalEnabled: Bool {
        didSet {
            userDefaults.set(silenceRemovalEnabled, forKey: UserDefaultsKeys.silenceRemovalEnabled)
        }
    }

    @Published var dynamicNormalizationEnabled: Bool {
        didSet {
            userDefaults.set(
                dynamicNormalizationEnabled, forKey: UserDefaultsKeys.dynamicNormalizationEnabled)
        }
    }

    @Published var noiseSuppressionLevel: Double {
        didSet {
            userDefaults.set(noiseSuppressionLevel, forKey: UserDefaultsKeys.noiseSuppressionLevel)
        }
    }

    @Published var soundEffectsEnabled: Bool {
        didSet {
            userDefaults.set(soundEffectsEnabled, forKey: UserDefaultsKeys.soundEffectsEnabled)
        }
    }

    @Published var soundEffectsVolume: Double {
        didSet {
            userDefaults.set(soundEffectsVolume, forKey: UserDefaultsKeys.soundEffectsVolume)
        }
    }

    @Published var historyRetentionPolicy: HistoryRetentionPolicy {
        didSet {
            userDefaults.set(
                historyRetentionPolicy.rawValue, forKey: UserDefaultsKeys.historyRetentionPolicy)
            pruneHistoryIfNeeded()
        }
    }

    @Published var autoSendAfterPaste: Bool {
        didSet {
            userDefaults.set(autoSendAfterPaste, forKey: UserDefaultsKeys.autoSendAfterPaste)
        }
    }

    @Published var restoreClipboardAfterPaste: Bool {
        didSet {
            userDefaults.set(
                restoreClipboardAfterPaste, forKey: UserDefaultsKeys.restoreClipboardAfterPaste)
        }
    }

    @Published var simulateKeypresses: Bool {
        didSet {
            userDefaults.set(simulateKeypresses, forKey: UserDefaultsKeys.simulateKeypresses)
        }
    }

    @Published var muteMusicWhileDictating: Bool {
        didSet {
            userDefaults.set(
                muteMusicWhileDictating, forKey: UserDefaultsKeys.muteMusicWhileDictating)
        }
    }

    @Published var contextAwarenessMode: ContextAwarenessMode {
        didSet {
            userDefaults.set(
                contextAwarenessMode.rawValue, forKey: UserDefaultsKeys.contextAwarenessMode)
        }
    }

    @Published var dictionaryAutoAddEnabled: Bool {
        didSet {
            userDefaults.set(
                dictionaryAutoAddEnabled, forKey: UserDefaultsKeys.dictionaryAutoAddEnabled)
        }
    }

    @Published var remoteProviders: [AIRemoteProviderConfiguration] = [] {
        didSet {
            persistRemoteProviders()
            rebuildAIProcessingStack(reason: "remote-providers-updated")
        }
    }

    @Published var selectedRemoteProviderID: String? {
        didSet {
            userDefaults.set(
                selectedRemoteProviderID, forKey: UserDefaultsKeys.selectedRemoteProviderID)
            remoteProviderAPIKeyDraft =
                selectedRemoteProviderID.flatMap {
                    aiRemoteProviderSecretStore.loadAPIKey(providerID: $0)
                } ?? ""
        }
    }

    @Published var remoteProviderAPIKeyDraft: String = ""
    @Published var selectedSettingsTab: SettingsTab = .general

    @Published var snippetRules: [SnippetRule] = []
    @Published var dictionaryTerms: [DictionaryTerm] = []
    @Published var dictionaryReviewQueue: [DictionaryReviewCandidate] = []
    @Published var transcriptHistory: [TranscriptHistoryEntry] = []
    @Published private(set) var aiModels: [AIModelDescriptor] = []
    @Published private(set) var voiceProviders: [VoiceProviderDescriptor] = []
    @Published private(set) var voiceModels: [VoiceModelDescriptor] = []
    @Published private(set) var installedVoiceModelFileNames: Set<String> = []
    @Published private(set) var voiceModelOperationInFlightIDs: Set<String> = []

    @Published var recordingStatus: String = "Idle"
    @Published var diagnosticsText: String = "Initializing ASR runtime..."
    @Published var debugLogText: String = ""
    @Published var capabilitySummary: String = ""
    @Published var lastTranscript: String = ""
    @Published var microphonePermissionStatus: PermissionStatus = .notDetermined
    @Published var accessibilityPermissionStatus: PermissionStatus = .notDetermined

    @Published var licenseInput: String = ""
    @Published var storedLicenseSummary: String?
    @Published var licenseStatusText: String = "No license"
    @Published var licenseValid: Bool = false
    @Published var licensePresentationState: LicensePresentationState = .notSet
    @Published var updaterStatusText: String = "Updater wird initialisiert..."
    @Published var updaterConfigured: Bool = false
    @Published var updaterFeedURLText: String = ""
    @Published var isSessionActive: Bool = false

    var menuBarIconName: String {
        switch recordingStatus {
        case "Recording":
            return "mic.fill"
        case "Error":
            return "exclamationmark.triangle.fill"
        default:
            return "waveform"
        }
    }

    var menuBarTitle: String {
        ""
    }

    var hotkeyDisplayText: String {
        selectedHotkey.displayName
    }

    var holdShortcutDisplayText: String {
        holdShortcut.displayName
    }

    var isLicenseUIEnabledForDevelopment: Bool {
        appConfiguration.isLicenseUIEnabledForDevelopment
    }

    var latestDictationText: String {
        transcriptHistory.first?.text ?? lastTranscript
    }

    var dictationCapability: DictationCapability {
        if microphonePermissionStatus != .granted {
            return .unavailable
        }

        if accessibilityPermissionStatus == .granted {
            return .fullSystemInsertion
        }

        return .limitedTranscription
    }

    var hotkeyHintText: String {
        switch recordingStatus {
        case "Recording":
            return "Diktat stoppen: \(selectedHotkey.displayName)"
        default:
            return "Diktat starten: \(selectedHotkey.displayName)"
        }
    }

    var hotkeyAdvisory: HotkeyAdvisory? {
        HotkeyAdvisor.advisory(for: selectedHotkey)
    }

    var holdShortcutAdvisory: HotkeyAdvisory? {
        if holdShortcut == selectedHotkey {
            return HotkeyAdvisory(
                severity: .critical,
                title: "Konflikt mit Start/Stop-Shortcut",
                message:
                    "Hold-to-dictate und der normale Diktier-Shortcut dürfen nicht dieselbe Kombination verwenden."
            )
        }
        return HotkeyAdvisor.advisory(for: holdShortcut)
    }

    var cancelShortcutAdvisory: HotkeyAdvisory? {
        if cancelShortcut == selectedHotkey || cancelShortcut == holdShortcut {
            return HotkeyAdvisory(
                severity: .warning,
                title: "Konflikt mit Diktier-Shortcuts",
                message:
                    "Der Abbrechen-Shortcut sollte nicht mit Start/Stopp oder Hold-to-dictate kollidieren."
            )
        }
        return HotkeyAdvisor.advisory(for: cancelShortcut)
    }

    var modeSwitchShortcutAdvisory: HotkeyAdvisory? {
        if modeSwitchShortcut == selectedHotkey || modeSwitchShortcut == holdShortcut
            || modeSwitchShortcut == cancelShortcut
        {
            return HotkeyAdvisory(
                severity: .warning,
                title: "Konflikt mit anderen Shortcuts",
                message:
                    "Der Moduswechsel-Shortcut sollte eine eigene, eindeutige Kombination verwenden."
            )
        }
        return HotkeyAdvisor.advisory(for: modeSwitchShortcut)
    }

    var statusBadgeText: String {
        switch recordingStatus {
        case "Recording":
            return "Aufnahme läuft"
        case "Error":
            return "Fehler"
        default:
            return "Bereit"
        }
    }

    var statusBadgeColor: Color {
        switch recordingStatus {
        case "Recording":
            return .green
        case "Error":
            return .red
        default:
            return .secondary
        }
    }

    var statusHintText: String {
        let latestDiagnosticLine = Self.latestDiagnosticLine(from: diagnosticsText)
        switch recordingStatus {
        case "Recording":
            return lastTranscript.isEmpty
                ? "Mikrofon aktiv – sprich, um Text einzufügen."
                : "Letztes Transkript: \(Self.summarize(lastTranscript))"
        case "Error":
            return Self.stripDiagnosticPrefix(latestDiagnosticLine)
        default:
            return lastTranscript.isEmpty
                ? "Bereit für ein neues Diktat."
                : "Letztes Transkript: \(Self.summarize(lastTranscript))"
        }
    }

    var permissionSummary: String {
        switch dictationCapability {
        case .fullSystemInsertion:
            return "Alle Berechtigungen erteilt."
        case .limitedTranscription:
            return
                "Bedienungshilfen fehlen. Diktate bleiben als Verlauf oder Zwischenablage verfügbar."
        case .unavailable:
            let missing = missingPermissionTargets
            return "Fehlende Berechtigungen: \(missing.joined(separator: ", "))."
        }
    }

    /// Kurztext für die Menüleisten-Popup-Zeile (verhindert breite Layouts durch lange Sätze).
    var menuBarCompactPermissionHint: String {
        let mic = microphonePermissionStatus != .granted
        let ax = accessibilityPermissionStatus != .granted
        switch (mic, ax) {
        case (true, true):
            return "Mikrofon & Bedienungshilfen prüfen"
        case (true, false):
            return "Mikrofon prüfen"
        case (false, true):
            return "Bedienungshilfen prüfen"
        case (false, false):
            return ""
        }
    }

    var missingPermissionTargets: [String] {
        var result: [String] = []
        if microphonePermissionStatus != .granted {
            result.append("Mikrofon")
        }
        if accessibilityPermissionStatus != .granted {
            result.append("Bedienungshilfen")
        }
        return result
    }

    var hasPermissionProblems: Bool {
        !missingPermissionTargets.isEmpty
    }

    var appSupportDirectoryURL: URL {
        Self.appSupportDirectory()
    }

    var appSupportDirectoryPathText: String {
        Self.appSupportDirectory().path
    }

    var dockVisibilityStatusText: String {
        showInDock
            ? "Im Dock sichtbar"
            : "Nur in der Menüleiste sichtbar"
    }

    var launchOnLoginStatusText: String {
        launchOnLoginEnabled
            ? "Beim Anmelden automatisch starten"
            : "Nicht beim Anmelden starten"
    }

    var availableQuickSettingsAIModels: [AIModelDescriptor] {
        aiModels.filter { $0.quickSettingsEligible && $0.availability.isAvailable }
    }

    var visibleAIModels: [AIModelDescriptor] {
        aiModels
    }

    var selectedAIModel: AIModelDescriptor? {
        guard let selectedAIModelID else { return nil }
        return aiModels.first(where: { $0.id == selectedAIModelID })
    }

    var selectedRemoteProvider: AIRemoteProviderConfiguration? {
        guard let selectedRemoteProviderID else { return nil }
        return remoteProviders.first(where: { $0.id == selectedRemoteProviderID })
    }

    var selectedVoiceProvider: VoiceProviderDescriptor? {
        voiceProviders.first(where: { $0.id == selectedVoiceProviderID })
    }

    var visibleVoiceModels: [VoiceModelDescriptor] {
        voiceModels.filter { $0.providerID == selectedVoiceProviderID }
    }

    var selectedVoiceModel: VoiceModelDescriptor? {
        voiceModels.first(where: { $0.id == selectedVoiceModelID })
    }

    var selectedVoiceModelSupportsTranslation: Bool {
        selectedVoiceModel?.supportsTranslationToEnglish ?? false
    }

    var speechTranslationAvailable: Bool {
        selectedVoiceModelSupportsTranslation
    }

    var selectedVoiceModelLanguageOptions: [DictationLanguage] {
        voiceLanguageOptions(for: selectedVoiceModel)
    }

    var selectedVoiceModelLanguageHintText: String? {
        guard let selectedVoiceModel else { return nil }
        if let languageCode = selectedVoiceModel.languageCode {
            let languageName =
                DictationLanguage(rawValue: languageCode)?.displayName ?? languageCode.uppercased()
            return
                "Dieses Modell ist auf \(languageName) festgelegt. Die Sprachauswahl reduziert sich deshalb auf \(languageName) und Auto."
        }
        return nil
    }

    var selectedLanguageVoiceOverride: VoiceLanguageOverride? {
        guard selectedLanguage != .auto else { return nil }
        return voiceLanguageOverrides.first(where: { $0.languageCode == selectedLanguage.rawValue })
    }

    var effectiveAIProcessingEnabled: Bool {
        aiProcessingEnabled && (selectedAIModel?.availability.isAvailable ?? false)
    }

    var availableAIWritingStyles: [AIWritingStyle] {
        aiFormattingMode.allowedWritingStyles
    }

    var aiFormattingModeSupportsSalutation: Bool {
        aiFormattingMode.supportsSalutation
    }

    /// „Modus“ (Format/Zieltext) nur bei aktiver Aufgabe „Format / Modus“, nicht bei reiner Stil-/Anrede-Aufgabe.
    var aiShowsModeControls: Bool {
        aiTaskFormatEnabled
    }

    var aiShowsWritingStyleControls: Bool {
        aiTaskToneEnabled
    }

    var aiShowsSalutationControls: Bool {
        aiTaskSalutationEnabled && aiFormattingModeSupportsSalutation
    }

    var aiDerivedRevisionGoal: AIRevisionGoal {
        if aiTaskFormatEnabled {
            return .adaptFormat
        }
        if aiTaskToneEnabled {
            return .adjustTone
        }
        if aiTaskSalutationEnabled {
            return .adjustSalutation
        }
        return .cleanup
    }

    var aiProcessingConfiguration: AIProcessingConfiguration {
        AIProcessingConfiguration(
            enabled: effectiveAIProcessingEnabled,
            selectedModelID: selectedAIModelID,
            applyDuringLiveInsertion: aiProcessingApplyDuringLiveInsertion,
            applyToFinalResult: aiProcessingApplyToFinalResult,
            revisionGoal: aiDerivedRevisionGoal,
            formattingMode: aiFormattingMode,
            style: aiTaskToneEnabled && availableAIWritingStyles.contains(aiWritingStyle)
                ? aiWritingStyle : .none,
            salutation: aiTaskSalutationEnabled && aiFormattingModeSupportsSalutation
                ? aiSalutation : .none,
            cleanupEnabled: aiTaskCleanupEnabled,
            cleanupIntensity: aiCleanupIntensity,
            toneAdjustmentEnabled: aiTaskToneEnabled,
            salutationAdjustmentEnabled: aiTaskSalutationEnabled,
            formatAdaptationEnabled: aiTaskFormatEnabled
        )
    }

    var audioProcessingConfiguration: AudioProcessingConfiguration {
        AudioProcessingConfiguration(
            inputLevelCompensationEnabled: automaticMicrophoneGainBoost,
            silenceRemovalEnabled: silenceRemovalEnabled,
            dynamicNormalizationEnabled: dynamicNormalizationEnabled,
            noiseSuppressionLevel: Float(noiseSuppressionLevel)
        )
    }

    var soundFeedbackConfiguration: SoundFeedbackConfiguration {
        SoundFeedbackConfiguration(
            enabled: soundEffectsEnabled,
            volume: soundEffectsVolume
        )
    }

    private enum UserDefaultsKeys {
        static let streamingEnabled = "wispr.settings.streamingEnabled"
        static let selectedLanguage = "wispr.settings.selectedLanguage"
        static let translationOutputMode = "wispr.settings.translationOutputMode"
        static let visibleMenuBarLanguages = "wispr.settings.visibleMenuBarLanguages"
        static let performanceProfile = "wispr.settings.performanceProfile"
        static let selectedVoiceProviderID = "wispr.settings.selectedVoiceProviderID"
        static let selectedVoiceModelID = "wispr.settings.selectedVoiceModelID"
        static let voiceLanguageOverrides = "wispr.settings.voiceLanguageOverrides"
        static let selectedHotkey = "wispr.settings.selectedHotkey"
        static let toggleShortcutEnabled = "wispr.settings.toggleShortcutEnabled"
        static let holdToDictateEnabled = "wispr.settings.holdToDictateEnabled"
        static let holdShortcut = "wispr.settings.holdShortcut"
        static let cancelShortcutEnabled = "wispr.settings.cancelShortcutEnabled"
        static let cancelShortcut = "wispr.settings.cancelShortcut"
        static let modeSwitchShortcutEnabled = "wispr.settings.modeSwitchShortcutEnabled"
        static let modeSwitchShortcut = "wispr.settings.modeSwitchShortcut"
        static let finalResultDeliveryMode = "wispr.settings.finalResultDeliveryMode"
        static let clipboardFallbackWhenNoTarget = "wispr.settings.clipboardFallbackWhenNoTarget"
        static let liveRewriteScope = "wispr.settings.liveRewriteScope"
        static let showMenuBarShortcutHints = "wispr.settings.showMenuBarShortcutHints"
        static let compactMenuBarDesign = "wispr.settings.compactMenuBarDesign"
        static let showInDock = "wispr.settings.showInDock"
        static let launchOnLoginEnabled = "wispr.settings.launchOnLoginEnabled"
        static let automaticallyCheckForUpdates = "wispr.settings.automaticallyCheckForUpdates"
        static let debugModeEnabled = "wispr.settings.debugModeEnabled"
        static let aiProcessingEnabled = "wispr.settings.aiProcessingEnabled"
        static let selectedAIModelID = "wispr.settings.selectedAIModelID"
        static let aiProcessingApplyDuringLiveInsertion =
            "wispr.settings.aiProcessing.applyDuringLiveInsertion"
        static let aiProcessingApplyToFinalResult = "wispr.settings.aiProcessing.applyToFinalResult"
        static let aiTaskCleanupEnabled = "wispr.settings.aiProcessing.task.cleanup"
        static let aiTaskToneEnabled = "wispr.settings.aiProcessing.task.tone"
        static let aiTaskSalutationEnabled = "wispr.settings.aiProcessing.task.salutation"
        static let aiTaskFormatEnabled = "wispr.settings.aiProcessing.task.format"
        static let legacyAIProcessingScope = "wispr.settings.aiProcessingScope"
        static let aiRevisionGoal = "wispr.settings.aiProcessing.revisionGoal"
        static let aiFormattingMode = "wispr.settings.aiProcessing.formattingMode"
        static let aiWritingStyle = "wispr.settings.aiWritingStyle"
        static let aiSalutation = "wispr.settings.aiSalutation"
        static let aiCleanupIntensity = "wispr.settings.aiProcessing.cleanupIntensity"
        static let voiceModelActiveDuration = "wispr.settings.ai.voiceModelActiveDuration"
        static let automaticMicrophoneGainBoost = "wispr.settings.automaticMicrophoneGainBoost"
        static let silenceRemovalEnabled = "wispr.settings.silenceRemovalEnabled"
        static let dynamicNormalizationEnabled = "wispr.settings.dynamicNormalizationEnabled"
        static let noiseSuppressionLevel = "wispr.settings.noiseSuppressionLevel"
        static let soundEffectsEnabled = "wispr.settings.soundEffectsEnabled"
        static let soundEffectsVolume = "wispr.settings.soundEffectsVolume"
        static let historyRetentionPolicy = "wispr.settings.historyRetentionPolicy"
        static let autoSendAfterPaste = "wispr.settings.autoSendAfterPaste"
        static let restoreClipboardAfterPaste = "wispr.settings.restoreClipboardAfterPaste"
        static let simulateKeypresses = "wispr.settings.simulateKeypresses"
        static let muteMusicWhileDictating = "wispr.settings.muteMusicWhileDictating"
        static let contextAwarenessMode = "wispr.settings.contextAwarenessMode"
        static let dictionaryAutoAddEnabled = "wispr.settings.dictionaryAutoAddEnabled"
        static let remoteProviders = "wispr.settings.ai.remoteProviders"
        static let selectedRemoteProviderID = "wispr.settings.ai.selectedRemoteProviderID"
    }

    private let userDefaults: UserDefaults
    private let preferencesStore: MacAppPreferencesStore
    private let sessionConfigurationBuilder: SessionConfigurationBuilder
    private let hotkeyManager: GlobalHotkeyRegistering
    let dictationRuntime: DictationRuntimeControlling
    private let snippetStore: SnippetStore
    private let dictionaryStore: PersonalDictionaryStoring
    private let historyStore: TranscriptHistoryStoring
    private let auditLogger: AuditLogging
    private let debugLogger: AuditLogging
    private let permissionController: PermissionControlling
    private let capabilityProfiler = CapabilityProfiler()
    private let aiRemoteProviderSecretStore: AIRemoteProviderSecretStoring
    private let voiceModelInstaller = VoiceModelInstaller()
    private var aiProcessingService = AIProcessingService()
    private let appConfiguration: MacAppConfiguration

    private let licenseController: LicenseController
    private var permissionCoordinator: PermissionCoordinator!
    private var appLifecycleCoordinator: AppLifecycleCoordinator!
    var sessionEntryController: SessionEntryController!
    private var transcriptHistoryController: TranscriptHistoryController!
    private var diagnosticsController: DiagnosticsController!
    private var snippetController: SnippetController!
    var aiProviderController: AIProviderController!
    var speechModelController: SpeechModelController!
    weak var updaterController: SparkleUpdaterController?
    private var dockPolicySettingsReopenWorkItem: DispatchWorkItem?
    var checkForUpdatesHandler: (() -> Void)?
    var openSettingsHandler: (() -> Void)?

    init(
        userDefaults: UserDefaults = .standard,
        configuration: MacAppConfiguration = .load(),
        permissionController: PermissionControlling = PermissionController(),
        dictationRuntime: DictationRuntimeControlling = DictationRuntime(),
        hotkeyManager: GlobalHotkeyRegistering = GlobalHotkeyManager(),
        historyStore: TranscriptHistoryStoring? = nil,
        aiRemoteProviderSecretStore: AIRemoteProviderSecretStoring = AIRemoteProviderSecretStore(),
        skipStartupSystemHooks: Bool = false
    ) {
        self.userDefaults = userDefaults
        self.appConfiguration = configuration
        self.permissionController = permissionController
        self.dictationRuntime = dictationRuntime
        self.hotkeyManager = hotkeyManager
        self.aiRemoteProviderSecretStore = aiRemoteProviderSecretStore
        self.preferencesStore = MacAppPreferencesStore(userDefaults: userDefaults)
        self.sessionConfigurationBuilder = SessionConfigurationBuilder()

        let preferences = preferencesStore.loadInitialState(
            currentLaunchOnLoginEnabled: Self.currentLaunchOnLoginEnabled())

        self.streamingEnabled = preferences.streamingEnabled
        self.selectedLanguage = preferences.selectedLanguage
        self.translationOutputMode = preferences.translationOutputMode
        self.visibleMenuBarLanguages = preferences.visibleMenuBarLanguages
        self.performanceProfile = preferences.performanceProfile
        self.selectedVoiceProviderID = preferences.selectedVoiceProviderID
        self.selectedVoiceModelID = preferences.selectedVoiceModelID
        self.voiceLanguageOverrides = preferences.voiceLanguageOverrides
        self.selectedHotkey = preferences.selectedHotkey
        self.toggleShortcutEnabled = preferences.toggleShortcutEnabled
        self.holdToDictateEnabled = preferences.holdToDictateEnabled
        self.holdShortcut = preferences.holdShortcut
        self.cancelShortcutEnabled = preferences.cancelShortcutEnabled
        self.cancelShortcut = preferences.cancelShortcut
        self.modeSwitchShortcutEnabled = preferences.modeSwitchShortcutEnabled
        self.modeSwitchShortcut = preferences.modeSwitchShortcut
        self.finalResultDeliveryMode = preferences.finalResultDeliveryMode
        self.clipboardFallbackWhenNoTarget = preferences.clipboardFallbackWhenNoTarget
        self.liveRewriteScope = preferences.liveRewriteScope
        self.showMenuBarShortcutHints = preferences.showMenuBarShortcutHints
        self.compactMenuBarDesign = preferences.compactMenuBarDesign
        self.showInDock = preferences.showInDock
        self.launchOnLoginEnabled = preferences.launchOnLoginEnabled
        self.automaticallyCheckForUpdates = preferences.automaticallyCheckForUpdates
        self.debugModeEnabled = preferences.debugModeEnabled
        self.aiProcessingEnabled = preferences.aiProcessingEnabled
        self.selectedAIModelID = preferences.selectedAIModelID
        self.aiProcessingApplyDuringLiveInsertion = preferences.aiProcessingApplyDuringLiveInsertion
        self.aiProcessingApplyToFinalResult = preferences.aiProcessingApplyToFinalResult
        self.aiTaskCleanupEnabled = preferences.aiTaskCleanupEnabled
        self.aiTaskToneEnabled = preferences.aiTaskToneEnabled
        self.aiTaskSalutationEnabled = preferences.aiTaskSalutationEnabled
        self.aiTaskFormatEnabled = preferences.aiTaskFormatEnabled
        self.aiRevisionGoal = preferences.aiRevisionGoal
        self.aiFormattingMode = preferences.aiFormattingMode
        self.aiWritingStyle = preferences.aiWritingStyle
        self.aiSalutation = preferences.aiSalutation
        self.aiCleanupIntensity = preferences.aiCleanupIntensity
        self.voiceModelActiveDuration = preferences.voiceModelActiveDuration
        self.automaticMicrophoneGainBoost = preferences.automaticMicrophoneGainBoost
        self.silenceRemovalEnabled = preferences.silenceRemovalEnabled
        self.dynamicNormalizationEnabled = preferences.dynamicNormalizationEnabled
        self.noiseSuppressionLevel = preferences.noiseSuppressionLevel
        self.soundEffectsEnabled = preferences.soundEffectsEnabled
        self.soundEffectsVolume = preferences.soundEffectsVolume
        self.historyRetentionPolicy = preferences.historyRetentionPolicy
        self.autoSendAfterPaste = preferences.autoSendAfterPaste
        self.restoreClipboardAfterPaste = preferences.restoreClipboardAfterPaste
        self.simulateKeypresses = preferences.simulateKeypresses
        self.muteMusicWhileDictating = preferences.muteMusicWhileDictating
        self.contextAwarenessMode = preferences.contextAwarenessMode
        self.dictionaryAutoAddEnabled = preferences.dictionaryAutoAddEnabled
        self.remoteProviders = preferences.remoteProviders
        self.selectedRemoteProviderID = preferences.selectedRemoteProviderID

        self.snippetStore = SnippetStore(fileURL: Self.snippetStorageURL())
        self.dictionaryStore = PersonalDictionaryStore(fileURL: Self.dictionaryStorageURL())
        self.historyStore = historyStore ?? TranscriptHistoryStore(fileURL: Self.historyStorageURL())
        self.auditLogger = AuditLogger(fileURL: Self.auditLogStorageURL())
        self.debugLogger = AuditLogger(fileURL: Self.debugLogStorageURL())
        self.licenseController = LicenseController(
            configuration: configuration, cacheFileURL: Self.legacyLicenseCacheURL())
        self.remoteProviderAPIKeyDraft =
            preferences.selectedRemoteProviderID.flatMap {
                aiRemoteProviderSecretStore.loadAPIKey(providerID: $0)
            } ?? ""

        self.diagnosticsController = DiagnosticsController(
            auditLogger: self.auditLogger,
            debugLogger: self.debugLogger,
            currentRecordingStatus: { [weak self] in
                self?.recordingStatus ?? "Idle"
            },
            currentPermissionSummary: { [weak self] in
                self?.permissionSummary ?? ""
            },
            currentCapabilitySummary: { [weak self] in
                self?.capabilitySummary ?? ""
            },
            currentUpdaterStatusText: { [weak self] in
                self?.updaterStatusText ?? ""
            },
            currentLicenseStatusText: { [weak self] in
                self?.licenseStatusText ?? ""
            },
            currentDebugModeEnabled: { [weak self] in
                self?.debugModeEnabled ?? false
            },
            currentDiagnosticsText: { [weak self] in
                self?.diagnosticsText ?? ""
            },
            currentDebugLogText: { [weak self] in
                self?.debugLogText ?? ""
            },
            setDiagnosticsText: { [weak self] value in
                self?.diagnosticsText = value
            },
            setDebugLogText: { [weak self] value in
                self?.debugLogText = value
            }
        )

        self.permissionCoordinator = PermissionCoordinator(
            permissionController: permissionController,
            dictationRuntime: dictationRuntime,
            currentMicrophonePermissionStatus: { [weak self] in
                self?.microphonePermissionStatus ?? .notDetermined
            },
            setMicrophonePermissionStatus: { [weak self] status in
                self?.microphonePermissionStatus = status
            },
            currentAccessibilityPermissionStatus: { [weak self] in
                self?.accessibilityPermissionStatus ?? .notDetermined
            },
            setAccessibilityPermissionStatus: { [weak self] status in
                self?.accessibilityPermissionStatus = status
            },
            registerSelectedHotkey: { [weak self] force in
                self?.registerSelectedHotkey(force: force)
            },
            appendDiagnostic: { [weak self] line in
                self?.appendDiagnostic(line)
            },
            appendDebug: { [weak self] line in
                self?.appendDebug(line)
            },
            isDebugModeEnabled: { [weak self] in
                self?.debugModeEnabled ?? false
            }
        )

        let lifecycleCoordinator = AppLifecycleCoordinator(
            onRefreshPermissionStates: { [weak self] in
                self?.refreshPermissionStates()
            },
            onRefreshPermissionsAfterExternalEvent: { [weak self] reason in
                self?.permissionCoordinator.refreshPermissionsAfterExternalEvent(reason: reason)
            },
            onRefreshOperationalState: { [weak self] reason in
                self?.refreshOperationalState(reason: reason)
            }
        )
        self.appLifecycleCoordinator = lifecycleCoordinator

        self.sessionEntryController = SessionEntryController(
            dictationRuntime: dictationRuntime,
            currentStartOptions: { [weak self] in
                self?.currentStartOptions() ?? DictationStartOptions(
                    mode: .finalize,
                    language: .german,
                    translationOutput: .original,
                    performance: .auto,
                    selectedVoiceProviderID: LocalVoiceModelCatalog.defaultProviderID,
                    selectedVoiceModelID: LocalVoiceModelCatalog.defaultModelID,
                    liveRewriteScope: .currentSentence,
                    snippetRules: [],
                    finalResultDeliveryMode: .insert,
                    clipboardFallbackWhenNoTarget: false,
                    simulateKeypresses: false,
                    restoreClipboardAfterPaste: false,
                    autoSendAfterPaste: false,
                    muteMusicWhileDictating: false,
                    asrInitialPrompt: nil,
                    dictionaryTerms: [],
                    liveContextText: nil,
                    finalContextText: nil,
                    aiProcessing: AIProcessingConfiguration(enabled: false, selectedModelID: nil),
                    audioProcessing: AudioProcessingConfiguration(),
                    soundFeedback: SoundFeedbackConfiguration()
                )
            },
            refreshPermissionStates: { [weak self] in
                self?.refreshPermissionStates()
            },
            dictationCapabilityAllowsDirectInsertion: { [weak self] in
                self?.dictationCapability.allowsDirectInsertion ?? false
            },
            lastExternalApplication: { lifecycleCoordinator.lastExternalApplication },
            appendAudit: { [weak self] line in
                self?.appendAudit(line)
            },
            appendDiagnostic: { [weak self] line in
                self?.appendDiagnostic(line)
            },
            currentRecordingStatus: { [weak self] in
                self?.recordingStatus ?? "Idle"
            },
            currentSelectedLanguageRawValue: { [weak self] in
                self?.selectedLanguage.rawValue ?? DictationLanguage.german.rawValue
            },
            currentPerformanceProfileRawValue: { [weak self] in
                self?.performanceProfile.rawValue ?? DictationPerformance.auto.rawValue
            },
            currentDictationCapability: { [weak self] in
                self?.dictationCapability ?? .unavailable
            },
            isSessionActive: { [weak self] in
                self?.isSessionActive ?? false
            },
            holdToDictateEnabled: { [weak self] in
                self?.holdToDictateEnabled ?? false
            }
        )

        self.transcriptHistoryController = TranscriptHistoryController(
            historyStore: self.historyStore,
            currentTranscriptHistory: { [weak self] in
                self?.transcriptHistory ?? []
            },
            setTranscriptHistory: { [weak self] entries in
                self?.transcriptHistory = entries
            },
            currentHistoryRetentionPolicy: { [weak self] in
                self?.historyRetentionPolicy ?? .forever
            },
            appendDiagnostic: { [weak self] line in
                self?.appendDiagnostic(line)
            },
            appendAudit: { [weak self] line in
                self?.appendAudit(line)
            }
        )

        self.snippetController = SnippetController(
            snippetStore: self.snippetStore,
            currentSnippetRules: { [weak self] in
                self?.snippetRules ?? []
            },
            setSnippetRules: { [weak self] rules in
                self?.snippetRules = rules
            },
            currentSelectedLanguageLocaleIdentifier: { [weak self] in
                self?.selectedLanguage.locale.identifier ?? DictationLanguage.german.locale.identifier
            },
            appendDiagnostic: { [weak self] line in
                self?.appendDiagnostic(line)
            },
            appendAudit: { [weak self] line in
                self?.appendAudit(line)
            }
        )

        self.aiProviderController = AIProviderController(
            aiRemoteProviderSecretStore: aiRemoteProviderSecretStore,
            dictationRuntime: dictationRuntime,
            currentRemoteProviders: { [weak self] in
                self?.remoteProviders ?? []
            },
            setRemoteProviders: { [weak self] providers in
                self?.remoteProviders = providers
            },
            currentSelectedRemoteProviderID: { [weak self] in
                self?.selectedRemoteProviderID
            },
            setSelectedRemoteProviderID: { [weak self] providerID in
                self?.selectedRemoteProviderID = providerID
            },
            currentRemoteProviderAPIKeyDraft: { [weak self] in
                self?.remoteProviderAPIKeyDraft ?? ""
            },
            setRemoteProviderAPIKeyDraft: { [weak self] apiKey in
                self?.remoteProviderAPIKeyDraft = apiKey
            },
            currentSelectedAIModelID: { [weak self] in
                self?.selectedAIModelID
            },
            setSelectedAIModelID: { [weak self] modelID in
                self?.selectedAIModelID = modelID
            },
            currentAIProcessingEnabled: { [weak self] in
                self?.aiProcessingEnabled ?? false
            },
            setAIProcessingEnabled: { [weak self] isEnabled in
                self?.aiProcessingEnabled = isEnabled
            },
            setAIModels: { [weak self] models in
                self?.aiModels = models
            },
            persistRemoteProviders: { [weak self] in
                self?.persistRemoteProviders()
            },
            appendDiagnostic: { [weak self] line in
                self?.appendDiagnostic(line)
            },
            appendAudit: { [weak self] line in
                self?.appendAudit(line)
            }
        )

        self.speechModelController = SpeechModelController(
            voiceModelInstaller: self.voiceModelInstaller,
            currentSelectedLanguage: { [weak self] in
                self?.selectedLanguage ?? .german
            },
            setSelectedLanguage: { [weak self] language in
                self?.selectedLanguage = language
            },
            currentTranslationOutputMode: { [weak self] in
                self?.translationOutputMode ?? .original
            },
            setTranslationOutputMode: { [weak self] mode in
                self?.translationOutputMode = mode
            },
            currentSelectedVoiceProviderID: { [weak self] in
                self?.selectedVoiceProviderID ?? LocalVoiceModelCatalog.defaultProviderID
            },
            setSelectedVoiceProviderID: { [weak self] providerID in
                self?.selectedVoiceProviderID = providerID
            },
            currentSelectedVoiceModelID: { [weak self] in
                self?.selectedVoiceModelID ?? LocalVoiceModelCatalog.defaultModelID
            },
            setSelectedVoiceModelID: { [weak self] modelID in
                self?.selectedVoiceModelID = modelID
            },
            currentVoiceLanguageOverrides: { [weak self] in
                self?.voiceLanguageOverrides ?? []
            },
            setVoiceLanguageOverrides: { [weak self] overrides in
                self?.voiceLanguageOverrides = overrides
            },
            currentVoiceProviders: { [weak self] in
                self?.voiceProviders ?? []
            },
            setVoiceProviders: { [weak self] providers in
                self?.voiceProviders = providers
            },
            currentVoiceModels: { [weak self] in
                self?.voiceModels ?? []
            },
            setVoiceModels: { [weak self] models in
                self?.voiceModels = models
            },
            currentInstalledVoiceModelFileNames: { [weak self] in
                self?.installedVoiceModelFileNames ?? []
            },
            setInstalledVoiceModelFileNames: { [weak self] fileNames in
                self?.installedVoiceModelFileNames = fileNames
            },
            currentVoiceModelOperationInFlightIDs: { [weak self] in
                self?.voiceModelOperationInFlightIDs ?? []
            },
            setVoiceModelOperationInFlightIDs: { [weak self] ids in
                self?.voiceModelOperationInFlightIDs = ids
            },
            appendDiagnostic: { [weak self] line in
                self?.appendDiagnostic(line)
            }
        )

        refreshVoiceModelCatalog()
        sanitizeAIProcessingSelections()
        sanitizeSpeechModelSelections()
        sanitizeVisibleMenuBarLanguages()

        dictationRuntime.onStatus = { [weak self] status in
            self?.recordingStatus = status
            if status != "Recording" {
                self?.sessionEntryController.resetHoldSessionActive()
            }
        }
        dictationRuntime.onSessionActivityChanged = { [weak self] isActive in
            self?.isSessionActive = isActive
            if !isActive {
                self?.sessionEntryController.resetHoldSessionActive()
            }
        }
        dictationRuntime.onDiagnostic = { [weak self] diagnostic in
            self?.appendDiagnostic(diagnostic)
        }
        dictationRuntime.onDebugEvent = { [weak self] diagnostic in
            self?.appendDebug(diagnostic)
        }
        dictationRuntime.onTranscript = { [weak self] transcript in
            self?.lastTranscript = transcript
        }
        dictationRuntime.onFinalTranscript = { [weak self] event in
            self?.transcriptHistoryController.handleFinalTranscript(event)
            self?.handleDictionaryCandidatesIfNeeded(from: event)
        }
        dictationRuntime.onPermissionInteractionFinished = { [weak self] in
            self?.permissionCoordinator.refreshPermissionStatesAfterUserFacingPermissionStep()
        }

        hotkeyManager.onToggle = { [weak self] in
            self?.sessionEntryController.toggleTranscriptionFromUI()
        }
        hotkeyManager.onHoldPress = { [weak self] in
            self?.sessionEntryController.handleHoldShortcutPressed()
        }
        hotkeyManager.onHoldRelease = { [weak self] in
            self?.sessionEntryController.handleHoldShortcutReleased()
        }
        hotkeyManager.onCancel = { [weak self] in
            self?.cancelTranscriptionFromUI()
        }
        hotkeyManager.onModeSwitch = { [weak self] in
            self?.toggleDictationModeFromShortcut()
        }
        registerSelectedHotkey(force: true)

        loadSnippets()
        loadDictionary()
        transcriptHistoryController.loadHistory()
        updateCapabilitySummary()
        rebuildAIProcessingStack(reason: "initial-load")
        updateUpdaterState()
        loadExistingLicense()
        dictationRuntime.setVoiceModelActiveDuration(voiceModelActiveDuration)
        dictationRuntime.prepareRuntime()
        refreshPermissionStates()
        if !skipStartupSystemHooks {
            DispatchQueue.main.async { [weak self] in
                self?.refreshPermissionStates()
            }
            applyActivationPolicy()
            syncLaunchOnLogin()
            lifecycleCoordinator.start()
        }
    }

    deinit {
        dockPolicySettingsReopenWorkItem?.cancel()
    }

    private func sanitizeAIProcessingSelections() {
        if !aiTaskCleanupEnabled && !aiTaskToneEnabled && !aiTaskSalutationEnabled
            && !aiTaskFormatEnabled
        {
            aiTaskCleanupEnabled = true
            if aiCleanupIntensity < 0.05 {
                aiCleanupIntensity = 0.5
            }
        }

        if !aiFormattingMode.allowedWritingStyles.contains(aiWritingStyle) {
            aiWritingStyle = .none
        }

        if !aiFormattingMode.supportsSalutation && aiSalutation != .none {
            aiSalutation = .none
        }

        aiRevisionGoal = aiDerivedRevisionGoal
    }

    private func sanitizeSpeechModelSelections() {
        speechModelController.sanitizeSpeechModelSelections()
    }

    func sanitizeVisibleMenuBarLanguages() {
        let allowed = Set(DictationLanguage.allCases.filter { $0 != .auto }.map(\.rawValue))
        var filtered = visibleMenuBarLanguages.filter { allowed.contains($0) }
        if filtered.isEmpty {
            filtered = DictationLanguage.allCases.filter { $0 != .auto }.map(\.rawValue)
        }
        if filtered != visibleMenuBarLanguages {
            visibleMenuBarLanguages = filtered
            userDefaults.set(filtered, forKey: UserDefaultsKeys.visibleMenuBarLanguages)
        }
    }

    func openMicrophoneSettings() {
        permissionCoordinator.openMicrophoneSettings()
    }

    func openAccessibilitySettings() {
        permissionCoordinator.openAccessibilitySettings()
    }

    func addSnippet(trigger: String, replacement: String) {
        snippetController.addSnippet(trigger: trigger, replacement: replacement)
    }

    func removeSnippet(ruleID: UUID) {
        snippetController.removeSnippet(ruleID: ruleID)
    }

    func importSnippetsFromJSON() {
        snippetController.importSnippetsFromJSON()
    }

    func exportSnippetsToJSON() {
        snippetController.exportSnippetsToJSON()
    }

    func copyHistoryEntry(_ entry: TranscriptHistoryEntry) {
        transcriptHistoryController.copyHistoryEntry(entry)
    }

    func copyAllHistoryToClipboard() {
        transcriptHistoryController.copyAllHistoryToClipboard()
    }

    func exportHistoryAsText() {
        transcriptHistoryController.exportHistoryAsText()
    }

    func removeHistoryEntry(_ entryID: UUID) {
        transcriptHistoryController.removeHistoryEntry(entryID)
    }

    func clearHistory() {
        transcriptHistoryController.clearHistory()
    }

    func exportDiagnosticsReport() {
        diagnosticsController.exportDiagnosticsReport()
    }

    func exportAuditLog() {
        diagnosticsController.exportAuditLog()
    }

    /// Ein Block für die Zwischenablage: Diagnose + technisches Protokoll (z. B. Smoke-Test / Support).
    func diagnosticsAndDebugCombinedForClipboard() -> String {
        diagnosticsController.diagnosticsAndDebugCombinedForClipboard()
    }

    func exportDebugLog() {
        diagnosticsController.exportDebugLog()
    }

    func checkForUpdates() {
        checkForUpdatesHandler?()
        if checkForUpdatesHandler == nil {
            appendDiagnostic("Updater ist nicht konfiguriert.")
        }
    }

    func activateLicense() {
        let snapshot = licenseController.activate(licenseKey: licenseInput)
        applyLicenseSnapshot(snapshot, clearInput: snapshot.isValid)

        if case .active(let tier) = snapshot.status {
            appendAudit("license.activate tier=\(tier)")
        }
    }

    func deactivateLicense() {
        licenseController.deactivate()
        applyLicenseSnapshot(
            LicenseStatusSnapshot(status: .notSet, maskedKey: nil), clearInput: true)
        appendAudit("license.deactivate")
    }

    private func loadExistingLicense() {
        let snapshot = licenseController.loadExistingStatus()
        applyLicenseSnapshot(snapshot, clearInput: true)
    }

    private func applyLicenseSnapshot(_ snapshot: LicenseStatusSnapshot, clearInput: Bool) {
        if clearInput {
            licenseInput = ""
        }

        storedLicenseSummary = snapshot.maskedKey
        licenseValid = snapshot.isValid

        switch snapshot.status {
        case .notConfigured:
            licenseStatusText = "Lizenzprüfung nicht konfiguriert"
            licensePresentationState = .notConfigured
        case .notSet:
            licenseStatusText = "Keine Lizenz gesetzt"
            licensePresentationState = .notSet
        case .active(let tier):
            licenseStatusText = "Aktiv: \(tier)"
            licensePresentationState = .active(tier: tier)
        case .invalid(let reason):
            licenseStatusText = "Ungültig: \(reason)"
            licensePresentationState = .invalid(reason: reason)
        }
    }

    private func loadSnippets() {
        snippetController.loadSnippets()
    }

    private func persistSnippets() {
        snippetController.persistSnippets()
    }

    func addDictionaryTerm(
        _ rawTerm: String,
        category: DictionaryTermCategory,
        source: DictionaryTermSource = .manual,
        languageCode: String? = nil
    ) {
        let term = rawTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else {
            appendDiagnostic("Dictionary: Begriff wurde nicht gespeichert (leer).")
            return
        }

        let key = normalizedDictionaryKey(term, languageCode: languageCode)
        if dictionaryTerms.contains(where: {
            normalizedDictionaryKey($0.term, languageCode: $0.languageCode) == key
        }) {
            appendDiagnostic("Dictionary: Begriff bereits vorhanden.")
            return
        }

        dictionaryTerms.append(
            DictionaryTerm(
                term: term,
                category: category,
                source: source,
                languageCode: languageCode
            )
        )

        dictionaryReviewQueue.removeAll {
            normalizedDictionaryKey($0.proposedTerm, languageCode: $0.languageCode) == key
        }
        persistDictionary()
    }

    func removeDictionaryTerm(termID: UUID) {
        dictionaryTerms.removeAll { $0.id == termID }
        persistDictionary()
    }

    func queueDictionaryCandidate(
        _ rawTerm: String,
        category: DictionaryTermCategory = .custom,
        languageCode: String? = nil
    ) {
        let term = rawTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return }

        let key = normalizedDictionaryKey(term, languageCode: languageCode)
        guard !dictionaryTerms.contains(where: {
            normalizedDictionaryKey($0.term, languageCode: $0.languageCode) == key
        }) else { return }
        guard !dictionaryReviewQueue.contains(where: {
            normalizedDictionaryKey($0.proposedTerm, languageCode: $0.languageCode) == key
        }) else { return }

        dictionaryReviewQueue.insert(
            DictionaryReviewCandidate(
                proposedTerm: term,
                category: category,
                languageCode: languageCode
            ),
            at: 0
        )
        persistDictionary()
    }

    func approveDictionaryCandidate(_ candidateID: UUID) {
        guard let candidate = dictionaryReviewQueue.first(where: { $0.id == candidateID }) else {
            return
        }
        addDictionaryTerm(
            candidate.proposedTerm,
            category: candidate.category,
            source: .auto,
            languageCode: candidate.languageCode
        )
    }

    func rejectDictionaryCandidate(_ candidateID: UUID) {
        dictionaryReviewQueue.removeAll { $0.id == candidateID }
        persistDictionary()
    }

    func importDictionaryFromJSON() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.json]

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let snapshot = try dictionaryStore.importSnapshot(from: url)
            dictionaryTerms = snapshot.terms
            dictionaryReviewQueue = snapshot.reviewQueue
            appendDiagnostic(
                "Dictionary importiert: \(dictionaryTerms.count) Begriffe, \(dictionaryReviewQueue.count) Vorschläge"
            )
            appendAudit("dictionary.import path=\(url.path)")
        } catch {
            appendDiagnostic("Dictionary-Import fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    func exportDictionaryToJSON() {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "wispr-dictionary.json"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try dictionaryStore.exportSnapshot(
                PersonalDictionarySnapshot(
                    terms: dictionaryTerms,
                    reviewQueue: dictionaryReviewQueue
                ),
                to: url
            )
            appendDiagnostic("Dictionary exportiert: \(dictionaryTerms.count) Begriffe")
            appendAudit("dictionary.export path=\(url.path)")
        } catch {
            appendDiagnostic("Dictionary-Export fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    private func loadHistory() {
        transcriptHistoryController.loadHistory()
    }

    private func persistHistory() {
        transcriptHistoryController.persistHistory()
    }

    private func loadDictionary() {
        do {
            let snapshot = try dictionaryStore.load()
            dictionaryTerms = snapshot.terms
            dictionaryReviewQueue = snapshot.reviewQueue
            appendDiagnostic(
                "Dictionary geladen: \(dictionaryTerms.count) Begriffe, \(dictionaryReviewQueue.count) Vorschläge"
            )
        } catch {
            appendDiagnostic("Dictionary-Load fehlgeschlagen: \(error.localizedDescription)")
            dictionaryTerms = []
            dictionaryReviewQueue = []
        }
    }

    private func persistDictionary() {
        do {
            try dictionaryStore.save(terms: dictionaryTerms, reviewQueue: dictionaryReviewQueue)
            appendAudit(
                "dictionary.save terms=\(dictionaryTerms.count) queue=\(dictionaryReviewQueue.count)"
            )
        } catch {
            appendDiagnostic("Dictionary-Save fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    private func pruneHistoryIfNeeded() {
        transcriptHistoryController.pruneHistoryIfNeeded()
    }

    private func updateCapabilitySummary() {
        let profile = capabilityProfiler.profile()
        let memoryGB = Double(profile.physicalMemoryBytes) / 1_073_741_824
        capabilitySummary =
            "CPU: \(profile.activeProcessorCount)/\(profile.processorCount), RAM: \(String(format: "%.1f", memoryGB)) GB, Thermal: \(profile.thermalState)"
    }

    func refreshPermissionStates() {
        permissionCoordinator.refreshPermissionStates()
    }

    private func refreshPermissionsAfterExternalEvent(reason: String) {
        permissionCoordinator.refreshPermissionsAfterExternalEvent(reason: reason)
    }

    /// TCC aktualisiert manchmal verzögert – einmal sofort und einmal kurz danach erneut lesen.
    private func refreshPermissionStatesAfterUserFacingPermissionStep() {
        permissionCoordinator.refreshPermissionStatesAfterUserFacingPermissionStep()
    }

    /// Aus den Einstellungen: System-Mikrofondialog oder Privacy-Panel.
    func requestMicrophoneAccessFromSettings() {
        permissionCoordinator.requestMicrophoneAccessFromSettings()
    }

    /// Aus den Einstellungen: AX-Bestätigungsdialog anstoßen und Status neu lesen.
    func requestAccessibilityAccessFromSettings() {
        permissionCoordinator.requestAccessibilityAccessFromSettings()
    }

    func appendDiagnostic(_ line: String) {
        diagnosticsController.appendDiagnostic(line)
    }

    private func appendDebug(_ line: String) {
        diagnosticsController.appendDebug(line)
    }

    func appendAudit(_ line: String) {
        diagnosticsController.appendAudit(line)
    }

    private func currentStartOptions() -> DictationStartOptions {
        sessionConfigurationBuilder.build(from: sessionConfigurationInput())
    }

    private func sessionConfigurationInput() -> SessionConfigurationInput {
        let liveContextText = contextAwarenessMode.appliesToLive
            ? bestEffortFocusedContextText(maxLength: 220)
            : nil
        let finalContextText = contextAwarenessMode.appliesToFinal
            ? bestEffortFocusedContextText(maxLength: 600)
            : nil

        return SessionConfigurationInput(
            streamingEnabled: streamingEnabled,
            selectedLanguage: selectedLanguage,
            translationOutputMode: translationOutputMode,
            performanceProfile: performanceProfile,
            selectedVoiceProviderID: selectedVoiceProviderID,
            selectedVoiceModelID: selectedVoiceModelID,
            voiceLanguageOverrides: voiceLanguageOverrides,
            voiceModels: voiceModels,
            installedVoiceModelFileNames: installedVoiceModelFileNames,
            liveRewriteScope: liveRewriteScope,
            snippetRules: snippetRules,
            finalResultDeliveryMode: finalResultDeliveryMode,
            clipboardFallbackWhenNoTarget: clipboardFallbackWhenNoTarget,
            simulateKeypresses: simulateKeypresses,
            restoreClipboardAfterPaste: restoreClipboardAfterPaste,
            autoSendAfterPaste: autoSendAfterPaste,
            muteMusicWhileDictating: muteMusicWhileDictating,
            asrInitialPrompt: buildDictionaryHintPrompt(),
            dictionaryTerms: dictionaryTerms.map(\.term),
            liveContextText: liveContextText,
            finalContextText: finalContextText,
            aiProcessing: aiProcessingConfiguration,
            audioProcessing: audioProcessingConfiguration,
            soundFeedback: soundFeedbackConfiguration
        )
    }

    private func refreshOperationalState(reason: String) {
        registerSelectedHotkey(force: true)
        updateCapabilitySummary()
        rebuildAIProcessingStack(reason: reason)
        permissionCoordinator.refreshPermissionsAfterExternalEvent(reason: reason)
        dictationRuntime.prepareRuntime()
        updateUpdaterState()
        appendAudit("lifecycle.refresh reason=\(reason)")
    }

    private func persistRemoteProviders() {
        preferencesStore.saveRemoteProviders(remoteProviders)
    }

    private func persistVoiceLanguageOverrides() {
        preferencesStore.saveVoiceLanguageOverrides(voiceLanguageOverrides)
    }

    private func rebuildAIProcessingStack(reason: String) {
        aiProviderController.rebuildAIProcessingStack(reason: reason)
    }

    private func registerSelectedHotkey(force: Bool) {
        let effectiveCancelShortcutEnabled =
            cancelShortcutEnabled
            && !(toggleShortcutEnabled && cancelShortcut == selectedHotkey)
            && !(holdToDictateEnabled && cancelShortcut == holdShortcut)
        let effectiveModeSwitchShortcutEnabled =
            modeSwitchShortcutEnabled
            && !(toggleShortcutEnabled && modeSwitchShortcut == selectedHotkey)
            && !(holdToDictateEnabled && modeSwitchShortcut == holdShortcut)
            && !(effectiveCancelShortcutEnabled && modeSwitchShortcut == cancelShortcut)

        let didRegister = hotkeyManager.register(
            shortcut: selectedHotkey,
            shortcutEnabled: toggleShortcutEnabled,
            holdShortcut: holdShortcut,
            holdEnabled: holdToDictateEnabled,
            cancelShortcut: cancelShortcut,
            cancelEnabled: effectiveCancelShortcutEnabled,
            modeShortcut: modeSwitchShortcut,
            modeEnabled: effectiveModeSwitchShortcutEnabled,
            force: force
        )
        if didRegister {
            appendDiagnostic(
                toggleShortcutEnabled
                    ? "Globaler Shortcut aktiv: \(selectedHotkey.displayName)"
                    : "Globaler Shortcut deaktiviert."
            )
            appendDiagnostic(
                holdToDictateEnabled
                    ? "Hold-to-dictate aktiv: \(holdShortcut.displayName)"
                    : "Hold-to-dictate deaktiviert."
            )
            appendDiagnostic(
                effectiveCancelShortcutEnabled
                    ? "Abbrechen-Shortcut aktiv: \(cancelShortcut.displayName)"
                    : cancelShortcutEnabled
                        ? "Abbrechen-Shortcut wegen Konflikt nicht registriert."
                        : "Abbrechen-Shortcut deaktiviert."
            )
            appendDiagnostic(
                effectiveModeSwitchShortcutEnabled
                    ? "Moduswechsel-Shortcut aktiv: \(modeSwitchShortcut.displayName)"
                    : modeSwitchShortcutEnabled
                        ? "Moduswechsel-Shortcut wegen Konflikt nicht registriert."
                        : "Moduswechsel-Shortcut deaktiviert."
            )
            if let hotkeyAdvisory {
                appendDiagnostic(
                    "Shortcut-Hinweis: \(hotkeyAdvisory.title) – \(hotkeyAdvisory.message)")
            }
            if holdToDictateEnabled, let holdShortcutAdvisory {
                appendDiagnostic(
                    "Hold-Hinweis: \(holdShortcutAdvisory.title) – \(holdShortcutAdvisory.message)")
            }
            if cancelShortcutEnabled, let cancelShortcutAdvisory {
                appendDiagnostic(
                    "Abbrechen-Hinweis: \(cancelShortcutAdvisory.title) – \(cancelShortcutAdvisory.message)"
                )
            }
            if modeSwitchShortcutEnabled, let modeSwitchShortcutAdvisory {
                appendDiagnostic(
                    "Modus-Hinweis: \(modeSwitchShortcutAdvisory.title) – \(modeSwitchShortcutAdvisory.message)"
                )
            }
            appendAudit(
                "hotkey.register value=\(selectedHotkey.rawValue) enabled=\(toggleShortcutEnabled) hold=\(holdShortcut.rawValue) holdEnabled=\(holdToDictateEnabled) cancel=\(cancelShortcut.rawValue) cancelEnabled=\(cancelShortcutEnabled) cancelEffective=\(effectiveCancelShortcutEnabled) mode=\(modeSwitchShortcut.rawValue) modeEnabled=\(modeSwitchShortcutEnabled) modeEffective=\(effectiveModeSwitchShortcutEnabled)"
            )
        } else {
            appendDiagnostic(
                "Globaler Shortcut konnte nicht registriert werden: \(selectedHotkey.displayName)")
            appendAudit("hotkey.register_failed value=\(selectedHotkey.rawValue)")
        }
    }

    /// - Returns: `true` if activation policy was changed successfully (caller may refresh UI such as the settings window).
    @discardableResult
    private func applyActivationPolicy() -> Bool {
        let targetPolicy: NSApplication.ActivationPolicy = showInDock ? .regular : .accessory
        let app = NSApplication.shared
        guard app.activationPolicy() != targetPolicy else {
            return false
        }
        let ok = app.setActivationPolicy(targetPolicy)
        if !ok {
            appendDiagnostic(
                "Die Aktivierungsrichtlinie konnte nicht auf \(showInDock ? "Dock" : "nur Menüleiste") umgestellt werden."
            )
        }
        return ok
    }

    private func scheduleSettingsReopenAfterDockPolicyChange() {
        guard openSettingsHandler != nil else { return }
        dockPolicySettingsReopenWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.dockPolicySettingsReopenWorkItem = nil
            self.openSettingsHandler?()
        }
        dockPolicySettingsReopenWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.065, execute: work)
    }

    private func syncLaunchOnLogin() {
        do {
            if launchOnLoginEnabled {
                if #available(macOS 13.0, *), SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                    appendDiagnostic("Anmeldung beim Systemstart aktiviert.")
                }
            } else if #available(macOS 13.0, *), SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
                appendDiagnostic("Anmeldung beim Systemstart deaktiviert.")
            }
        } catch {
            appendDiagnostic(
                "Anmeldung beim Systemstart konnte nicht aktualisiert werden: \(error.localizedDescription)"
            )
        }
    }

    func syncAutomaticUpdateChecks() {
        updaterController?.setAutomaticallyChecksEnabled(automaticallyCheckForUpdates)
    }

    private func updateUpdaterState() {
        updaterConfigured = appConfiguration.isUpdaterConfigured
        updaterFeedURLText = appConfiguration.sparkleFeedURL?.absoluteString ?? ""
        updaterStatusText =
            appConfiguration.isUpdaterConfigured
            ? "Updater konfiguriert"
            : "Updater nicht konfiguriert"
    }

    private static func displayDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }

    private static func summarize(_ text: String, limit: Int = 120) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > limit else {
            return trimmed
        }
        return "\(trimmed.prefix(limit))…"
    }

    private static func stripDiagnosticPrefix(_ diagnostic: String) -> String {
        guard let closingBracket = diagnostic.firstIndex(of: "]") else {
            return diagnostic
        }
        let nextIndex = diagnostic.index(after: closingBracket)
        return diagnostic[nextIndex...].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func latestDiagnosticLine(from diagnostics: String) -> String {
        diagnostics
            .split(separator: "\n", omittingEmptySubsequences: true)
            .last
            .map(String.init) ?? diagnostics
    }

    private func handleDictionaryCandidatesIfNeeded(from event: FinalTranscriptEvent) {
        guard dictionaryAutoAddEnabled else { return }
        let added = autoQueueDictionaryCandidates(from: event.text, languageCode: event.languageCode)
        if added > 0 {
            appendDiagnostic("Dictionary-Vorschläge ergänzt: \(added)")
        }
    }

    private func autoQueueDictionaryCandidates(from text: String, languageCode: String) -> Int {
        let before = dictionaryReviewQueue.count
        let normalizedLanguage = languageCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let scopedLanguage = normalizedLanguage.isEmpty ? nil : normalizedLanguage
        let maxNewCandidates = 8
        var added = 0
        var seenInTranscript = Set<String>()

        for phrase in matchedTerms(
            in: text,
            pattern: #"\b[A-ZÄÖÜ][\p{L}]{2,}\s+[A-ZÄÖÜ][\p{L}]{2,}\b"#
        ) {
            guard shouldAutoSuggestPersonPhrase(phrase) else { continue }
            let key = normalizedDictionaryKey(phrase, languageCode: scopedLanguage)
            guard !seenInTranscript.contains(key) else { continue }
            seenInTranscript.insert(key)
            let queueCountBefore = dictionaryReviewQueue.count
            queueDictionaryCandidate(phrase, category: .personName, languageCode: scopedLanguage)
            if dictionaryReviewQueue.count > queueCountBefore {
                added += 1
            }
            if added >= maxNewCandidates {
                return max(0, dictionaryReviewQueue.count - before)
            }
        }

        for token in matchedTerms(in: text, pattern: #"\b[\p{L}\d][\p{L}\d\-\._]{2,}\b"#) {
            let normalizedToken = normalizeDictionaryCandidate(token)
            guard shouldAutoSuggestDictionaryToken(normalizedToken) else { continue }
            let key = normalizedDictionaryKey(normalizedToken, languageCode: scopedLanguage)
            guard !seenInTranscript.contains(key) else { continue }
            seenInTranscript.insert(key)
            let category: DictionaryTermCategory =
                if normalizedToken.contains(where: { $0.isNumber }) || isUppercaseAcronym(normalizedToken) {
                    .industryLanguage
                } else {
                    .custom
                }
            let queueCountBefore = dictionaryReviewQueue.count
            queueDictionaryCandidate(
                normalizedToken,
                category: category,
                languageCode: scopedLanguage
            )
            if dictionaryReviewQueue.count > queueCountBefore {
                added += 1
            }
            if added >= maxNewCandidates {
                break
            }
        }

        return max(0, dictionaryReviewQueue.count - before)
    }

    private func matchedTerms(in text: String, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }

        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, options: [], range: nsRange)
        return matches.compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            return String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private func shouldAutoSuggestDictionaryToken(_ token: String) -> Bool {
        guard token.count >= 3, token.count <= 40 else { return false }
        guard !isLikelyCommonWord(token) else { return false }

        if isUppercaseAcronym(token) {
            return true
        }
        if token.contains(where: { $0.isNumber }) && token.contains(where: { $0.isLetter }) {
            return true
        }
        guard let first = token.first, first.isUppercase else {
            return false
        }
        return token.dropFirst().contains(where: { $0.isUppercase })
    }

    private func isUppercaseAcronym(_ token: String) -> Bool {
        let letters = token.filter(\.isLetter)
        guard letters.count >= 2 else { return false }
        return letters == letters.uppercased()
    }

    private func shouldAutoSuggestPersonPhrase(_ phrase: String) -> Bool {
        let components = phrase.split(whereSeparator: \.isWhitespace).map(String.init)
        guard components.count == 2 else { return false }
        guard components.allSatisfy({ !$0.isEmpty && !$0.contains(where: { $0.isNumber }) }) else {
            return false
        }
        guard components.allSatisfy({ !isLikelyCommonWord($0) }) else { return false }
        return true
    }

    private func normalizeDictionaryCandidate(_ candidate: String) -> String {
        candidate.trimmingCharacters(
            in: CharacterSet(charactersIn: " \t\n\r.,;:!?()[]{}\"'")
        )
    }

    private func isLikelyCommonWord(_ token: String) -> Bool {
        let normalized = token
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
        return Self.commonAutoAddStopwords.contains(normalized)
    }

    private func normalizedDictionaryKey(_ term: String, languageCode: String?) -> String {
        let normalizedTerm = term
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let normalizedLanguage = languageCode?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? "*"
        return "\(normalizedLanguage)|\(normalizedTerm)"
    }

    private func buildDictionaryHintPrompt(maxCharacters: Int = 320) -> String? {
        let currentLanguageCode = selectedLanguage == .auto ? nil : selectedLanguage.rawValue
        let filtered = dictionaryTerms
            .filter { term in
                guard
                    let languageCode = term.languageCode?
                        .trimmingCharacters(in: .whitespacesAndNewlines),
                    !languageCode.isEmpty
                else {
                    return true
                }
                guard let currentLanguageCode else { return true }
                return languageCode.caseInsensitiveCompare(currentLanguageCode) == .orderedSame
            }
            .map(\.term)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !filtered.isEmpty else { return nil }

        var result = "Preferred terms: "
        for term in filtered {
            let candidate = result == "Preferred terms: " ? "\(result)\(term)" : "\(result), \(term)"
            if candidate.count > maxCharacters { break }
            result = candidate
        }

        return result == "Preferred terms: " ? nil : result
    }

    private func bestEffortFocusedContextText(maxLength: Int) -> String? {
        guard accessibilityPermissionStatus == .granted else { return nil }

        let systemWide = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        let focusedResult = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedRef
        )

        guard focusedResult == .success, let focusedRef else {
            return nil
        }
        let focusedElement = focusedRef as! AXUIElement

        var valueRef: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(
                focusedElement,
                kAXValueAttribute as CFString,
                &valueRef
            ) == .success,
            let fullText = valueRef as? String
        else {
            return nil
        }

        let trimmed = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var selectedRangeRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(
            focusedElement,
            kAXSelectedTextRangeAttribute as CFString,
            &selectedRangeRef
        ) == .success,
            let axValue = selectedRangeRef,
            CFGetTypeID(axValue) == AXValueGetTypeID()
        {
            let selectedRangeValue = axValue as! AXValue
            var range = CFRange(location: 0, length: 0)
            if AXValueGetType(selectedRangeValue) == .cfRange,
                AXValueGetValue(selectedRangeValue, .cfRange, &range)
            {
                return contextWindow(
                    in: fullText,
                    cursorLocation: max(0, range.location),
                    maxLength: maxLength
                )
            }
        }

        if trimmed.count <= maxLength {
            return trimmed
        }
        return String(trimmed.suffix(maxLength))
    }

    private func contextWindow(in text: String, cursorLocation: Int, maxLength: Int) -> String? {
        guard !text.isEmpty else { return nil }
        let safeCursor = min(max(0, cursorLocation), text.count)
        let beforeLength = maxLength / 2
        let afterLength = maxLength - beforeLength

        let startOffset = max(0, safeCursor - beforeLength)
        let endOffset = min(text.count, safeCursor + afterLength)

        let startIndex = text.index(text.startIndex, offsetBy: startOffset)
        let endIndex = text.index(text.startIndex, offsetBy: endOffset)
        let window = String(text[startIndex..<endIndex]).trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        return window.isEmpty ? nil : window
    }

    private static let commonAutoAddStopwords: Set<String> = [
        "aber", "als", "am", "an", "auch", "auf", "aus", "bei", "bin", "bist", "da", "dann",
        "das", "dein", "der", "des", "die", "dir", "doch", "du", "ein", "eine", "einer", "eines",
        "er", "es", "für", "hat", "hast", "hier", "ich", "im", "in", "ist", "ja", "kein", "mit",
        "nach", "nicht", "noch", "oder", "schon", "sein", "sind", "so", "und", "vom", "von",
        "war", "was", "wenn", "wie", "wir", "wird", "you", "your", "the", "this", "that", "and",
        "for", "from", "with", "have", "has", "are", "was", "were", "not", "but", "what", "when",
        "where", "which", "who", "why", "can", "could", "would", "should", "will",
    ]

    static func appSupportDirectory() -> URL {
        let fileManager = FileManager.default
        let base =
            (try? fileManager.url(
                for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil,
                create: true))
            ?? fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
        return base.appendingPathComponent("WisprLocal", isDirectory: true)
    }

    private static func snippetStorageURL() -> URL {
        appSupportDirectory().appendingPathComponent("snippets.json", isDirectory: false)
    }

    private static func historyStorageURL() -> URL {
        appSupportDirectory().appendingPathComponent("transcript-history.json", isDirectory: false)
    }

    private static func dictionaryStorageURL() -> URL {
        appSupportDirectory().appendingPathComponent("personal-dictionary.json", isDirectory: false)
    }

    private static func auditLogStorageURL() -> URL {
        appSupportDirectory().appendingPathComponent("audit.log", isDirectory: false)
    }

    private static func debugLogStorageURL() -> URL {
        appSupportDirectory().appendingPathComponent("debug.log", isDirectory: false)
    }

    private static func legacyLicenseCacheURL() -> URL {
        appSupportDirectory().appendingPathComponent("license-cache.json", isDirectory: false)
    }

    private static func currentLaunchOnLoginEnabled() -> Bool {
        #if canImport(ServiceManagement)
            if #available(macOS 13.0, *) {
                return SMAppService.mainApp.status == .enabled
            }
        #endif
        return false
    }
}

extension DictationRuntime: DictationRuntimeControlling {}

extension GlobalHotkeyManager: GlobalHotkeyRegistering {}

extension AIRemoteProviderSecretStore: AIRemoteProviderSecretStoring {}
