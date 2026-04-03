import AppKit
import AVFoundation
import AIProcessingCore
import Foundation
import SwiftUI
import SnippetCore
import CapabilityCore
import LicenseCore
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
        case let .active(tier):
            return "Aktiv: \(tier)"
        case let .invalid(reason):
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
        }
    }

    @Published var translationOutputMode: TranslationOutputMode {
        didSet {
            userDefaults.set(translationOutputMode.rawValue, forKey: UserDefaultsKeys.translationOutputMode)
        }
    }

    @Published var performanceProfile: DictationPerformance {
        didSet {
            userDefaults.set(performanceProfile.rawValue, forKey: UserDefaultsKeys.performanceProfile)
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

    @Published var finalResultDeliveryMode: FinalResultDeliveryMode {
        didSet {
            userDefaults.set(finalResultDeliveryMode.rawValue, forKey: UserDefaultsKeys.finalResultDeliveryMode)
        }
    }

    @Published var clipboardFallbackWhenNoTarget: Bool {
        didSet {
            userDefaults.set(clipboardFallbackWhenNoTarget, forKey: UserDefaultsKeys.clipboardFallbackWhenNoTarget)
        }
    }

    @Published var liveRewriteScope: LiveRewriteScope {
        didSet {
            userDefaults.set(liveRewriteScope.rawValue, forKey: UserDefaultsKeys.liveRewriteScope)
        }
    }

    @Published var showMenuBarShortcutHints: Bool {
        didSet {
            userDefaults.set(showMenuBarShortcutHints, forKey: UserDefaultsKeys.showMenuBarShortcutHints)
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
            userDefaults.set(aiProcessingApplyDuringLiveInsertion, forKey: UserDefaultsKeys.aiProcessingApplyDuringLiveInsertion)
        }
    }

    @Published var aiProcessingApplyToFinalResult: Bool {
        didSet {
            userDefaults.set(aiProcessingApplyToFinalResult, forKey: UserDefaultsKeys.aiProcessingApplyToFinalResult)
        }
    }

    @Published var aiWritingStyle: AIWritingStyle {
        didSet {
            userDefaults.set(aiWritingStyle.rawValue, forKey: UserDefaultsKeys.aiWritingStyle)
        }
    }

    @Published var aiSalutation: AISalutation {
        didSet {
            userDefaults.set(aiSalutation.rawValue, forKey: UserDefaultsKeys.aiSalutation)
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
            userDefaults.set(selectedRemoteProviderID, forKey: UserDefaultsKeys.selectedRemoteProviderID)
            remoteProviderAPIKeyDraft = selectedRemoteProviderID.flatMap { aiRemoteProviderSecretStore.loadAPIKey(providerID: $0) } ?? ""
        }
    }

    @Published var remoteProviderAPIKeyDraft: String = ""
    @Published var selectedSettingsTab: SettingsTab = .general

    @Published var snippetRules: [SnippetRule] = []
    @Published var transcriptHistory: [TranscriptHistoryEntry] = []
    @Published private(set) var aiModels: [AIModelDescriptor] = []

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
                message: "Hold-to-dictate und der normale Diktier-Shortcut dürfen nicht dieselbe Kombination verwenden."
            )
        }
        return HotkeyAdvisor.advisory(for: holdShortcut)
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
            return "Bedienungshilfen fehlen. Diktate bleiben als Verlauf oder Zwischenablage verfügbar."
        case .unavailable:
            let missing = missingPermissionTargets
            return "Fehlende Berechtigungen: \(missing.joined(separator: ", "))."
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

    var availableQuickSettingsAIModels: [AIModelDescriptor] {
        aiModels.filter { $0.quickSettingsEligible && $0.availability.isAvailable }
    }

    var selectedAIModel: AIModelDescriptor? {
        guard let selectedAIModelID else { return nil }
        return aiModels.first(where: { $0.id == selectedAIModelID })
    }

    var selectedRemoteProvider: AIRemoteProviderConfiguration? {
        guard let selectedRemoteProviderID else { return nil }
        return remoteProviders.first(where: { $0.id == selectedRemoteProviderID })
    }

    var effectiveAIProcessingEnabled: Bool {
        aiProcessingEnabled && (selectedAIModel?.availability.isAvailable ?? false)
    }

    var aiProcessingConfiguration: AIProcessingConfiguration {
        AIProcessingConfiguration(
            enabled: effectiveAIProcessingEnabled,
            selectedModelID: selectedAIModelID,
            applyDuringLiveInsertion: aiProcessingApplyDuringLiveInsertion,
            applyToFinalResult: aiProcessingApplyToFinalResult,
            style: aiWritingStyle,
            salutation: aiSalutation
        )
    }

    private enum UserDefaultsKeys {
        static let streamingEnabled = "wispr.settings.streamingEnabled"
        static let selectedLanguage = "wispr.settings.selectedLanguage"
        static let translationOutputMode = "wispr.settings.translationOutputMode"
        static let performanceProfile = "wispr.settings.performanceProfile"
        static let selectedHotkey = "wispr.settings.selectedHotkey"
        static let toggleShortcutEnabled = "wispr.settings.toggleShortcutEnabled"
        static let holdToDictateEnabled = "wispr.settings.holdToDictateEnabled"
        static let holdShortcut = "wispr.settings.holdShortcut"
        static let finalResultDeliveryMode = "wispr.settings.finalResultDeliveryMode"
        static let clipboardFallbackWhenNoTarget = "wispr.settings.clipboardFallbackWhenNoTarget"
        static let liveRewriteScope = "wispr.settings.liveRewriteScope"
        static let showMenuBarShortcutHints = "wispr.settings.showMenuBarShortcutHints"
        static let debugModeEnabled = "wispr.settings.debugModeEnabled"
        static let aiProcessingEnabled = "wispr.settings.aiProcessingEnabled"
        static let selectedAIModelID = "wispr.settings.selectedAIModelID"
        static let aiProcessingApplyDuringLiveInsertion = "wispr.settings.aiProcessing.applyDuringLiveInsertion"
        static let aiProcessingApplyToFinalResult = "wispr.settings.aiProcessing.applyToFinalResult"
        static let legacyAIProcessingScope = "wispr.settings.aiProcessingScope"
        static let aiWritingStyle = "wispr.settings.aiWritingStyle"
        static let aiSalutation = "wispr.settings.aiSalutation"
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
    private var aiProcessingService = AIProcessingService()
    private let appConfiguration: MacAppConfiguration

    private let licenseController: LicenseController
    private var didActivateApplicationObserver: NSObjectProtocol?
    private var didBecomeActiveObserver: NSObjectProtocol?
    private var didWakeObserver: NSObjectProtocol?
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

        self.streamingEnabled = userDefaults.object(forKey: UserDefaultsKeys.streamingEnabled) as? Bool ?? true

        if let rawLanguage = userDefaults.string(forKey: UserDefaultsKeys.selectedLanguage),
           let parsedLanguage = DictationLanguage(rawValue: rawLanguage) {
            self.selectedLanguage = parsedLanguage
        } else {
            self.selectedLanguage = .german
        }

        if let rawTranslationOutputMode = userDefaults.string(forKey: UserDefaultsKeys.translationOutputMode),
           let parsedTranslationOutputMode = TranslationOutputMode(rawValue: rawTranslationOutputMode) {
            self.translationOutputMode = parsedTranslationOutputMode
        } else {
            self.translationOutputMode = .original
        }

        if let rawPerformance = userDefaults.string(forKey: UserDefaultsKeys.performanceProfile),
           let parsedPerformance = DictationPerformance(rawValue: rawPerformance) {
            self.performanceProfile = parsedPerformance
        } else {
            self.performanceProfile = .auto
        }

        if let rawHotkey = userDefaults.string(forKey: UserDefaultsKeys.selectedHotkey),
           let parsedHotkey = HotkeyBinding.from(rawValue: rawHotkey) {
            self.selectedHotkey = parsedHotkey
        } else {
            self.selectedHotkey = .optionSpace
        }

        self.toggleShortcutEnabled = userDefaults.object(forKey: UserDefaultsKeys.toggleShortcutEnabled) as? Bool ?? true
        self.holdToDictateEnabled = userDefaults.object(forKey: UserDefaultsKeys.holdToDictateEnabled) as? Bool ?? false

        if let rawHoldHotkey = userDefaults.string(forKey: UserDefaultsKeys.holdShortcut),
           let parsedHoldHotkey = HotkeyBinding.from(rawValue: rawHoldHotkey) {
            self.holdShortcut = parsedHoldHotkey
        } else {
            self.holdShortcut = .optionShiftSpace
        }

        self.showMenuBarShortcutHints = userDefaults.object(forKey: UserDefaultsKeys.showMenuBarShortcutHints) as? Bool ?? false
        self.debugModeEnabled = userDefaults.object(forKey: UserDefaultsKeys.debugModeEnabled) as? Bool ?? false
        if let rawDeliveryMode = userDefaults.string(forKey: UserDefaultsKeys.finalResultDeliveryMode),
           let parsedDeliveryMode = FinalResultDeliveryMode(rawValue: rawDeliveryMode) {
            self.finalResultDeliveryMode = parsedDeliveryMode
        } else {
            self.finalResultDeliveryMode = .insert
        }
        self.clipboardFallbackWhenNoTarget = userDefaults.object(forKey: UserDefaultsKeys.clipboardFallbackWhenNoTarget) as? Bool ?? false

        if let rawLiveRewriteScope = userDefaults.string(forKey: UserDefaultsKeys.liveRewriteScope),
           let parsedLiveRewriteScope = LiveRewriteScope(rawValue: rawLiveRewriteScope) {
            self.liveRewriteScope = parsedLiveRewriteScope
        } else {
            self.liveRewriteScope = .currentSentence
        }

        self.aiProcessingEnabled = userDefaults.object(forKey: UserDefaultsKeys.aiProcessingEnabled) as? Bool ?? false
        self.selectedAIModelID = userDefaults.string(forKey: UserDefaultsKeys.selectedAIModelID)

        if userDefaults.object(forKey: UserDefaultsKeys.aiProcessingApplyDuringLiveInsertion) != nil {
            self.aiProcessingApplyDuringLiveInsertion = userDefaults.bool(forKey: UserDefaultsKeys.aiProcessingApplyDuringLiveInsertion)
        } else if userDefaults.string(forKey: UserDefaultsKeys.legacyAIProcessingScope) == "liveAndFinal" {
            self.aiProcessingApplyDuringLiveInsertion = true
        } else {
            self.aiProcessingApplyDuringLiveInsertion = false
        }

        if userDefaults.object(forKey: UserDefaultsKeys.aiProcessingApplyToFinalResult) != nil {
            self.aiProcessingApplyToFinalResult = userDefaults.bool(forKey: UserDefaultsKeys.aiProcessingApplyToFinalResult)
        } else {
            self.aiProcessingApplyToFinalResult = true
        }

        if let rawAIWritingStyle = userDefaults.string(forKey: UserDefaultsKeys.aiWritingStyle),
           let parsedAIWritingStyle = AIWritingStyle(rawValue: rawAIWritingStyle) {
            self.aiWritingStyle = parsedAIWritingStyle
        } else {
            self.aiWritingStyle = .none
        }

        if let rawAISalutation = userDefaults.string(forKey: UserDefaultsKeys.aiSalutation),
           let parsedAISalutation = AISalutation(rawValue: rawAISalutation) {
            self.aiSalutation = parsedAISalutation
        } else {
            self.aiSalutation = .none
        }

        let persistedRemoteProviders: [AIRemoteProviderConfiguration]
        if let data = userDefaults.data(forKey: UserDefaultsKeys.remoteProviders),
           let decoded = try? JSONDecoder().decode([AIRemoteProviderConfiguration].self, from: data) {
            persistedRemoteProviders = decoded
        } else {
            persistedRemoteProviders = []
        }
        self.remoteProviders = persistedRemoteProviders

        let initialSelectedRemoteProviderID = userDefaults.string(forKey: UserDefaultsKeys.selectedRemoteProviderID)
            ?? persistedRemoteProviders.first?.id
        self.selectedRemoteProviderID = initialSelectedRemoteProviderID

        self.snippetStore = SnippetStore(fileURL: Self.snippetStorageURL())
        self.historyStore = TranscriptHistoryStore(fileURL: Self.historyStorageURL())
        self.auditLogger = AuditLogger(fileURL: Self.auditLogStorageURL())
        self.debugLogger = AuditLogger(fileURL: Self.debugLogStorageURL())
        self.licenseController = LicenseController(configuration: configuration, cacheFileURL: Self.legacyLicenseCacheURL())
        self.remoteProviderAPIKeyDraft = initialSelectedRemoteProviderID.flatMap {
            aiRemoteProviderSecretStore.loadAPIKey(providerID: $0)
        } ?? ""

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
        registerSelectedHotkey(force: true)

        loadSnippets()
        loadHistory()
        updateCapabilitySummary()
        rebuildAIProcessingStack(reason: "initial-load")
        updateUpdaterState()
        loadExistingLicense()
        dictationRuntime.prepareRuntime()
        refreshPermissionStates()
        configureLifecycleObservers()
    }

    deinit {
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
        updaterConfigured = updaterController.isConfigured
        updaterStatusText = updaterController.statusText
        updaterFeedURLText = updaterController.feedURLDescription
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
            appendDiagnostic("\(provider.displayName) wurde als API-Anbieter hinzugefügt. Hinterlege jetzt den API-Key und lade die Modelle.")
        } else {
            appendDiagnostic("\(provider.displayName) wurde als API-Anbieter hinzugefügt. Du kannst den Modellkatalog jetzt direkt laden.")
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
        guard let selectedRemoteProviderID,
              let index = remoteProviders.firstIndex(where: { $0.id == selectedRemoteProviderID }) else {
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
                try aiRemoteProviderSecretStore.saveAPIKey(trimmed, providerID: selectedRemoteProviderID)
                appendDiagnostic("API-Key für den gewählten Anbieter im Keychain gespeichert.")
            } catch {
                appendDiagnostic("API-Key konnte nicht gespeichert werden: \(error.localizedDescription)")
            }
        }

        rebuildAIProcessingStack(reason: "remote-provider-api-key")
    }

    func refreshSelectedRemoteProviderModels() {
        guard let selectedRemoteProvider else { return }
        let apiKey = aiRemoteProviderSecretStore.loadAPIKey(providerID: selectedRemoteProvider.id) ?? ""
        if selectedRemoteProvider.requiresAPIKey,
           apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            appendDiagnostic("Für den gewählten API-Anbieter fehlt ein API-Key.")
            return
        }

        appendDiagnostic("Lade Modellkatalog für \(selectedRemoteProvider.displayName)...")
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let models = try await OpenAICompatibleRemoteTextProcessor.discoverModels(
                    configuration: selectedRemoteProvider,
                    apiKey: apiKey
                )
                self.updateSelectedRemoteProvider { provider in
                    provider.discoveredModels = models
                }
                self.rebuildAIProcessingStack(reason: "remote-models-refreshed")
                self.appendDiagnostic("Modellkatalog für \(selectedRemoteProvider.displayName) aktualisiert: \(models.count) Modelle.")
            } catch {
                self.appendDiagnostic("Modellkatalog konnte nicht geladen werden: \(error.localizedDescription)")
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
        appendAudit("session.toggle.menuBar start mode=\(options.mode) language=\(selectedLanguage.rawValue) profile=\(performanceProfile.rawValue)")

        guard dictationCapability.allowsDirectInsertion else {
            dictationRuntime.start(options: options)
            return
        }

        restorePreviousApplicationAndStart(options: options, source: "menuBar")
    }

    private func startTranscriptionForShortcut() {
        let options = currentStartOptions()
        appendAudit("session.toggle start mode=\(options.mode) language=\(selectedLanguage.rawValue) profile=\(performanceProfile.rawValue)")

        if dictationCapability.allowsDirectInsertion,
           shouldRestorePreviousApplicationBeforeStarting(),
           let previousApplication = lastExternalApplication {
            appendDiagnostic("Wechsle vor dem Start zurück zur letzten App, um das fokussierte Textfeld zu verwenden.")
            restorePreviousApplicationAndStart(options: options, source: "shortcut", preferredApplication: previousApplication)
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
            liveRewriteScope: liveRewriteScope,
            snippetRules: snippetRules,
            finalResultDeliveryMode: finalResultDeliveryMode,
            clipboardFallbackWhenNoTarget: clipboardFallbackWhenNoTarget,
            aiProcessing: aiProcessingConfiguration
        )
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
                self.appendDiagnostic("Aktiviere die letzte App erneut, damit das Ziel-Textfeld fokussiert bleibt.")
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

    private func waitForFrontmostApplication(bundleIdentifier: String, timeoutNanoseconds: UInt64 = 1_500_000_000) async -> Bool {
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
            appendDiagnostic("Snippet wurde nicht gespeichert: Trigger/Replacement darf nicht leer sein.")
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
        let joined = transcriptHistory
            .reversed()
            .map { "[\(Self.displayDate($0.createdAt))] [\($0.mode)] [\($0.languageCode)] \($0.text)" }
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
            "Debug mode: \(debugModeEnabled ? "enabled" : "disabled")",
            "",
            diagnosticsText,
            "",
            "Debug Log",
            debugLogText.isEmpty ? "No debug events captured." : debugLogText
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

    func exportDebugLog() {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "wispr-debug.log"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try debugLogger.export(to: url)
            appendDiagnostic("Debug-Log exportiert")
            appendAudit("debug.export path=\(url.path)")
        } catch {
            appendDiagnostic("Debug-Log-Export fehlgeschlagen: \(error.localizedDescription)")
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

        if case let .active(tier) = snapshot.status {
            appendAudit("license.activate tier=\(tier)")
        }
    }

    func deactivateLicense() {
        licenseController.deactivate()
        applyLicenseSnapshot(LicenseStatusSnapshot(status: .notSet, maskedKey: nil), clearInput: true)
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
        case let .failed(reason):
            appendDiagnostic("Finales Transkript konnte nicht zugestellt werden: \(reason)")
        }
        appendAudit("transcript.final language=\(event.languageCode) mode=\(entry.mode) chars=\(trimmed.count)")
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
        case let .active(tier):
            licenseStatusText = "Aktiv: \(tier)"
            licensePresentationState = .active(tier: tier)
        case let .invalid(reason):
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

    private func updateCapabilitySummary() {
        let profile = capabilityProfiler.profile()
        let memoryGB = Double(profile.physicalMemoryBytes) / 1_073_741_824
        capabilitySummary = "CPU: \(profile.activeProcessorCount)/\(profile.processorCount), RAM: \(String(format: "%.1f", memoryGB)) GB, Thermal: \(profile.thermalState)"
    }

    func refreshPermissionStates() {
        microphonePermissionStatus = permissionController.microphoneStatus()
        accessibilityPermissionStatus = permissionController.accessibilityStatus()
    }

    private func schedulePermissionRefresh() {
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            self?.refreshOperationalState(reason: "delayed-permission-refresh")
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
            guard let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                return
            }
            guard application.bundleIdentifier != Bundle.main.bundleIdentifier else {
                return
            }
            Task { @MainActor [weak self] in
                self?.lastExternalApplication = application
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
        refreshPermissionStates()
        dictationRuntime.prepareRuntime()
        updateUpdaterState()
        appendAudit("lifecycle.refresh reason=\(reason)")
    }

    private func persistRemoteProviders() {
        guard let data = try? JSONEncoder().encode(remoteProviders) else { return }
        userDefaults.set(data, forKey: UserDefaultsKeys.remoteProviders)
    }

    private func rebuildAIProcessingStack(reason: String) {
        aiProcessingService = AIProcessingService(providers: makeAIProviders())
        dictationRuntime.setAIProcessingService(aiProcessingService)
        let catalog = aiProcessingService.catalog()
        aiModels = catalog.allModels

        if selectedAIModelID == nil {
            selectedAIModelID = catalog.availableModels.first?.id
        }

        if aiProcessingEnabled,
           let selectedAIModel,
           !selectedAIModel.availability.isAvailable {
            aiProcessingEnabled = false
            appendDiagnostic("AI-Verarbeitung wurde deaktiviert, weil das ausgewählte Modell aktuell nicht verfügbar ist.")
        }

        appendAudit("ai.catalog.refresh reason=\(reason) models=\(aiModels.count) available=\(catalog.availableModels.count)")
    }

    private func makeAIProviders() -> [any AITextProcessingProviding] {
        var providers: [any AITextProcessingProviding] = [AppleFoundationTextProcessor()]

        for provider in remoteProviders where provider.isEnabled {
            let apiKey = aiRemoteProviderSecretStore.loadAPIKey(providerID: provider.id) ?? ""
            if provider.requiresAPIKey,
               apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                continue
            }

            providers.append(OpenAICompatibleRemoteTextProcessor(configuration: provider, apiKey: apiKey))
        }

        return providers
    }

    private func registerSelectedHotkey(force: Bool) {
        let didRegister = hotkeyManager.register(
            shortcut: selectedHotkey,
            shortcutEnabled: toggleShortcutEnabled,
            holdShortcut: holdShortcut,
            holdEnabled: holdToDictateEnabled,
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
            if let hotkeyAdvisory {
                appendDiagnostic("Shortcut-Hinweis: \(hotkeyAdvisory.title) – \(hotkeyAdvisory.message)")
            }
            if holdToDictateEnabled, let holdShortcutAdvisory {
                appendDiagnostic("Hold-Hinweis: \(holdShortcutAdvisory.title) – \(holdShortcutAdvisory.message)")
            }
            appendAudit(
                "hotkey.register value=\(selectedHotkey.rawValue) enabled=\(toggleShortcutEnabled) hold=\(holdShortcut.rawValue) holdEnabled=\(holdToDictateEnabled)"
            )
        } else {
            appendDiagnostic("Globaler Shortcut konnte nicht registriert werden: \(selectedHotkey.displayName)")
            appendAudit("hotkey.register_failed value=\(selectedHotkey.rawValue)")
        }
    }

    private func updateUpdaterState() {
        updaterConfigured = appConfiguration.isUpdaterConfigured
        updaterFeedURLText = appConfiguration.sparkleFeedURL?.absoluteString ?? ""
        updaterStatusText = appConfiguration.isUpdaterConfigured
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
        let base = (try? fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
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
}
