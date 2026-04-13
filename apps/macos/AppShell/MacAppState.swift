import AppKit
import AVFoundation
import Foundation
import SwiftUI
import ApplicationServices
import SnippetCore
import CapabilityCore
import LicenseCore
import AIProcessingCore
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

extension ContextAwarenessMode {
    func localizedDisplayName(interfaceLanguageCode: String) -> String {
        switch (interfaceLanguageCode, self) {
        case ("en", .off):
            return "Off"
        case ("en", .finalOnly):
            return "Final only"
        case ("en", .liveOnly):
            return "Live only"
        case ("en", .liveAndFinal):
            return "Live and final"
        case (_, .off):
            return "Aus"
        case (_, .finalOnly):
            return "Nur final"
        case (_, .liveOnly):
            return "Nur live"
        case (_, .liveAndFinal):
            return "Live und final"
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

    @Published var muteMusicWhileDictating: Bool {
        didSet {
            userDefaults.set(muteMusicWhileDictating, forKey: UserDefaultsKeys.muteMusicWhileDictating)
        }
    }

    @Published var contextAwarenessMode: ContextAwarenessMode {
        didSet {
            userDefaults.set(contextAwarenessMode.rawValue, forKey: UserDefaultsKeys.contextAwarenessMode)
        }
    }

    @Published var dictionaryAutoAddEnabled: Bool {
        didSet {
            userDefaults.set(dictionaryAutoAddEnabled, forKey: UserDefaultsKeys.dictionaryAutoAddEnabled)
        }
    }

    @Published var formattingEnabled: Bool {
        didSet {
            userDefaults.set(formattingEnabled, forKey: UserDefaultsKeys.formattingEnabled)
        }
    }

    @Published var formattingScope: AIProcessingScope {
        didSet {
            userDefaults.set(formattingScope.rawValue, forKey: UserDefaultsKeys.formattingScope)
        }
    }

    @Published var snippetRules: [SnippetRule] = []
    @Published var transcriptHistory: [TranscriptHistoryEntry] = []
    @Published var dictionaryTerms: [DictionaryTerm] = []
    @Published var dictionaryReviewQueue: [DictionaryReviewCandidate] = []

    @Published var recordingStatus: String = "Idle"
    @Published var diagnosticsText: String = "Initializing ASR runtime..."
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

    private enum UserDefaultsKeys {
        static let streamingEnabled = "wispr.settings.streamingEnabled"
        static let selectedLanguage = "wispr.settings.selectedLanguage"
        static let performanceProfile = "wispr.settings.performanceProfile"
        static let selectedHotkey = "wispr.settings.selectedHotkey"
        static let toggleShortcutEnabled = "wispr.settings.toggleShortcutEnabled"
        static let holdToDictateEnabled = "wispr.settings.holdToDictateEnabled"
        static let holdShortcut = "wispr.settings.holdShortcut"
        static let finalResultDeliveryMode = "wispr.settings.finalResultDeliveryMode"
        static let clipboardFallbackWhenNoTarget = "wispr.settings.clipboardFallbackWhenNoTarget"
        static let liveRewriteScope = "wispr.settings.liveRewriteScope"
        static let showMenuBarShortcutHints = "wispr.settings.showMenuBarShortcutHints"
        static let muteMusicWhileDictating = "wispr.settings.muteMusicWhileDictating"
        static let contextAwarenessMode = "wispr.settings.contextAwarenessMode"
        static let dictionaryAutoAddEnabled = "wispr.settings.dictionaryAutoAddEnabled"
        static let formattingEnabled = "wispr.settings.formattingEnabled"
        static let formattingScope = "wispr.settings.formattingScope"
    }

    private let userDefaults: UserDefaults
    private let hotkeyManager = GlobalHotkeyManager()
    private let dictationRuntime = DictationRuntime()
    private let snippetStore: SnippetStore
    private let historyStore: TranscriptHistoryStore
    private let dictionaryStore: PersonalDictionaryStore
    private let auditLogger: AuditLogging
    private let permissionController: PermissionControlling
    private let capabilityProfiler = CapabilityProfiler()
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
        self.muteMusicWhileDictating = userDefaults.object(forKey: UserDefaultsKeys.muteMusicWhileDictating) as? Bool ?? false
        self.dictionaryAutoAddEnabled = userDefaults.object(forKey: UserDefaultsKeys.dictionaryAutoAddEnabled) as? Bool ?? false
        self.formattingEnabled = userDefaults.object(forKey: UserDefaultsKeys.formattingEnabled) as? Bool ?? false

        if let rawContextMode = userDefaults.string(forKey: UserDefaultsKeys.contextAwarenessMode),
           let parsedContextMode = ContextAwarenessMode(rawValue: rawContextMode) {
            self.contextAwarenessMode = parsedContextMode
        } else {
            self.contextAwarenessMode = .finalOnly
        }

        if let rawFormattingScope = userDefaults.string(forKey: UserDefaultsKeys.formattingScope),
           let parsedFormattingScope = AIProcessingScope(rawValue: rawFormattingScope) {
            self.formattingScope = parsedFormattingScope
        } else {
            self.formattingScope = .finalOnly
        }

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

        self.snippetStore = SnippetStore(fileURL: Self.snippetStorageURL())
        self.historyStore = TranscriptHistoryStore(fileURL: Self.historyStorageURL())
        self.dictionaryStore = PersonalDictionaryStore(fileURL: Self.dictionaryStorageURL())
        self.auditLogger = AuditLogger(fileURL: Self.auditLogStorageURL())
        self.licenseController = LicenseController(configuration: configuration, cacheFileURL: Self.legacyLicenseCacheURL())

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
        loadDictionary()
        updateCapabilitySummary()
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

        let aiConfiguration = AIProcessingConfiguration(
            enabled: formattingEnabled,
            selectedModelID: "apple.ondevice",
            scope: formattingScope,
            contextAwarenessMode: contextAwarenessMode,
            style: .none,
            salutation: .none
        )

        return DictationStartOptions(
            mode: mode,
            language: selectedLanguage,
            translationOutput: .original,
            performance: performanceProfile,
            liveRewriteScope: liveRewriteScope,
            snippetRules: snippetRules,
            finalResultDeliveryMode: finalResultDeliveryMode,
            clipboardFallbackWhenNoTarget: clipboardFallbackWhenNoTarget,
            aiProcessing: aiConfiguration,
            muteMusicWhileDictating: muteMusicWhileDictating,
            asrInitialPrompt: buildDictionaryHintPrompt(),
            dictionaryTerms: dictionaryTerms.map(\.term),
            // TODO: replace AX-based extraction with a dedicated context provider per target app.
            appContextText: bestEffortFocusedContextText(maxLength: 600)
        )
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
        if dictionaryTerms.contains(where: { normalizedDictionaryKey($0.term, languageCode: $0.languageCode) == key }) {
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
        guard !dictionaryTerms.contains(where: { normalizedDictionaryKey($0.term, languageCode: $0.languageCode) == key }) else {
            return
        }
        guard !dictionaryReviewQueue.contains(where: { normalizedDictionaryKey($0.proposedTerm, languageCode: $0.languageCode) == key }) else {
            return
        }

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
            appendDiagnostic("Dictionary importiert: \(dictionaryTerms.count) Begriffe, \(dictionaryReviewQueue.count) Vorschläge")
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
                PersonalDictionarySnapshot(terms: dictionaryTerms, reviewQueue: dictionaryReviewQueue),
                to: url
            )
            appendDiagnostic("Dictionary exportiert: \(dictionaryTerms.count) Begriffe")
            appendAudit("dictionary.export path=\(url.path)")
        } catch {
            appendDiagnostic("Dictionary-Export fehlgeschlagen: \(error.localizedDescription)")
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
            "",
            diagnosticsText
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

        if dictionaryAutoAddEnabled {
            let queuedCount = autoQueueDictionaryCandidates(from: trimmed, languageCode: event.languageCode)
            if queuedCount > 0 {
                appendDiagnostic("Dictionary: \(queuedCount) neue Vorschläge automatisch erkannt.")
            }
        }

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
            queueDictionaryCandidate(
                phrase,
                category: .personName,
                languageCode: scopedLanguage
            )
            if dictionaryReviewQueue.count > queueCountBefore {
                added += 1
            }
            if added >= maxNewCandidates {
                return max(0, dictionaryReviewQueue.count - before)
            }
        }

        for token in matchedTerms(
            in: text,
            pattern: #"\b[\p{L}\d][\p{L}\d\-\._]{2,}\b"#
        ) {
            let normalizedToken = normalizeDictionaryCandidate(token)
            guard shouldAutoSuggestDictionaryToken(normalizedToken) else { continue }
            let key = normalizedDictionaryKey(normalizedToken, languageCode: scopedLanguage)
            guard !seenInTranscript.contains(key) else { continue }
            seenInTranscript.insert(key)
            let category: DictionaryTermCategory
            if normalizedToken.contains(where: { $0.isNumber }) || isUppercaseAcronym(normalizedToken) {
                category = .industryLanguage
            } else {
                category = .custom
            }
            let queueCountBefore = dictionaryReviewQueue.count
            queueDictionaryCandidate(normalizedToken, category: category, languageCode: scopedLanguage)
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
        let components = phrase
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
        guard components.count == 2 else { return false }
        guard components.allSatisfy({ !$0.isEmpty && !$0.contains(where: { $0.isNumber }) }) else { return false }
        guard components.allSatisfy({ !isLikelyCommonWord($0) }) else { return false }
        return true
    }

    private func normalizeDictionaryCandidate(_ candidate: String) -> String {
        candidate.trimmingCharacters(in: CharacterSet(charactersIn: " \t\n\r.,;:!?()[]{}\"'"))
    }

    private func isLikelyCommonWord(_ token: String) -> Bool {
        let normalized = token
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
        return Self.commonAutoAddStopwords.contains(normalized)
    }

    private static let commonAutoAddStopwords: Set<String> = [
        "aber", "als", "am", "an", "auch", "auf", "aus", "bei", "bin", "bist", "da", "dann",
        "das", "dein", "der", "des", "die", "dir", "doch", "du", "ein", "eine", "einer", "eines",
        "er", "es", "für", "hat", "hast", "hier", "ich", "im", "in", "ist", "ja", "kein", "mit",
        "nach", "nicht", "noch", "oder", "schon", "sein", "sind", "so", "und", "vom", "von",
        "war", "was", "wenn", "wie", "wir", "wird", "you", "your", "the", "this", "that", "and",
        "for", "from", "with", "have", "has", "are", "was", "were", "not", "but", "what", "when",
        "where", "which", "who", "why", "can", "could", "would", "should", "will"
    ]

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

    private func loadDictionary() {
        do {
            let snapshot = try dictionaryStore.load()
            dictionaryTerms = snapshot.terms
            dictionaryReviewQueue = snapshot.reviewQueue
            appendDiagnostic("Dictionary geladen: \(dictionaryTerms.count) Begriffe, \(dictionaryReviewQueue.count) Vorschläge")
        } catch {
            appendDiagnostic("Dictionary-Load fehlgeschlagen: \(error.localizedDescription)")
            dictionaryTerms = []
            dictionaryReviewQueue = []
        }
    }

    private func persistDictionary() {
        do {
            try dictionaryStore.save(terms: dictionaryTerms, reviewQueue: dictionaryReviewQueue)
            appendAudit("dictionary.save terms=\(dictionaryTerms.count) queue=\(dictionaryReviewQueue.count)")
        } catch {
            appendDiagnostic("Dictionary-Save fehlgeschlagen: \(error.localizedDescription)")
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
        refreshPermissionStates()
        dictationRuntime.prepareRuntime()
        updateUpdaterState()
        appendAudit("lifecycle.refresh reason=\(reason)")
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

    private static func dictionaryStorageURL() -> URL {
        appSupportDirectory().appendingPathComponent("personal-dictionary.json", isDirectory: false)
    }

    private static func auditLogStorageURL() -> URL {
        appSupportDirectory().appendingPathComponent("audit.log", isDirectory: false)
    }

    private static func legacyLicenseCacheURL() -> URL {
        appSupportDirectory().appendingPathComponent("license-cache.json", isDirectory: false)
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
                guard let languageCode = term.languageCode?.trimmingCharacters(in: .whitespacesAndNewlines), !languageCode.isEmpty else {
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
            if candidate.count > maxCharacters {
                break
            }
            result = candidate
        }

        return result == "Preferred terms: " ? nil : result
    }

    private func bestEffortFocusedContextText(maxLength: Int) -> String? {
        guard accessibilityPermissionStatus == .granted else {
            return nil
        }

        let systemWide = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        let focusedResult = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedRef
        )

        guard focusedResult == .success, let focusedElement = focusedRef as? AXUIElement else {
            return nil
        }

        var valueRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(focusedElement, kAXValueAttribute as CFString, &valueRef) == .success,
              let fullText = valueRef as? String else {
            return nil
        }

        let trimmed = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var selectedRangeRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(focusedElement, kAXSelectedTextRangeAttribute as CFString, &selectedRangeRef) == .success,
           let axValue = selectedRangeRef,
           CFGetTypeID(axValue) == AXValueGetTypeID() {
            let selectedRangeValue = axValue as! AXValue
            var range = CFRange(location: 0, length: 0)
            if AXValueGetType(selectedRangeValue) == .cfRange,
               AXValueGetValue(selectedRangeValue, .cfRange, &range) {
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
        let window = String(text[startIndex..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        return window.isEmpty ? nil : window
    }
}
