import AIProcessingCore
import ASRCore
import AVFoundation
import AppKit
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
        }
    }

    static func microphone(from status: AVAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .authorized:
            return .granted
        case .notDetermined:
            return .notDetermined
        default:
            return .denied
        }
    }

    static func accessibility(isTrusted: Bool) -> PermissionStatus {
        isTrusted ? .granted : .denied
    }
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
            applyActivationPolicy()
            reopenSettingsWindowAfterDockPolicyChange()
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

    var aiShowsModeControls: Bool {
        aiTaskToneEnabled || aiTaskSalutationEnabled || aiTaskFormatEnabled
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
        static let remoteProviders = "wispr.settings.ai.remoteProviders"
        static let selectedRemoteProviderID = "wispr.settings.ai.selectedRemoteProviderID"
    }

    private let userDefaults: UserDefaults
    private let hotkeyManager = GlobalHotkeyManager()
    private let dictationRuntime = DictationRuntime()
    private let snippetStore: SnippetStore
    private let historyStore: TranscriptHistoryStore
    private let auditLogger: AuditLogging
    private let debugLogger: AuditLogging
    private let permissionController: PermissionControlling
    private let capabilityProfiler = CapabilityProfiler()
    private let aiRemoteProviderSecretStore = AIRemoteProviderSecretStore()
    private let voiceModelInstaller = VoiceModelInstaller()
    private var aiProcessingService = AIProcessingService()
    private let appConfiguration: MacAppConfiguration

    private let licenseController: LicenseController
    private weak var updaterController: SparkleUpdaterController?
    private var didActivateApplicationObserver: NSObjectProtocol?
    private var didBecomeActiveObserver: NSObjectProtocol?
    private var didWakeObserver: NSObjectProtocol?
    private var permissionPollTask: Task<Void, Never>?
    private var accessibilityStatusDebounceTask: Task<Void, Never>?
    private var hasAppliedAccessibilityStatusOnce = false
    private var diagnosticLines: [String] = []
    private var checkForUpdatesHandler: (() -> Void)?
    private var lastExternalApplication: NSRunningApplication?
    private var openSettingsHandler: (() -> Void)?
    private var holdSessionActive = false
    private var debugLines: [String] = []

    init(
        userDefaults: UserDefaults = .standard,
        configuration: MacAppConfiguration = .load(),
        permissionController: PermissionControlling = PermissionController()
    ) {
        self.userDefaults = userDefaults
        self.appConfiguration = configuration
        self.permissionController = permissionController

        self.streamingEnabled =
            userDefaults.object(forKey: UserDefaultsKeys.streamingEnabled) as? Bool ?? true

        if let rawLanguage = userDefaults.string(forKey: UserDefaultsKeys.selectedLanguage),
            let parsedLanguage = DictationLanguage(rawValue: rawLanguage)
        {
            self.selectedLanguage = parsedLanguage
        } else {
            self.selectedLanguage = .german
        }

        if let rawTranslationOutputMode = userDefaults.string(
            forKey: UserDefaultsKeys.translationOutputMode),
            let parsedTranslationOutputMode = TranslationOutputMode(
                rawValue: rawTranslationOutputMode)
        {
            self.translationOutputMode = parsedTranslationOutputMode
        } else {
            self.translationOutputMode = .original
        }
        if let storedVisibleMenuBarLanguages = userDefaults.stringArray(
            forKey: UserDefaultsKeys.visibleMenuBarLanguages)
        {
            self.visibleMenuBarLanguages = storedVisibleMenuBarLanguages
        } else {
            self.visibleMenuBarLanguages = DictationLanguage.allCases
                .filter { $0 != .auto }
                .map(\.rawValue)
        }

        if let rawPerformance = userDefaults.string(forKey: UserDefaultsKeys.performanceProfile),
            let parsedPerformance = DictationPerformance(rawValue: rawPerformance)
        {
            self.performanceProfile = parsedPerformance
        } else {
            self.performanceProfile = .auto
        }

        self.selectedVoiceProviderID =
            userDefaults.string(forKey: UserDefaultsKeys.selectedVoiceProviderID)
            ?? LocalVoiceModelCatalog.defaultProviderID
        self.selectedVoiceModelID =
            userDefaults.string(forKey: UserDefaultsKeys.selectedVoiceModelID)
            ?? LocalVoiceModelCatalog.defaultModelID
        if let data = userDefaults.data(forKey: UserDefaultsKeys.voiceLanguageOverrides),
            let decoded = try? JSONDecoder().decode([VoiceLanguageOverride].self, from: data)
        {
            self.voiceLanguageOverrides = decoded
        } else {
            self.voiceLanguageOverrides = []
        }

        if let rawHotkey = userDefaults.string(forKey: UserDefaultsKeys.selectedHotkey),
            let parsedHotkey = HotkeyBinding.from(rawValue: rawHotkey)
        {
            self.selectedHotkey = parsedHotkey
        } else {
            self.selectedHotkey = .optionSpace
        }

        self.toggleShortcutEnabled =
            userDefaults.object(forKey: UserDefaultsKeys.toggleShortcutEnabled) as? Bool ?? true
        self.holdToDictateEnabled =
            userDefaults.object(forKey: UserDefaultsKeys.holdToDictateEnabled) as? Bool ?? false

        if let rawHoldHotkey = userDefaults.string(forKey: UserDefaultsKeys.holdShortcut),
            let parsedHoldHotkey = HotkeyBinding.from(rawValue: rawHoldHotkey)
        {
            self.holdShortcut = parsedHoldHotkey
        } else {
            self.holdShortcut = .optionShiftSpace
        }

        self.cancelShortcutEnabled =
            userDefaults.object(forKey: UserDefaultsKeys.cancelShortcutEnabled) as? Bool ?? false
        if let rawCancelHotkey = userDefaults.string(forKey: UserDefaultsKeys.cancelShortcut),
            let parsedCancelHotkey = HotkeyBinding.from(rawValue: rawCancelHotkey)
        {
            self.cancelShortcut = parsedCancelHotkey
        } else {
            self.cancelShortcut = HotkeyBinding(
                keyCode: UInt32(kVK_Escape), carbonModifiers: UInt32(optionKey))
        }

        self.modeSwitchShortcutEnabled =
            userDefaults.object(forKey: UserDefaultsKeys.modeSwitchShortcutEnabled) as? Bool
            ?? false
        if let rawModeSwitchHotkey = userDefaults.string(
            forKey: UserDefaultsKeys.modeSwitchShortcut),
            let parsedModeSwitchHotkey = HotkeyBinding.from(rawValue: rawModeSwitchHotkey)
        {
            self.modeSwitchShortcut = parsedModeSwitchHotkey
        } else {
            self.modeSwitchShortcut = HotkeyBinding(
                keyCode: UInt32(kVK_ANSI_M), carbonModifiers: UInt32(optionKey | shiftKey))
        }

        self.showMenuBarShortcutHints =
            userDefaults.object(forKey: UserDefaultsKeys.showMenuBarShortcutHints) as? Bool ?? false
        self.compactMenuBarDesign =
            userDefaults.object(forKey: UserDefaultsKeys.compactMenuBarDesign) as? Bool ?? false
        self.showInDock = userDefaults.object(forKey: UserDefaultsKeys.showInDock) as? Bool ?? false
        if userDefaults.object(forKey: UserDefaultsKeys.launchOnLoginEnabled) != nil {
            self.launchOnLoginEnabled = userDefaults.bool(
                forKey: UserDefaultsKeys.launchOnLoginEnabled)
        } else {
            self.launchOnLoginEnabled = Self.currentLaunchOnLoginEnabled()
        }
        self.automaticallyCheckForUpdates =
            userDefaults.object(forKey: UserDefaultsKeys.automaticallyCheckForUpdates) as? Bool
            ?? true
        self.debugModeEnabled =
            userDefaults.object(forKey: UserDefaultsKeys.debugModeEnabled) as? Bool ?? false
        if let rawDeliveryMode = userDefaults.string(
            forKey: UserDefaultsKeys.finalResultDeliveryMode),
            let parsedDeliveryMode = FinalResultDeliveryMode(rawValue: rawDeliveryMode)
        {
            self.finalResultDeliveryMode = parsedDeliveryMode
        } else {
            self.finalResultDeliveryMode = .insert
        }
        self.clipboardFallbackWhenNoTarget =
            userDefaults.object(forKey: UserDefaultsKeys.clipboardFallbackWhenNoTarget) as? Bool
            ?? false

        if let rawLiveRewriteScope = userDefaults.string(forKey: UserDefaultsKeys.liveRewriteScope),
            let parsedLiveRewriteScope = LiveRewriteScope(rawValue: rawLiveRewriteScope)
        {
            self.liveRewriteScope = parsedLiveRewriteScope
        } else {
            self.liveRewriteScope = .currentSentence
        }

        self.aiProcessingEnabled =
            userDefaults.object(forKey: UserDefaultsKeys.aiProcessingEnabled) as? Bool ?? false
        self.selectedAIModelID = userDefaults.string(forKey: UserDefaultsKeys.selectedAIModelID)

        if userDefaults.object(forKey: UserDefaultsKeys.aiProcessingApplyDuringLiveInsertion) != nil
        {
            self.aiProcessingApplyDuringLiveInsertion = userDefaults.bool(
                forKey: UserDefaultsKeys.aiProcessingApplyDuringLiveInsertion)
        } else if userDefaults.string(forKey: UserDefaultsKeys.legacyAIProcessingScope)
            == "liveAndFinal"
        {
            self.aiProcessingApplyDuringLiveInsertion = true
        } else {
            self.aiProcessingApplyDuringLiveInsertion = false
        }

        if userDefaults.object(forKey: UserDefaultsKeys.aiProcessingApplyToFinalResult) != nil {
            self.aiProcessingApplyToFinalResult = userDefaults.bool(
                forKey: UserDefaultsKeys.aiProcessingApplyToFinalResult)
        } else {
            self.aiProcessingApplyToFinalResult = true
        }

        let storedAIRevisionGoal = userDefaults.string(forKey: UserDefaultsKeys.aiRevisionGoal)
            .flatMap(AIRevisionGoal.init(rawValue:))

        if userDefaults.object(forKey: UserDefaultsKeys.aiTaskCleanupEnabled) != nil {
            self.aiTaskCleanupEnabled = userDefaults.bool(
                forKey: UserDefaultsKeys.aiTaskCleanupEnabled)
        } else {
            self.aiTaskCleanupEnabled =
                storedAIRevisionGoal == nil || storedAIRevisionGoal == .cleanup
        }

        if userDefaults.object(forKey: UserDefaultsKeys.aiTaskToneEnabled) != nil {
            self.aiTaskToneEnabled = userDefaults.bool(forKey: UserDefaultsKeys.aiTaskToneEnabled)
        } else {
            self.aiTaskToneEnabled = storedAIRevisionGoal == .adjustTone
        }

        if userDefaults.object(forKey: UserDefaultsKeys.aiTaskSalutationEnabled) != nil {
            self.aiTaskSalutationEnabled = userDefaults.bool(
                forKey: UserDefaultsKeys.aiTaskSalutationEnabled)
        } else {
            self.aiTaskSalutationEnabled = storedAIRevisionGoal == .adjustSalutation
        }

        if userDefaults.object(forKey: UserDefaultsKeys.aiTaskFormatEnabled) != nil {
            self.aiTaskFormatEnabled = userDefaults.bool(
                forKey: UserDefaultsKeys.aiTaskFormatEnabled)
        } else {
            self.aiTaskFormatEnabled = storedAIRevisionGoal == .adaptFormat
        }

        if let rawAIRevisionGoal = userDefaults.string(forKey: UserDefaultsKeys.aiRevisionGoal),
            let parsedAIRevisionGoal = AIRevisionGoal(rawValue: rawAIRevisionGoal)
        {
            self.aiRevisionGoal = parsedAIRevisionGoal
        } else {
            self.aiRevisionGoal = .cleanup
        }

        if let rawAIFormattingMode = userDefaults.string(forKey: UserDefaultsKeys.aiFormattingMode),
            let parsedAIFormattingMode = AIFormattingMode(rawValue: rawAIFormattingMode)
        {
            self.aiFormattingMode = parsedAIFormattingMode
        } else {
            self.aiFormattingMode = .plainText
        }

        if let rawAIWritingStyle = userDefaults.string(forKey: UserDefaultsKeys.aiWritingStyle),
            let parsedAIWritingStyle = AIWritingStyle(rawValue: rawAIWritingStyle)
        {
            self.aiWritingStyle = parsedAIWritingStyle
        } else {
            self.aiWritingStyle = .none
        }

        if let rawAISalutation = userDefaults.string(forKey: UserDefaultsKeys.aiSalutation),
            let parsedAISalutation = AISalutation(rawValue: rawAISalutation)
        {
            self.aiSalutation = parsedAISalutation
        } else {
            self.aiSalutation = .none
        }

        if let rawVoiceModelActiveDuration = userDefaults.string(
            forKey: UserDefaultsKeys.voiceModelActiveDuration),
            let parsedVoiceModelActiveDuration = VoiceModelActiveDuration(
                rawValue: rawVoiceModelActiveDuration)
        {
            self.voiceModelActiveDuration = parsedVoiceModelActiveDuration
        } else {
            self.voiceModelActiveDuration = .oneMinute
        }

        self.automaticMicrophoneGainBoost =
            userDefaults.object(forKey: UserDefaultsKeys.automaticMicrophoneGainBoost) as? Bool
            ?? false
        self.silenceRemovalEnabled =
            userDefaults.object(forKey: UserDefaultsKeys.silenceRemovalEnabled) as? Bool ?? false
        self.dynamicNormalizationEnabled =
            userDefaults.object(forKey: UserDefaultsKeys.dynamicNormalizationEnabled) as? Bool
            ?? false
        self.noiseSuppressionLevel =
            userDefaults.object(forKey: UserDefaultsKeys.noiseSuppressionLevel) as? Double ?? 0.35
        self.soundEffectsEnabled =
            userDefaults.object(forKey: UserDefaultsKeys.soundEffectsEnabled) as? Bool ?? false
        let loadedSoundVolume =
            userDefaults.object(forKey: UserDefaultsKeys.soundEffectsVolume) as? Double ?? 50
        let steppedSoundVolume = (loadedSoundVolume / 5).rounded() * 5
        self.soundEffectsVolume = min(100, max(0, steppedSoundVolume))

        if let rawHistoryRetentionPolicy = userDefaults.string(
            forKey: UserDefaultsKeys.historyRetentionPolicy),
            let parsedHistoryRetentionPolicy = HistoryRetentionPolicy(
                rawValue: rawHistoryRetentionPolicy)
        {
            self.historyRetentionPolicy = parsedHistoryRetentionPolicy
        } else {
            self.historyRetentionPolicy = .forever
        }

        self.autoSendAfterPaste =
            userDefaults.object(forKey: UserDefaultsKeys.autoSendAfterPaste) as? Bool ?? false
        self.restoreClipboardAfterPaste =
            userDefaults.object(forKey: UserDefaultsKeys.restoreClipboardAfterPaste) as? Bool
            ?? false
        self.simulateKeypresses =
            userDefaults.object(forKey: UserDefaultsKeys.simulateKeypresses) as? Bool ?? false

        let persistedRemoteProviders: [AIRemoteProviderConfiguration]
        if let data = userDefaults.data(forKey: UserDefaultsKeys.remoteProviders),
            let decoded = try? JSONDecoder().decode(
                [AIRemoteProviderConfiguration].self, from: data)
        {
            persistedRemoteProviders = decoded
        } else {
            persistedRemoteProviders = []
        }
        self.remoteProviders = persistedRemoteProviders

        let initialSelectedRemoteProviderID =
            userDefaults.string(forKey: UserDefaultsKeys.selectedRemoteProviderID)
            ?? persistedRemoteProviders.first?.id
        self.selectedRemoteProviderID = initialSelectedRemoteProviderID

        self.snippetStore = SnippetStore(fileURL: Self.snippetStorageURL())
        self.historyStore = TranscriptHistoryStore(fileURL: Self.historyStorageURL())
        self.auditLogger = AuditLogger(fileURL: Self.auditLogStorageURL())
        self.debugLogger = AuditLogger(fileURL: Self.debugLogStorageURL())
        self.licenseController = LicenseController(
            configuration: configuration, cacheFileURL: Self.legacyLicenseCacheURL())
        self.remoteProviderAPIKeyDraft =
            initialSelectedRemoteProviderID.flatMap {
                aiRemoteProviderSecretStore.loadAPIKey(providerID: $0)
            } ?? ""
        refreshVoiceModelCatalog()
        sanitizeAIProcessingSelections()
        sanitizeSpeechModelSelections()
        sanitizeVisibleMenuBarLanguages()

        dictationRuntime.onStatus = { [weak self] status in
            self?.recordingStatus = status
            if status != "Recording" {
                self?.holdSessionActive = false
            }
        }
        dictationRuntime.onSessionActivityChanged = { [weak self] isActive in
            self?.isSessionActive = isActive
            if !isActive {
                self?.holdSessionActive = false
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
            self?.handleFinalTranscript(event)
        }

        hotkeyManager.onToggle = { [weak self] in
            self?.toggleTranscriptionFromUI()
        }
        hotkeyManager.onHoldPress = { [weak self] in
            self?.handleHoldShortcutPressed()
        }
        hotkeyManager.onHoldRelease = { [weak self] in
            self?.handleHoldShortcutReleased()
        }
        hotkeyManager.onCancel = { [weak self] in
            self?.cancelTranscriptionFromUI()
        }
        hotkeyManager.onModeSwitch = { [weak self] in
            self?.toggleDictationModeFromShortcut()
        }
        registerSelectedHotkey(force: true)

        loadSnippets()
        loadHistory()
        updateCapabilitySummary()
        rebuildAIProcessingStack(reason: "initial-load")
        updateUpdaterState()
        loadExistingLicense()
        dictationRuntime.setVoiceModelActiveDuration(voiceModelActiveDuration)
        dictationRuntime.prepareRuntime()
        refreshPermissionStates()
        applyActivationPolicy()
        syncLaunchOnLogin()
        configureLifecycleObservers()
    }

    deinit {
        permissionPollTask?.cancel()
        accessibilityStatusDebounceTask?.cancel()
        if let didActivateApplicationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(didActivateApplicationObserver)
        }
        if let didBecomeActiveObserver {
            NotificationCenter.default.removeObserver(didBecomeActiveObserver)
        }
        if let didWakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(didWakeObserver)
        }
    }

    func bindUpdater(_ updaterController: SparkleUpdaterController) {
        self.updaterController = updaterController
        updaterConfigured = updaterController.isConfigured
        updaterStatusText = updaterController.statusText
        updaterFeedURLText = updaterController.feedURLDescription
        syncAutomaticUpdateChecks()
        checkForUpdatesHandler = { [weak self, weak updaterController] in
            updaterController?.checkForUpdates()
            self?.updaterStatusText = updaterController?.statusText ?? "Updater nicht verfügbar"
        }
    }

    func bindOpenSettingsHandler(_ handler: @escaping () -> Void) {
        openSettingsHandler = handler
    }

    func openSettingsWindow() {
        if let openSettingsHandler {
            openSettingsHandler()
        } else {
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }

    func openHistorySettingsWindow() {
        selectedSettingsTab = .history
        openSettingsWindow()
    }

    func openAISettingsWindow() {
        selectedSettingsTab = .ai
        openSettingsWindow()
    }

    func toggleVisibleMenuBarLanguage(_ language: DictationLanguage) {
        guard language != .auto else { return }
        if visibleMenuBarLanguages.contains(language.rawValue) {
            visibleMenuBarLanguages.removeAll { $0 == language.rawValue }
        } else {
            visibleMenuBarLanguages.append(language.rawValue)
        }
        sanitizeVisibleMenuBarLanguages()
    }

    func cancelTranscriptionFromUI() {
        appendAudit("session.cancel")
        dictationRuntime.cancel()
    }

    func toggleDictationModeFromShortcut() {
        streamingEnabled.toggle()
        appendAudit("mode.toggle streamingEnabled=\(streamingEnabled)")
        appendDiagnostic(
            streamingEnabled
                ? "Live-Einfügen aktiviert. Der Wechsel gilt ab dem nächsten Diktat."
                : "Live-Einfügen deaktiviert. Der Wechsel gilt ab dem nächsten Diktat.")
    }

    func revealAppDataFolder() {
        let folderURL = Self.appSupportDirectory()
        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        NSWorkspace.shared.activateFileViewerSelecting([folderURL])
        appendAudit("storage.reveal path=\(folderURL.path)")
    }

    func addRemoteProvider(preset: AIRemoteProviderPreset) {
        var provider = AIRemoteProviderConfiguration.template(
            for: preset,
            appTitle: "WisprLocal",
            appReferer: Bundle.main.bundleURL.absoluteString
        )
        if preset == .customOpenAICompatible {
            provider.displayName = "Custom API"
        }
        remoteProviders.append(provider)
        selectedRemoteProviderID = provider.id
        if provider.requiresAPIKey {
            appendDiagnostic(
                "\(provider.displayName) wurde als API-Anbieter hinzugefügt und startet deaktiviert. Hinterlege jetzt den API-Key, speichere die Konfiguration und aktiviere den Anbieter danach bewusst."
            )
        } else {
            appendDiagnostic(
                "\(provider.displayName) wurde als API-Anbieter hinzugefügt und startet deaktiviert. Speichere die Konfiguration und aktiviere den Anbieter danach bewusst."
            )
        }
    }

    func removeSelectedRemoteProvider() {
        guard let selectedRemoteProviderID else { return }
        remoteProviders.removeAll { $0.id == selectedRemoteProviderID }
        aiRemoteProviderSecretStore.removeAPIKey(providerID: selectedRemoteProviderID)
        self.selectedRemoteProviderID = remoteProviders.first?.id
        rebuildAIProcessingStack(reason: "remote-provider-removed")
    }

    func updateSelectedRemoteProvider(_ update: (inout AIRemoteProviderConfiguration) -> Void) {
        guard let selectedRemoteProviderID else { return }
        updateRemoteProvider(id: selectedRemoteProviderID, update)
    }

    private func updateRemoteProvider(
        id providerID: String,
        _ update: (inout AIRemoteProviderConfiguration) -> Void
    ) {
        guard let index = remoteProviders.firstIndex(where: { $0.id == providerID }) else {
            return
        }

        var provider = remoteProviders[index]
        update(&provider)
        remoteProviders[index] = provider
    }

    func saveSelectedRemoteProviderAPIKey() {
        guard let selectedRemoteProviderID else { return }
        let trimmed = remoteProviderAPIKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            aiRemoteProviderSecretStore.removeAPIKey(providerID: selectedRemoteProviderID)
            appendDiagnostic("API-Key für den gewählten Anbieter entfernt.")
        } else {
            do {
                try aiRemoteProviderSecretStore.saveAPIKey(
                    trimmed, providerID: selectedRemoteProviderID)
                appendDiagnostic("API-Key für den gewählten Anbieter im Keychain gespeichert.")
            } catch {
                appendDiagnostic(
                    "API-Key konnte nicht gespeichert werden: \(error.localizedDescription)")
            }
        }

        rebuildAIProcessingStack(reason: "remote-provider-api-key")
    }

    func saveSelectedRemoteProvider() {
        guard let selectedRemoteProvider else { return }

        saveSelectedRemoteProviderAPIKey()

        let trimmedAPIKey = remoteProviderAPIKeyDraft.trimmingCharacters(
            in: .whitespacesAndNewlines)
        if selectedRemoteProvider.requiresAPIKey && trimmedAPIKey.isEmpty {
            appendDiagnostic(
                "Anbieter gespeichert. Hinterlege einen API-Key, um den Modellkatalog zu laden.")
            return
        }

        refreshSelectedRemoteProviderModels()
    }

    func refreshSelectedRemoteProviderModels() {
        guard let selectedRemoteProvider else { return }
        let providerID = selectedRemoteProvider.id
        let providerName = selectedRemoteProvider.displayName
        let apiKey =
            aiRemoteProviderSecretStore.loadAPIKey(providerID: selectedRemoteProvider.id) ?? ""
        if selectedRemoteProvider.requiresAPIKey,
            apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            appendDiagnostic("Für den gewählten API-Anbieter fehlt ein API-Key.")
            return
        }

        appendDiagnostic("Lade Modellkatalog für \(providerName)...")
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let models = try await OpenAICompatibleRemoteTextProcessor.discoverModels(
                    configuration: selectedRemoteProvider,
                    apiKey: apiKey
                )
                self.updateRemoteProvider(id: providerID) { provider in
                    provider.discoveredModels = models
                }
                self.rebuildAIProcessingStack(reason: "remote-models-refreshed")
                self.appendDiagnostic(
                    "Modellkatalog für \(providerName) aktualisiert: \(models.count) Modelle.")
            } catch {
                self.appendDiagnostic(
                    "Modellkatalog für \(providerName) konnte nicht geladen werden: \(error.localizedDescription)"
                )
            }
        }
    }

    func handleHoldShortcutPressed() {
        appendAudit("hotkey.hold.press recordingStatus=\(recordingStatus)")
        guard holdToDictateEnabled else { return }
        guard !holdSessionActive else { return }
        guard !isSessionActive else { return }

        holdSessionActive = true
        startTranscriptionForShortcut()
    }

    func handleHoldShortcutReleased() {
        appendAudit("hotkey.hold.release recordingStatus=\(recordingStatus)")
        guard holdSessionActive else { return }
        holdSessionActive = false
        guard isSessionActive else { return }
        dictationRuntime.toggle(options: currentStartOptions())
    }

    func toggleTranscriptionFromUI() {
        if isSessionActive {
            appendAudit("session.toggle stop")
            holdSessionActive = false
            dictationRuntime.toggle(options: currentStartOptions())
            return
        }

        startTranscriptionForShortcut()
    }

    func toggleTranscriptionFromMenuBar() {
        if isSessionActive {
            toggleTranscriptionFromUI()
            return
        }

        let options = currentStartOptions()
        appendAudit(
            "session.toggle.menuBar start mode=\(options.mode) language=\(selectedLanguage.rawValue) profile=\(performanceProfile.rawValue)"
        )

        guard dictationCapability.allowsDirectInsertion else {
            dictationRuntime.start(options: options)
            return
        }

        restorePreviousApplicationAndStart(options: options, source: "menuBar")
    }

    private func startTranscriptionForShortcut() {
        let options = currentStartOptions()
        appendAudit(
            "session.toggle start mode=\(options.mode) language=\(selectedLanguage.rawValue) profile=\(performanceProfile.rawValue)"
        )

        if dictationCapability.allowsDirectInsertion,
            shouldRestorePreviousApplicationBeforeStarting(),
            let previousApplication = lastExternalApplication
        {
            appendDiagnostic(
                "Wechsle vor dem Start zurück zur letzten App, um das fokussierte Textfeld zu verwenden."
            )
            restorePreviousApplicationAndStart(
                options: options, source: "shortcut", preferredApplication: previousApplication)
            return
        }

        dictationRuntime.toggle(options: options)
    }

    private func currentStartOptions() -> DictationStartOptions {
        let mode: DictationMode
        if finalResultDeliveryMode == .clipboardOnly {
            mode = .finalize
        } else {
            mode = streamingEnabled ? .streaming : .finalize
        }
        return DictationStartOptions(
            mode: mode,
            language: selectedLanguage,
            translationOutput: translationOutputMode,
            performance: performanceProfile,
            selectedVoiceProviderID: effectiveVoiceProviderID(for: selectedLanguage),
            selectedVoiceModelID: effectiveVoiceModelDescriptor(for: selectedLanguage)?.id
                ?? selectedVoiceModelID,
            liveRewriteScope: liveRewriteScope,
            snippetRules: snippetRules,
            finalResultDeliveryMode: finalResultDeliveryMode,
            clipboardFallbackWhenNoTarget: clipboardFallbackWhenNoTarget,
            simulateKeypresses: simulateKeypresses,
            restoreClipboardAfterPaste: restoreClipboardAfterPaste,
            autoSendAfterPaste: autoSendAfterPaste,
            aiProcessing: aiProcessingConfiguration,
            audioProcessing: audioProcessingConfiguration,
            soundFeedback: soundFeedbackConfiguration
        )
    }

    func refreshVoiceModelCatalog() {
        let providers = LocalVoiceModelCatalog.availableProviders()
        voiceProviders = providers
        voiceModels = LocalVoiceModelCatalog.availableModels(
            includeParakeet: providers.contains(where: {
                $0.id == VoiceProviderID.nvidiaParakeet.rawValue
            }))

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let installedFiles = try await self.voiceModelInstaller
                    .installedWhisperModelFileNames()
                self.installedVoiceModelFileNames = installedFiles
            } catch {
                self.installedVoiceModelFileNames = []
                self.appendDiagnostic(
                    "Speech-Model-Katalog konnte nicht vollständig geladen werden: \(error.localizedDescription)"
                )
            }

            self.sanitizeSpeechModelSelections()
        }
    }

    func installVoiceModel(_ descriptor: VoiceModelDescriptor) {
        guard descriptor.providerID == VoiceProviderID.whisperCpp.rawValue else {
            appendDiagnostic("Dieser Speech-Anbieter ist lokal aktuell nicht installierbar.")
            return
        }

        voiceModelOperationInFlightIDs.insert(descriptor.id)
        appendDiagnostic("Installiere Speech-Modell \(descriptor.displayName)...")

        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.voiceModelOperationInFlightIDs.remove(descriptor.id) }

            do {
                let runtime = try await self.voiceModelInstaller.install(descriptor)
                self.installedVoiceModelFileNames = Set(runtime.availableModelFileNames)
                self.sanitizeSpeechModelSelections()
                self.appendDiagnostic("Speech-Modell \(descriptor.displayName) wurde installiert.")
            } catch {
                self.appendDiagnostic(
                    "Speech-Modell \(descriptor.displayName) konnte nicht installiert werden: \(error.localizedDescription)"
                )
            }
        }
    }

    func removeVoiceModel(_ descriptor: VoiceModelDescriptor) {
        guard descriptor.providerID == VoiceProviderID.whisperCpp.rawValue else {
            appendDiagnostic("Dieser Speech-Anbieter ist lokal aktuell nicht entfernbar.")
            return
        }

        voiceModelOperationInFlightIDs.insert(descriptor.id)
        appendDiagnostic("Entferne Speech-Modell \(descriptor.displayName)...")

        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.voiceModelOperationInFlightIDs.remove(descriptor.id) }

            do {
                let runtime = try await self.voiceModelInstaller.remove(descriptor)
                self.installedVoiceModelFileNames = Set(runtime.availableModelFileNames)
                self.voiceLanguageOverrides.removeAll { $0.modelID == descriptor.id }
                self.sanitizeSpeechModelSelections()
                self.appendDiagnostic("Speech-Modell \(descriptor.displayName) wurde entfernt.")
            } catch {
                self.appendDiagnostic(
                    "Speech-Modell \(descriptor.displayName) konnte nicht entfernt werden: \(error.localizedDescription)"
                )
            }
        }
    }

    func setSelectedVoiceModel(_ descriptor: VoiceModelDescriptor) {
        selectedVoiceProviderID = descriptor.providerID
        selectedVoiceModelID = descriptor.id
    }

    func assignSelectedVoiceModelToCurrentLanguage() {
        guard selectedLanguage != .auto, let descriptor = selectedVoiceModel else { return }
        voiceLanguageOverrides.removeAll { $0.languageCode == selectedLanguage.rawValue }
        voiceLanguageOverrides.append(
            VoiceLanguageOverride(languageCode: selectedLanguage.rawValue, modelID: descriptor.id)
        )
        sanitizeSpeechModelSelections()
        appendDiagnostic(
            "Für \(selectedLanguage.displayName) wird jetzt standardmäßig \(descriptor.displayName) verwendet."
        )
    }

    func clearSelectedLanguageVoiceOverride() {
        guard selectedLanguage != .auto else { return }
        voiceLanguageOverrides.removeAll { $0.languageCode == selectedLanguage.rawValue }
        sanitizeSpeechModelSelections()
        appendDiagnostic(
            "Sprachspezifisches Speech-Modell für \(selectedLanguage.displayName) entfernt.")
    }

    func isVoiceModelInstalled(_ descriptor: VoiceModelDescriptor) -> Bool {
        guard descriptor.providerID == VoiceProviderID.whisperCpp.rawValue else {
            return descriptor.installState == .bundled
        }
        guard let localFileName = descriptor.localFileName else { return false }
        return installedVoiceModelFileNames.contains(localFileName)
    }

    func isVoiceModelBusy(_ descriptor: VoiceModelDescriptor) -> Bool {
        voiceModelOperationInFlightIDs.contains(descriptor.id)
    }

    func canUseVoiceModel(_ descriptor: VoiceModelDescriptor, for language: DictationLanguage)
        -> Bool
    {
        if descriptor.providerID != VoiceProviderID.whisperCpp.rawValue {
            return false
        }
        if !isVoiceModelInstalled(descriptor) {
            return false
        }
        guard let languageCode = descriptor.languageCode else { return true }
        return language == .auto || language.rawValue == languageCode
    }

    func voiceLanguageOptions(for descriptor: VoiceModelDescriptor?) -> [DictationLanguage] {
        guard let descriptor, let languageCode = descriptor.languageCode else {
            return DictationLanguage.allCases
        }

        let fixedLanguage = DictationLanguage(rawValue: languageCode) ?? .english
        return [.auto, fixedLanguage]
    }

    private func effectiveVoiceProviderID(for language: DictationLanguage) -> String {
        effectiveVoiceModelDescriptor(for: language)?.providerID ?? selectedVoiceProviderID
    }

    private func effectiveVoiceModelDescriptor(for language: DictationLanguage)
        -> VoiceModelDescriptor?
    {
        let overrideDescriptor: VoiceModelDescriptor?
        if language != .auto,
            let overrideID = voiceLanguageOverrides.first(where: {
                $0.languageCode == language.rawValue
            })?.modelID
        {
            overrideDescriptor = voiceModels.first(where: { $0.id == overrideID })
        } else {
            overrideDescriptor = nil
        }

        if let overrideDescriptor, canUseVoiceModel(overrideDescriptor, for: language) {
            return overrideDescriptor
        }

        if let selectedVoiceModel, canUseVoiceModel(selectedVoiceModel, for: language) {
            return selectedVoiceModel
        }

        if let standard = voiceModels.first(where: {
            $0.id == LocalVoiceModelCatalog.defaultModelID
        }),
            canUseVoiceModel(standard, for: language)
        {
            return standard
        }

        return voiceModels.first(where: { canUseVoiceModel($0, for: language) })
    }

    private func sanitizeAIProcessingSelections() {
        if !aiTaskCleanupEnabled && !aiTaskToneEnabled && !aiTaskSalutationEnabled
            && !aiTaskFormatEnabled
        {
            aiTaskCleanupEnabled = true
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
        if voiceProviders.isEmpty {
            voiceProviders = LocalVoiceModelCatalog.availableProviders()
        }
        if voiceModels.isEmpty {
            voiceModels = LocalVoiceModelCatalog.availableModels(includeParakeet: false)
        }

        if !voiceProviders.contains(where: { $0.id == selectedVoiceProviderID }) {
            selectedVoiceProviderID = LocalVoiceModelCatalog.defaultProviderID
        }

        if let selectedVoiceModel,
            selectedVoiceModel.providerID != selectedVoiceProviderID
        {
            selectedVoiceModelID =
                voiceModels.first(where: { $0.providerID == selectedVoiceProviderID })?.id
                ?? LocalVoiceModelCatalog.defaultModelID
        }

        if selectedVoiceModel == nil {
            selectedVoiceModelID =
                voiceModels.first(where: { $0.id == LocalVoiceModelCatalog.defaultModelID })?.id
                ?? voiceModels.first(where: { $0.providerID == selectedVoiceProviderID })?.id
                ?? LocalVoiceModelCatalog.defaultModelID
        }

        if let selectedVoiceModel {
            let availableLanguages = Set(
                voiceLanguageOptions(for: selectedVoiceModel).map(\.rawValue))
            if !availableLanguages.contains(selectedLanguage.rawValue) {
                selectedLanguage = .auto
            }
            if let languageCode = selectedVoiceModel.languageCode,
                selectedLanguage == .auto
            {
                selectedLanguage = DictationLanguage(rawValue: languageCode) ?? .english
            }
        }

        voiceLanguageOverrides.removeAll { overrideEntry in
            guard let descriptor = voiceModels.first(where: { $0.id == overrideEntry.modelID })
            else {
                return true
            }
            let language = DictationLanguage(rawValue: overrideEntry.languageCode) ?? .auto
            return !canUseVoiceModel(descriptor, for: language)
        }

        if !speechTranslationAvailable, translationOutputMode != .original {
            translationOutputMode = .original
        }
    }

    private func sanitizeVisibleMenuBarLanguages() {
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

    private func shouldRestorePreviousApplicationBeforeStarting() -> Bool {
        let ownBundleIdentifier = Bundle.main.bundleIdentifier
        let frontmostBundleIdentifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        return frontmostBundleIdentifier == ownBundleIdentifier
    }

    private func restorePreviousApplicationAndStart(
        options: DictationStartOptions,
        source: String,
        preferredApplication: NSRunningApplication? = nil
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }

            let targetApplication = preferredApplication ?? self.lastExternalApplication
            if let targetApplication, let bundleIdentifier = targetApplication.bundleIdentifier {
                self.appendDiagnostic(
                    "Aktiviere die letzte App erneut, damit das Ziel-Textfeld fokussiert bleibt.")
                targetApplication.activate(options: [.activateAllWindows])
                _ = await self.waitForFrontmostApplication(bundleIdentifier: bundleIdentifier)
            } else {
                _ = await self.waitForMenuBarToClose()
            }

            self.appendAudit("session.restore_start source=\(source)")
            self.dictationRuntime.start(options: options)
        }
    }

    private func waitForMenuBarToClose() async -> Bool {
        try? await Task.sleep(nanoseconds: 150_000_000)
        return true
    }

    private func waitForFrontmostApplication(
        bundleIdentifier: String, timeoutNanoseconds: UInt64 = 1_500_000_000
    ) async -> Bool {
        let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds

        while DispatchTime.now().uptimeNanoseconds < deadline {
            if NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bundleIdentifier {
                return true
            }

            try? await Task.sleep(nanoseconds: 50_000_000)
        }

        return false
    }

    func openMicrophoneSettings() {
        dictationRuntime.openMicrophoneSettings()
        schedulePermissionRefresh()
    }

    func openAccessibilitySettings() {
        dictationRuntime.openAccessibilitySettings()
        schedulePermissionRefresh()
    }

    func addSnippet(trigger: String, replacement: String) {
        let trimmedTrigger = trigger.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedReplacement = replacement.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedTrigger.isEmpty, !trimmedReplacement.isEmpty else {
            appendDiagnostic(
                "Snippet wurde nicht gespeichert: Trigger/Replacement darf nicht leer sein.")
            return
        }

        let rule = SnippetRule(
            trigger: trimmedTrigger,
            replacement: trimmedReplacement,
            caseSensitive: false,
            localeIdentifier: selectedLanguage.locale.identifier
        )
        snippetRules.append(rule)
        persistSnippets()
    }

    func removeSnippet(ruleID: UUID) {
        snippetRules.removeAll { $0.id == ruleID }
        persistSnippets()
    }

    func importSnippetsFromJSON() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.json]

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            snippetRules = try snippetStore.importRules(from: url)
            appendDiagnostic("Snippets importiert: \(snippetRules.count)")
            appendAudit("snippets.import path=\(url.path)")
        } catch {
            appendDiagnostic("Snippet-Import fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    func exportSnippetsToJSON() {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "wispr-snippets.json"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try snippetStore.exportRules(snippetRules, to: url)
            appendDiagnostic("Snippets exportiert: \(snippetRules.count)")
            appendAudit("snippets.export path=\(url.path)")
        } catch {
            appendDiagnostic("Snippet-Export fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    func copyHistoryEntry(_ entry: TranscriptHistoryEntry) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(entry.text, forType: .string)
        appendDiagnostic("History-Eintrag kopiert: \(entry.id.uuidString.prefix(8))")
    }

    func copyAllHistoryToClipboard() {
        let joined =
            transcriptHistory
            .reversed()
            .map {
                "[\(Self.displayDate($0.createdAt))] [\($0.mode)] [\($0.languageCode)] \($0.text)"
            }
            .joined(separator: "\n")

        guard !joined.isEmpty else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(joined, forType: .string)
        appendDiagnostic("Gesamte History in Zwischenablage kopiert")
    }

    func exportHistoryAsText() {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "wispr-transcript-history.txt"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try historyStore.exportText(entries: transcriptHistory, to: url)
            appendDiagnostic("History exportiert")
            appendAudit("history.export path=\(url.path)")
        } catch {
            appendDiagnostic("History-Export fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    func removeHistoryEntry(_ entryID: UUID) {
        transcriptHistory.removeAll { $0.id == entryID }
        persistHistory()
    }

    func clearHistory() {
        transcriptHistory.removeAll()
        persistHistory()
        appendDiagnostic("History geleert")
        appendAudit("history.clear")
    }

    func exportDiagnosticsReport() {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "wispr-diagnostics.txt"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let report = [
            "WisprLocal Diagnostics",
            "Status: \(recordingStatus)",
            "Permissions: \(permissionSummary)",
            "Capability: \(capabilitySummary)",
            "Updater: \(updaterStatusText)",
            "License: \(licenseStatusText)",
            "Technical logging: \(debugModeEnabled ? "enabled" : "disabled")",
            "",
            diagnosticsText,
            "",
            "Technical Diagnostic Log",
            debugLogText.isEmpty ? "No technical diagnostic events captured." : debugLogText,
        ].joined(separator: "\n")

        do {
            try report.write(to: url, atomically: true, encoding: .utf8)
            appendDiagnostic("Diagnose exportiert")
            appendAudit("diagnostics.export path=\(url.path)")
        } catch {
            appendDiagnostic("Diagnose-Export fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    func exportAuditLog() {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "wispr-audit.log"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try auditLogger.export(to: url)
            appendDiagnostic("Audit-Log exportiert")
            appendAudit("audit.export path=\(url.path)")
        } catch {
            appendDiagnostic("Audit-Export fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    /// Ein Block für die Zwischenablage: Diagnose + technisches Protokoll (z. B. Smoke-Test / Support).
    func diagnosticsAndDebugCombinedForClipboard() -> String {
        [
            "=== Diagnostics ===",
            diagnosticsText,
            "",
            "=== Technical log ===",
            debugLogText.isEmpty ? "(empty)" : debugLogText,
        ].joined(separator: "\n")
    }

    func exportDebugLog() {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "wispr-diagnostic-log.txt"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try debugLogger.export(to: url)
            appendDiagnostic("Diagnoseprotokoll exportiert")
            appendAudit("diagnostic-log.export path=\(url.path)")
        } catch {
            appendDiagnostic(
                "Diagnoseprotokoll-Export fehlgeschlagen: \(error.localizedDescription)")
        }
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

    private func handleFinalTranscript(_ event: FinalTranscriptEvent) {
        let trimmed = event.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let entry = TranscriptHistoryEntry(
            text: trimmed,
            languageCode: event.languageCode,
            mode: event.mode == .streaming ? "streaming" : "finalize"
        )

        transcriptHistory.insert(entry, at: 0)
        pruneHistoryIfNeeded()
        if transcriptHistory.count > 500 {
            transcriptHistory = Array(transcriptHistory.prefix(500))
        }
        persistHistory()
        appendDiagnostic("History gespeichert (\(transcriptHistory.count) Einträge)")
        switch event.deliveryOutcome {
        case .inserted:
            appendDiagnostic("Finales Transkript eingefügt.")
        case .copiedToClipboard:
            appendDiagnostic("Finales Transkript in die Zwischenablage kopiert.")
        case .historyOnlyNoTarget:
            appendDiagnostic("Finales Transkript ohne Ziel nur in der History gespeichert.")
        case .failed(let reason):
            appendDiagnostic("Finales Transkript konnte nicht zugestellt werden: \(reason)")
        }
        appendAudit(
            "transcript.final language=\(event.languageCode) mode=\(entry.mode) chars=\(trimmed.count)"
        )
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
        do {
            snippetRules = try snippetStore.load()
            if snippetRules.isEmpty {
                appendDiagnostic("Keine Snippets gespeichert.")
            } else {
                appendDiagnostic("Snippets geladen: \(snippetRules.count)")
            }
        } catch {
            appendDiagnostic("Snippet-Load fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    private func persistSnippets() {
        do {
            try snippetStore.save(snippetRules)
            appendDiagnostic("Snippets gespeichert: \(snippetRules.count)")
            appendAudit("snippets.save count=\(snippetRules.count)")
        } catch {
            appendDiagnostic("Snippet-Save fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    private func loadHistory() {
        do {
            transcriptHistory = try historyStore.load()
            pruneHistoryIfNeeded()
            appendDiagnostic("History geladen: \(transcriptHistory.count)")
        } catch {
            appendDiagnostic("History-Load fehlgeschlagen: \(error.localizedDescription)")
            transcriptHistory = []
        }
    }

    private func persistHistory() {
        do {
            try historyStore.save(transcriptHistory)
        } catch {
            appendDiagnostic("History-Save fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    private func pruneHistoryIfNeeded() {
        guard let retainedDays = historyRetentionPolicy.retainedDays else { return }
        let cutoff =
            Calendar.current.date(byAdding: .day, value: -retainedDays, to: Date()) ?? .distantPast
        let originalCount = transcriptHistory.count
        transcriptHistory.removeAll { $0.createdAt < cutoff }
        if transcriptHistory.count != originalCount {
            persistHistory()
            appendDiagnostic(
                "History aufgrund der Aufbewahrungsrichtlinie bereinigt: \(transcriptHistory.count) Einträge"
            )
        }
    }

    private func updateCapabilitySummary() {
        let profile = capabilityProfiler.profile()
        let memoryGB = Double(profile.physicalMemoryBytes) / 1_073_741_824
        capabilitySummary =
            "CPU: \(profile.activeProcessorCount)/\(profile.processorCount), RAM: \(String(format: "%.1f", memoryGB)) GB, Thermal: \(profile.thermalState)"
    }

    func refreshPermissionStates() {
        microphonePermissionStatus = permissionController.microphoneStatus()
        applyAccessibilityStatusWithDebounce(permissionController.accessibilityStatus())
    }

    /// UI-Status für Bedienungshilfen: Freigabe sofort anzeigen; vorübergehende „Verweigert“-Messwerte kurz entprellen.
    private func applyAccessibilityStatusWithDebounce(_ raw: PermissionStatus) {
        if !hasAppliedAccessibilityStatusOnce {
            accessibilityStatusDebounceTask?.cancel()
            accessibilityPermissionStatus = raw
            hasAppliedAccessibilityStatusOnce = true
            return
        }
        if raw == .granted {
            accessibilityStatusDebounceTask?.cancel()
            accessibilityPermissionStatus = .granted
            return
        }
        if raw == accessibilityPermissionStatus {
            accessibilityStatusDebounceTask?.cancel()
            return
        }
        accessibilityStatusDebounceTask?.cancel()
        accessibilityStatusDebounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled, let self else { return }
            let again = self.permissionController.accessibilityStatus()
            if again == raw {
                self.accessibilityPermissionStatus = again
            }
        }
    }

    private func schedulePermissionRefresh() {
        permissionPollTask?.cancel()
        permissionPollTask = Task { @MainActor [weak self] in
            let delaysNanoseconds: [UInt64] = [
                400_000_000, 1_200_000_000, 2_500_000_000, 5_000_000_000,
            ]
            for delay in delaysNanoseconds {
                try? await Task.sleep(nanoseconds: delay)
                guard !Task.isCancelled else { return }
                self?.refreshPermissionsAfterExternalEvent(reason: "permission-poll")
            }
        }
    }

    /// TCC/AX nach Systemeinstellungen: nur Status lesen; Hotkeys nur bei tatsächlicher Änderung neu registrieren.
    private func refreshPermissionsAfterExternalEvent(reason: String) {
        let beforeMic = microphonePermissionStatus
        let rawAXBefore = permissionController.accessibilityStatus()
        refreshPermissionStates()
        let afterMic = microphonePermissionStatus
        let rawAXAfter = permissionController.accessibilityStatus()
        if beforeMic != afterMic || rawAXBefore != rawAXAfter {
            registerSelectedHotkey(force: true)
            appendDiagnostic("Berechtigungen geändert (\(reason))")
        }
    }

    private func appendDiagnostic(_ line: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        diagnosticLines.append("[\(timestamp)] \(line)")
        if diagnosticLines.count > 200 {
            diagnosticLines = Array(diagnosticLines.suffix(200))
        }
        diagnosticsText = diagnosticLines.joined(separator: "\n")
        appendAudit("diag \(line)")
    }

    private func appendDebug(_ line: String) {
        guard debugModeEnabled else { return }

        let timestamp = ISO8601DateFormatter().string(from: Date())
        let entry = "[\(timestamp)] \(line)"
        debugLines.append(entry)
        if debugLines.count > 400 {
            debugLines = Array(debugLines.suffix(400))
        }
        debugLogText = debugLines.joined(separator: "\n")
        debugLogger.append(line)
        appendAudit("debug \(line)")
    }

    private func appendAudit(_ line: String) {
        auditLogger.append(line)
    }

    private func configureLifecycleObservers() {
        didActivateApplicationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                guard let self else { return }
                // Nach Systemeinstellungen o. Ä. ist oft eine andere App aktiv; TCC-Status trotzdem neu lesen.
                self.refreshPermissionsAfterExternalEvent(reason: "workspace-app-activated")
                if let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                    as? NSRunningApplication,
                    application.bundleIdentifier != Bundle.main.bundleIdentifier
                {
                    self.lastExternalApplication = application
                }
            }
        }

        didBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshOperationalState(reason: "app-active")
            }
        }

        didWakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshOperationalState(reason: "system-wake")
            }
        }
    }

    private func refreshOperationalState(reason: String) {
        registerSelectedHotkey(force: true)
        updateCapabilitySummary()
        rebuildAIProcessingStack(reason: reason)
        refreshPermissionsAfterExternalEvent(reason: reason)
        dictationRuntime.prepareRuntime()
        updateUpdaterState()
        appendAudit("lifecycle.refresh reason=\(reason)")
    }

    private func persistRemoteProviders() {
        guard let data = try? JSONEncoder().encode(remoteProviders) else { return }
        userDefaults.set(data, forKey: UserDefaultsKeys.remoteProviders)
    }

    private func persistVoiceLanguageOverrides() {
        guard let data = try? JSONEncoder().encode(voiceLanguageOverrides) else { return }
        userDefaults.set(data, forKey: UserDefaultsKeys.voiceLanguageOverrides)
    }

    private func rebuildAIProcessingStack(reason: String) {
        aiProcessingService = AIProcessingService(providers: makeAIProviders())
        dictationRuntime.setAIProcessingService(aiProcessingService)
        let catalog = aiProcessingService.catalog()
        aiModels = catalog.allModels
        let fallbackModelID =
            catalog.availableModels.first?.id
            ?? catalog.allModels.first?.id

        if catalog.model(id: selectedAIModelID) == nil,
            selectedAIModelID != fallbackModelID
        {
            let previousSelection = selectedAIModelID
            selectedAIModelID = fallbackModelID
            if previousSelection != nil, fallbackModelID != nil {
                appendDiagnostic(
                    "Das zuvor gewählte AI-Modell ist nicht mehr verfügbar. Ein anderes verfügbares Modell wurde ausgewählt."
                )
            }
        }

        if aiProcessingEnabled,
            let selectedAIModel,
            !selectedAIModel.availability.isAvailable
        {
            aiProcessingEnabled = false
            appendDiagnostic(
                "AI-Verarbeitung wurde deaktiviert, weil das ausgewählte Modell aktuell nicht verfügbar ist."
            )
        }

        appendAudit(
            "ai.catalog.refresh reason=\(reason) models=\(aiModels.count) available=\(catalog.availableModels.count)"
        )
    }

    private func makeAIProviders() -> [any AITextProcessingProviding] {
        var providers: [any AITextProcessingProviding] = [AppleFoundationTextProcessor()]

        for provider in remoteProviders where provider.isEnabled {
            let apiKey = aiRemoteProviderSecretStore.loadAPIKey(providerID: provider.id) ?? ""
            if provider.requiresAPIKey,
                apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            {
                continue
            }

            providers.append(
                OpenAICompatibleRemoteTextProcessor(configuration: provider, apiKey: apiKey))
        }

        return providers
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

    private func applyActivationPolicy() {
        let targetPolicy: NSApplication.ActivationPolicy = showInDock ? .regular : .accessory
        if NSApplication.shared.activationPolicy() != targetPolicy {
            NSApplication.shared.setActivationPolicy(targetPolicy)
        }
    }

    private func reopenSettingsWindowAfterDockPolicyChange() {
        guard openSettingsHandler != nil else { return }

        DispatchQueue.main.async { [weak self] in
            self?.openSettingsHandler?()
        }
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

    private func syncAutomaticUpdateChecks() {
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

    private static func appSupportDirectory() -> URL {
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
