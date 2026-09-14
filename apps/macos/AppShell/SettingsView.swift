import AIProcessingCore
import ASRCore
import AppKit
import SnippetCore
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: MacAppState
    @AppStorage("wispr.uiLanguage") var uiLanguageRaw: String = AppLanguage.system.rawValue

    @State var diagnosticsExpanded = false
    @State var newSnippetTrigger: String = ""
    @State var newSnippetReplacement: String = ""
    @State private var searchText: String = ""
    @State private var splitColumnVisibility: NavigationSplitViewVisibility = .all
    @AppStorage("cortexa.settings.selected-tab") private var persistedSettingsTabID = SettingsTab.general.persistenceID
    @State var selectedRemoteProviderPreset: AIRemoteProviderPreset?
    @State var addProviderDisclosureExpanded = false
    @State var speechModelSearchText: String = ""
    @State var speechModelAvailabilityFilter: SpeechModelAvailabilityFilter = .all
    @State var speechModelLanguageFilter: SpeechModelLanguageFilter = .all
    @State var newDictionaryTerm: String = ""
    @State var newDictionaryLanguageCode: String = ""
    @State var newDictionaryCategory: DictionaryTermCategory = .personalTerm
    @State var editingDictionaryTermID: UUID?
    @State var editingDictionaryTerm: String = ""
    @State var editingDictionaryLanguageCode: String = ""
    @State var editingDictionaryCategory: DictionaryTermCategory = .personalTerm
    @State var pendingVoiceModelForInstallation: VoiceModelDescriptor?
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    let personalWebsiteURL = URL(string: "https://leon-stadler.com")!
    let projectRepositoryURL = URL(string: "https://github.com/LeonStadler/Cortexa")!

    var appMarketingVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    var appBuildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }

    /// Suchergebnisse: App-Metadaten nur bei passenden Suchbegriffen, damit die Liste nicht aufgebläht wird.
    var aboutAppMetadataMatchesSearch: Bool {
        matches([
            "version", "build", "app", "wispr", "wisprlocal", "bundle", "cfbundle",
        ])
    }

    var trimmedNewSnippetTrigger: String {
        newSnippetTrigger.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedNewSnippetReplacement: String {
        newSnippetReplacement.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var newSnippetTriggerIsDuplicate: Bool {
        let trigger = trimmedNewSnippetTrigger
        guard !trigger.isEmpty else { return false }
        return appState.snippetRules.contains { rule in
            rule.caseSensitive
                ? rule.trigger == trigger
                : rule.trigger.lowercased() == trigger.lowercased()
        }
    }

    var canCommitNewSnippet: Bool {
        !trimmedNewSnippetTrigger.isEmpty
            && !trimmedNewSnippetReplacement.isEmpty
            && !newSnippetTriggerIsDuplicate
    }

    func commitNewSnippet() {
        guard canCommitNewSnippet else { return }
        appState.addSnippet(
            trigger: trimmedNewSnippetTrigger,
            replacement: trimmedNewSnippetReplacement
        )
        newSnippetTrigger = ""
        newSnippetReplacement = ""
    }

    private var trimmedNewDictionaryTerm: String {
        newDictionaryTerm.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedNewDictionaryLanguageCode: String {
        newDictionaryLanguageCode.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canCommitNewDictionaryTerm: Bool {
        !trimmedNewDictionaryTerm.isEmpty
    }

    var trimmedEditingDictionaryTerm: String {
        editingDictionaryTerm.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedEditingDictionaryLanguageCode: String {
        editingDictionaryLanguageCode.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canCommitEditingDictionaryTerm: Bool {
        editingDictionaryTermID != nil && !trimmedEditingDictionaryTerm.isEmpty
    }

    func commitNewDictionaryTerm() {
        guard canCommitNewDictionaryTerm else { return }
        appState.addDictionaryTerm(
            trimmedNewDictionaryTerm,
            category: newDictionaryCategory,
            languageCode: trimmedNewDictionaryLanguageCode.isEmpty
                ? nil
                : trimmedNewDictionaryLanguageCode
        )
        newDictionaryTerm = ""
        newDictionaryLanguageCode = ""
        newDictionaryCategory = .personalTerm
    }

    func beginEditingDictionaryTerm(_ term: DictionaryTerm) {
        editingDictionaryTermID = term.id
        editingDictionaryTerm = term.term
        editingDictionaryLanguageCode = term.languageCode ?? ""
        editingDictionaryCategory = term.category
    }

    func cancelEditingDictionaryTerm() {
        editingDictionaryTermID = nil
        editingDictionaryTerm = ""
        editingDictionaryLanguageCode = ""
        editingDictionaryCategory = .personalTerm
    }

    func commitEditingDictionaryTerm() {
        guard let termID = editingDictionaryTermID, canCommitEditingDictionaryTerm else { return }
        appState.updateDictionaryTerm(
            termID: termID,
            term: trimmedEditingDictionaryTerm,
            category: editingDictionaryCategory,
            languageCode: trimmedEditingDictionaryLanguageCode.isEmpty
                ? nil
                : trimmedEditingDictionaryLanguageCode
        )
        cancelEditingDictionaryTerm()
    }

    private var storedLanguage: AppLanguage {
        AppLanguage(rawValue: uiLanguageRaw) ?? .system
    }

    var effectiveLanguage: AppLanguage {
        storedLanguage.contentLanguage
    }

    func text(_ german: String, _ english: String) -> String {
        storedLanguage.text(german, english)
    }

    func erasedView<Content: View>(@ViewBuilder _ content: () -> Content) -> AnyView {
        AnyView(content())
    }

    func formattedHistoryDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = storedLanguage.localeForFormatting
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }

    private var settingsSearchPresentation: SettingsSearchPresentation {
        SettingsSearchPresentation(
            searchText: searchText,
            language: storedLanguage
        )
    }

    var isSearching: Bool {
        settingsSearchPresentation.isSearching
    }

    /// Live rewrite / adjustment radius affects streaming partials only.
    var isLiveRewriteScopeApplicable: Bool {
        appState.streamingEnabled
            && appState.finalResultDeliveryMode != .clipboardOnly
            && appState.dictationCapability.allowsDirectInsertion
    }

    func matches(_ keywords: [String]) -> Bool {
        settingsSearchPresentation.matches(keywords)
    }

    var filteredHistory: [TranscriptHistoryEntry] {
        appState.transcriptHistory
    }

    var compactHistoryEntries: [TranscriptHistoryEntry] {
        Array(appState.transcriptHistory.prefix(12))
    }

    var filteredSnippets: [SnippetRule] {
        appState.snippetRules
    }

    var filteredDictionaryTerms: [DictionaryTerm] {
        appState.dictionaryTerms
    }

    var filteredDictionaryReviewQueue: [DictionaryReviewCandidate] {
        appState.dictionaryReviewQueue
    }

    var generalHasMatches: Bool {
        settingsSearchPresentation.hasResults(in: .general)
    }

    var dictationHasMatches: Bool {
        settingsSearchPresentation.hasResults(in: .dictation)
    }

    var speechHasMatches: Bool {
        settingsSearchPresentation.hasResults(in: .speech)
    }

    var shortcutsHasMatches: Bool {
        settingsSearchPresentation.hasResults(in: .shortcuts)
    }

    var aiHasMatches: Bool {
        settingsSearchPresentation.hasResults(in: .ai)
    }

    var historyHasMatches: Bool {
        settingsSearchPresentation.hasResults(in: .history)
    }

    var aboutHasMatches: Bool {
        settingsSearchPresentation.hasResults(in: .about)
    }

    var snippetsHasMatches: Bool {
        settingsSearchPresentation.hasResults(in: .snippets)
    }

    var dictionaryHasMatches: Bool {
        settingsSearchPresentation.hasResults(in: .dictionary)
    }

    var advancedHasMatches: Bool {
        settingsSearchPresentation.hasResults(in: .advanced)
    }

    var soundHasMatches: Bool {
        settingsSearchPresentation.hasResults(in: .sound)
    }

    var compressedDiagnosticsText: String {
        let lines = appState.diagnosticsText
            .split(separator: "\n")
            .map(String.init)
        let preview = lines.suffix(8).joined(separator: "\n")
        return preview.isEmpty ? appState.diagnosticsText : preview
    }

    var body: some View {
        SettingsViewShell(
            splitColumnVisibility: $splitColumnVisibility,
            searchText: $searchText,
            storedLanguage: storedLanguage,
            selectedTabSelection: selectedTabSelection,
            currentSelectedTab: currentSelectedTab,
            selectedForm: AnyView(selectedForm),
            searchResults: settingsSearchPresentation.results,
            onSelectSearchResult: selectSearchResult,
            accessibilityReduceMotion: accessibilityReduceMotion,
            toolbarAccessoryContent: settingsToolbarAccessoryContent,
            onRefreshPermissionStates: {
                appState.refreshPermissionStatesWithStabilization()
            }
        )
        .onAppear {
            appState.selectedSettingsTab = SettingsTab(rawValue: persistedSettingsTabID) ?? .general
        }
        .onChange(of: currentSelectedTab) { _, tab in
            persistedSettingsTabID = tab.persistenceID
        }
    }

    @ViewBuilder
    private var selectedForm: some View {
        switch currentSelectedTab {
        case .general:
            GeneralSettingsPage(
                appSectionTitle: text("App", "App"),
                menuBarSectionTitle: text("Menüleiste", "Menu bar"),
                accessSectionTitle: text("Zugriff", "Access"),
                appContent: erasedView { generalAppearanceContent },
                menuBarContent: erasedView { generalMenuBarContent },
                accessContent: erasedView { generalPermissionsContent },
                showsAccessSection: appState.microphonePermissionStatus != .granted
                    || appState.accessibilityPermissionStatus != .granted
            )
        case .speech:
            SpeechSettingsPage(
                modelSectionTitle: text("Modell", "Model"),
                languageSectionTitle: text("Sprache", "Language"),
                qualitySectionTitle: text("Qualität", "Quality"),
                translationSectionTitle: text("Übersetzung", "Translation"),
                installedModelsSectionTitle: text("Modellverwaltung", "Model management"),
                modelSelectionContent: erasedView { speechModelSelectionContent },
                languageContent: erasedView { speechLanguageContent },
                qualityContent: erasedView { speechQualityContent },
                translationContent: erasedView { translationContent },
                installedModelsContent: erasedView { installedSpeechModelsContent }
            )
        case .dictation:
            DictationSettingsPage(
                liveRewritingSectionTitle: text("Live-Anpassung", "Live rewriting"),
                textInputSectionTitle: text("Texteingabe", "Text input"),
                liveRewriteContent: erasedView { liveRewriteContent },
                deliveryContent: erasedView { dictationDeliveryContent }
            )
        case .sound:
            SoundSettingsPage(
                inputSectionTitle: text("Eingang", "Input"),
                feedbackSectionTitle: text("Rückmeldung", "Feedback"),
                inputContent: erasedView { soundInputContent },
                feedbackContent: erasedView { soundFeedbackContent }
            )
        case .shortcuts:
            ShortcutsSettingsPage(
                startStopSectionTitle: text("Start / Stopp", "Start / Stop"),
                holdSectionTitle: text("Halten zum Diktieren", "Hold to Dictate"),
                cancelSectionTitle: text("Abbrechen", "Cancel"),
                modeSwitchSectionTitle: text("Moduswechsel", "Mode switch"),
                startStopContent: erasedView { startStopShortcutContent },
                holdContent: erasedView { holdShortcutContent },
                cancelContent: erasedView { cancelShortcutContent },
                modeSwitchContent: erasedView { modeSwitchShortcutContent }
            )
        case .ai:
            AISettingsPage(
                processingSectionTitle: text("Verarbeitung", "Processing"),
                providersSectionTitle: text("Anbieter", "Providers"),
                modelsSectionTitle: text("Modelle", "Models"),
                processingContent: erasedView { aiProcessingContent },
                providerContent: erasedView { aiProviderContent },
                modelContent: erasedView { aiModelContent }
            )
        case .history:
            HistorySettingsPage(
                actionsSectionTitle: text("Aktionen", "Actions"),
                retentionSectionTitle: text("Aufbewahrung", "Retention"),
                entriesSectionTitle: text("Transkriptverlauf", "Transcript History"),
                actionsContent: erasedView { historyActionContent },
                retentionContent: erasedView { historyRetentionContent },
                entriesContent: erasedView { historyEntriesContent }
            )
        case .about:
            AboutSettingsPage(
                aboutMeSectionTitle: text("Über mich", "About me"),
                changelogSectionTitle: text("Changelog", "Changelog"),
                supportSectionTitle: text("Support", "Support"),
                developerContent: erasedView { aboutDeveloperRows },
                changelogContent: erasedView { aboutChangelogContent },
                supportContent: erasedView { aboutSupportContent }
            )
        case .dictionary:
            DictionarySettingsPage(
                newEntrySectionTitle: text("Neuer Begriff", "New term"),
                reviewQueueSectionTitle: text("Vorschläge", "Review queue"),
                savedTermsSectionTitle: text("Gespeicherte Begriffe", "Saved terms"),
                newEntryContent: erasedView { dictionaryNewEntryRows },
                reviewQueueContent: erasedView { dictionaryReviewQueueRows },
                savedTermsContent: erasedView { dictionarySavedRows }
            )
        case .snippets:
            SnippetsSettingsPage(
                newSnippetSectionTitle: text("Neues Snippet", "New snippet"),
                importExportSectionTitle: text("Import und Export", "Import and export"),
                savedSnippetsSectionTitle: text("Gespeicherte Snippets", "Saved snippets"),
                newSnippetContent: erasedView { snippetNewEntryRows },
                importExportContent: erasedView { snippetImportExportRows },
                savedContent: erasedView { snippetSavedRows }
            )
                case .advanced:
            AdvancedSettingsPage(
                appSectionTitle: text("App", "App"),
                modelRuntimeSectionTitle: text("Modelllaufzeit", "Model runtime"),
                storageLocationSectionTitle: text("Speicherort", "Storage location"),
                updatesSectionTitle: text("Updates", "Updates"),
                diagnosticsSectionTitle: text("Diagnose", "Diagnostics"),
                permissionsSectionTitle: text("Berechtigungen", "Permissions"),
                appInfoContent: erasedView { aboutAppInfoRows },
                runtimeContent: erasedView { voiceModelRuntimeContent },
                storageContent: erasedView { advancedStorageContent },
                updatesContent: erasedView { updatesContent },
                diagnosticsContent: erasedView { diagnosticsContent },
                permissionsContent: erasedView { advancedPermissionsContent }
            )
        }
    }

    private var selectedTabSelection: Binding<SettingsTab> {
        Binding(
            get: { appState.selectedSettingsTab },
            set: { newValue in
                // List(selection:) schreibt während View-Updates; @Published sofort zu setzen löst
                // „Publishing changes from within view updates“ aus.
                DispatchQueue.main.async {
                    appState.selectedSettingsTab = newValue
                }
            }
        )
    }

    private func selectSearchResult(_ result: SettingsSearchDestination) {
        appState.selectedSettingsTab = result.tab
        searchText = ""
    }

    private var currentSelectedTab: SettingsTab {
        appState.selectedSettingsTab
    }

    private var settingsToolbarAccessoryContent: AnyView? {
        switch currentSelectedTab {
        case .dictionary:
            return erasedView { dictionaryToolbarActions }
        default:
            return nil
        }
    }

    func copyToClipboard(_ string: String) {
        guard !string.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }

}
