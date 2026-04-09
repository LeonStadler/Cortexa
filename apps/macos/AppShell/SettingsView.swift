import AIProcessingCore
import ASRCore
import AppKit
import SnippetCore
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: MacAppState
    @AppStorage("wispr.uiLanguage") private var uiLanguageRaw: String = AppLanguage.system.rawValue

    @State private var diagnosticsExpanded = false
    @State private var newSnippetTrigger: String = ""
    @State private var newSnippetReplacement: String = ""
    @State private var searchText: String = ""
    @State private var splitColumnVisibility: NavigationSplitViewVisibility = .all
    @State private var showsTabInfoPopover = false
    @State private var selectedRemoteProviderPreset: AIRemoteProviderPreset?
    @State private var addProviderDisclosureExpanded = false
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    private let personalWebsiteURL = URL(string: "https://leon-stadler.com")!

    private var appMarketingVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    private var appBuildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }

    /// Suchergebnisse: App-Metadaten nur bei passenden Suchbegriffen, damit die Liste nicht aufgebläht wird.
    private var aboutAppMetadataMatchesSearch: Bool {
        matches([
            "version", "build", "app", "wispr", "wisprlocal", "bundle", "cfbundle",
        ])
    }

    private var trimmedNewSnippetTrigger: String {
        newSnippetTrigger.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedNewSnippetReplacement: String {
        newSnippetReplacement.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var newSnippetTriggerIsDuplicate: Bool {
        let trigger = trimmedNewSnippetTrigger
        guard !trigger.isEmpty else { return false }
        return appState.snippetRules.contains { rule in
            rule.caseSensitive
                ? rule.trigger == trigger
                : rule.trigger.lowercased() == trigger.lowercased()
        }
    }

    private var canCommitNewSnippet: Bool {
        !trimmedNewSnippetTrigger.isEmpty
            && !trimmedNewSnippetReplacement.isEmpty
            && !newSnippetTriggerIsDuplicate
    }

    private func commitNewSnippet() {
        guard canCommitNewSnippet else { return }
        appState.addSnippet(
            trigger: trimmedNewSnippetTrigger,
            replacement: trimmedNewSnippetReplacement
        )
        newSnippetTrigger = ""
        newSnippetReplacement = ""
    }

    private var storedLanguage: AppLanguage {
        AppLanguage(rawValue: uiLanguageRaw) ?? .system
    }

    private var effectiveLanguage: AppLanguage {
        storedLanguage.contentLanguage
    }

    private func text(_ german: String, _ english: String) -> String {
        storedLanguage.text(german, english)
    }

    private func formattedHistoryDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = storedLanguage.localeForFormatting
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }

    private var searchQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var isSearching: Bool {
        !searchQuery.isEmpty
    }

    /// Etwas länger als die früheren 0,12s: besser im Takt mit Toolbar-Suchfeld (macOS) / Titelwechsel.
    private var searchFieldSyncedAnimation: Animation? {
        accessibilityReduceMotion ? nil : .easeInOut(duration: 0.26)
    }

    /// Kleiner vertikaler Shift neben Opacity — reiner Fade auf `Form`+Material wirkt oft „fragmentiert“.
    private var searchResultsContentTransition: AnyTransition {
        if accessibilityReduceMotion {
            .opacity
        } else {
            .opacity.combined(with: .offset(y: 7))
        }
    }

    /// Live rewrite / adjustment radius affects streaming partials only.
    private var isLiveRewriteScopeApplicable: Bool {
        appState.streamingEnabled
            && appState.finalResultDeliveryMode != .clipboardOnly
            && appState.dictationCapability.allowsDirectInsertion
    }

    private func matches(_ keywords: [String]) -> Bool {
        guard isSearching else { return true }
        return keywords.contains { $0.lowercased().contains(searchQuery) }
    }

    private func selectedRemoteProviderBinding<T>(
        _ keyPath: WritableKeyPath<AIRemoteProviderConfiguration, T>,
        default defaultValue: T
    ) -> Binding<T> {
        Binding(
            get: {
                appState.selectedRemoteProvider?[keyPath: keyPath] ?? defaultValue
            },
            set: { newValue in
                appState.updateSelectedRemoteProvider { provider in
                    provider[keyPath: keyPath] = newValue
                }
            }
        )
    }

    private var filteredHistory: [TranscriptHistoryEntry] {
        guard isSearching else {
            return appState.transcriptHistory
        }
        return appState.transcriptHistory.filter {
            $0.text.lowercased().contains(searchQuery)
                || $0.languageCode.lowercased().contains(searchQuery)
                || $0.mode.lowercased().contains(searchQuery)
        }
    }

    private var compactHistoryEntries: [TranscriptHistoryEntry] {
        if isSearching {
            return filteredHistory
        }
        return Array(filteredHistory.prefix(12))
    }

    private var filteredSnippets: [SnippetRule] {
        guard isSearching else {
            return appState.snippetRules
        }
        return appState.snippetRules.filter {
            $0.trigger.lowercased().contains(searchQuery)
                || $0.replacement.lowercased().contains(searchQuery)
        }
    }

    private var generalHasMatches: Bool {
        matches([
            "language", "sprache", "menüleiste", "menu bar", "shortcut hints", "compact", "kompakt",
            "dock", "launch on login", "updates", "zugriff", "permissions", "berechtigungen",
            "mikrofon", "accessibility", "bedienungshilfen",
        ])
    }

    private var dictationHasMatches: Bool {
        matches([
            "streaming",
            "clipboard",
            "zwischenablage",
            "insert",
            "delivery",
            "paste",
            "auto-send",
            "restore clipboard",
            "keypress",
            "anpassung",
            "anpassungsradius",
            "anpassen",
            "rückwirkung",
            "rückwirkend",
            "rückwirkungsbereich",
            "rueckwirkung",
            "rueckwirkend",
            "rueckwirkungsbereich",
            "rewrite",
            "kontext",
            "retroaktiv",
            "weit zurück",
        ])
    }

    private var speechHasMatches: Bool {
        matches([
            "speech",
            "voice",
            "sprache",
            "language",
            "translate",
            "translation",
            "übersetzung",
            "uebersetzung",
            "modell",
            "model",
            "anbieter",
            "provider",
            "whisper",
            "parakeet",
            "qualität",
            "quality",
            "installieren",
            "download",
        ])
    }

    private var shortcutsHasMatches: Bool {
        matches([
            "shortcut", "kurzbefehl", "hold", "dictation", "diktat", "cancel", "abbrechen", "mode",
            "modus",
        ])
    }

    private var aiHasMatches: Bool {
        matches([
            "ai",
            "processing",
            "modell",
            "model",
            "rewrite",
            "stil",
            "style",
            "ton",
            "tone",
            "anrede",
            "formal",
            "informal",
            "apple intelligence",
            "api",
            "openrouter",
            "provider",
            "anbieter",
            "key",
            "api key",
        ])
    }

    private var historyHasMatches: Bool {
        matches([
            "history", "verlauf", "transkript", "dictation", "diktat", "retention", "aufbewahrung",
            "storage", "folder",
        ]) || !filteredHistory.isEmpty
    }

    private var aboutHasMatches: Bool {
        matches([
            "about", "über", "ueber", "leon", "stadler", "website", "webseite", "proprietär",
            "proprietary", "lizenz", "intermedia", "design", "fotografie", "vorarlberg",
            "changelog",
            "neuigkeiten", "release", "release notes", "änderungen", "aenderungen",
        ])
    }

    private var snippetsHasMatches: Bool {
        matches([
            "snippet", "textbaustein", "replacement", "trigger", "json", "import", "export",
            "importieren", "exportieren",
        ]) || !filteredSnippets.isEmpty
    }

    private var advancedHasMatches: Bool {
        matches([
            "update", "updates", "aktualisierung", "diagnose", "diagnostics", "capability", "audit",
            "storage", "folder", "app support", "logs", "protokolle", "voice", "modell", "model",
            "warm", "dauer", "duration", "laufzeit", "speicher halten", "runtime",
            "version", "build", "app", "wispr", "wisprlocal", "bundle", "cfbundle",
        ]) || appState.diagnosticsText.lowercased().contains(searchQuery)
            || appState.capabilitySummary.lowercased().contains(searchQuery)
            || appState.updaterStatusText.lowercased().contains(searchQuery)
    }

    private var soundHasMatches: Bool {
        matches([
            "sound", "audio", "mikrofon", "volume", "loudness", "silence", "normalization",
            "normalisierung", "verstärkung", "gain", "feedback",
        ])
    }

    private var compressedDiagnosticsText: String {
        let lines = appState.diagnosticsText
            .split(separator: "\n")
            .map(String.init)
        let preview = lines.suffix(8).joined(separator: "\n")
        return preview.isEmpty ? appState.diagnosticsText : preview
    }

    private var settingsNavigationTitle: String {
        isSearching
            ? text("Suchergebnisse", "Search Results")
            : currentSelectedTab.title(language: storedLanguage)
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $splitColumnVisibility) {
            List(selection: selectedTabSelection) {
                Section {
                    ForEach(SettingsTab.allCases, id: \.self) { tab in
                        Label(tab.title(language: storedLanguage), systemImage: tab.symbolName)
                            .tag(tab)
                            .imageScale(.medium)
                    }
                }
            }
            .listStyle(.sidebar)
            .settingsSidebarBackgroundExtensionEffect()
            .environment(\.defaultMinListRowHeight, 36)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .navigationSplitViewColumnWidth(
                min: MacNativeDesign.SettingsSplitView.sidebarMinWidth,
                ideal: MacNativeDesign.SettingsSplitView.sidebarIdealWidth,
                max: MacNativeDesign.SettingsSplitView.sidebarMaxWidth
            )
        } detail: {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Group {
                            if isSearching {
                                searchResultsForm
                            } else {
                                selectedForm
                            }
                        }
                        .frame(maxWidth: 760, alignment: .leading)
                        // Vertikaler Offset + Opacity: Material/Glass in `Form` wirkt bei purem Fade oft zerhackt.
                        .transition(searchResultsContentTransition)
                        .contentTransition(.interpolate)
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 20)
                    .padding(.bottom, 28)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle(settingsNavigationTitle)
            }
            // Gleiche Kurve für Titel (Toolbar) und Inhalt, damit die System-Suchfeld-Animation nicht „auseinanderläuft“.
            .animation(searchFieldSyncedAnimation, value: isSearching)
            // Nur Detail-Spalte: globales `.controlSize` am SplitView würde auch die Fenster-Toolbar verkleinern.
            .controlSize(.regular)
            .navigationSplitViewColumnWidth(
                min: MacNativeDesign.SettingsSplitView.detailMinWidth,
                ideal: 720
            )
        }
        .searchable(
            text: $searchText,
            placement: .automatic,
            prompt: text("Einstellungen durchsuchen", "Search settings")
        )
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    let next: NavigationSplitViewVisibility =
                        splitColumnVisibility == .detailOnly ? .all : .detailOnly
                    if accessibilityReduceMotion {
                        splitColumnVisibility = next
                    } else {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            splitColumnVisibility = next
                        }
                    }
                } label: {
                    Image(systemName: "sidebar.left")
                }
                .accessibilityLabel(
                    text("Seitenleiste ein- oder ausblenden", "Show or hide sidebar")
                )
                .help(text("Seitenleiste ein- oder ausblenden", "Show or hide sidebar"))
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showsTabInfoPopover.toggle()
                } label: {
                    Image(systemName: "info.circle")
                }
                .accessibilityLabel(
                    text("Informationen zu diesem Bereich", "Information about this section")
                )
                // Kein `.help`: vermeidet den nativen Tooltip neben dem Klick-Popover.
                .popover(isPresented: $showsTabInfoPopover, arrowEdge: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(currentSelectedTab.title(language: storedLanguage))
                            .font(.headline)
                        Text(currentSelectedTab.details(language: storedLanguage))
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .frame(minWidth: 280, maxWidth: 320, alignment: .leading)
                }
            }
        }
        .environment(\.locale, storedLanguage.localeForFormatting)
        .frame(
            minWidth: MacNativeDesign.SettingsSplitView.windowMinWidth,
            idealWidth: 1020,
            minHeight: 600,
            idealHeight: 650
        )
        .background(.windowBackground)
        .onAppear {
            appState.refreshPermissionStates()
        }
    }

    private var generalForm: some View {
        Form {
            Section(text("App", "App")) {
                generalAppearanceContent
            }
            Section(text("Menüleiste", "Menu bar")) {
                generalMenuBarContent
            }
            Section(text("Zugriff", "Access")) {
                generalPermissionsContent
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: 760, alignment: .leading)
    }

    @ViewBuilder
    private var selectedForm: some View {
        switch currentSelectedTab {
        case .general:
            generalForm
        case .speech:
            speechForm
        case .dictation:
            dictationForm
        case .sound:
            soundForm
        case .shortcuts:
            shortcutsForm
        case .ai:
            aiForm
        case .history:
            historyForm
        case .about:
            aboutForm
        case .snippets:
            snippetsForm
        case .advanced:
            advancedForm
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

    private var currentSelectedTab: SettingsTab {
        appState.selectedSettingsTab
    }

    private var speechForm: some View {
        Form {
            Section(text("Kurz erklärt", "Quick explainer")) {
                speechOverviewContent
            }
            Section(text("Anbieter", "Providers")) {
                speechProviderContent
            }
            Section(text("Modell", "Model")) {
                speechModelSelectionContent
            }
            Section(text("Sprache", "Language")) {
                speechLanguageContent
            }
            Section(text("Qualität", "Quality")) {
                speechQualityContent
            }
            Section(text("Übersetzung", "Translation")) {
                translationContent
            }
            Section(text("Installierte Modelle", "Installed models")) {
                installedSpeechModelsContent
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: 760, alignment: .leading)
    }

    private var dictationForm: some View {
        Form {
            Section(text("Live-Anpassung", "Live rewriting")) {
                liveRewriteContent
            }
            Section(text("Texteingabe", "Text input")) {
                dictationDeliveryContent
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: 760, alignment: .leading)
    }

    private var soundForm: some View {
        Form {
            Section(text("Eingang", "Input")) {
                soundInputContent
            }
            Section(text("Rückmeldung", "Feedback")) {
                soundFeedbackContent
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: 760, alignment: .leading)
    }

    private var shortcutsForm: some View {
        Form {
            Section(text("Start / Stopp", "Start / Stop")) {
                startStopShortcutContent
            }
            Section(text("Halten zum Diktieren", "Hold to Dictate")) {
                holdShortcutContent
            }
            Section(text("Abbrechen", "Cancel")) {
                cancelShortcutContent
            }
            Section(text("Moduswechsel", "Mode switch")) {
                modeSwitchShortcutContent
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: 760, alignment: .leading)
    }

    private var aiForm: some View {
        Form {
            Section(text("Verarbeitung", "Processing")) {
                aiProcessingContent
            }
            Section(text("Anbieter", "Providers")) {
                aiProviderContent
            }
            Section(text("Modelle", "Models")) {
                aiModelContent
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: 760, alignment: .leading)
    }

    private var historyForm: some View {
        Form {
            Section(text("Aktionen", "Actions")) {
                historyActionContent
            }
            Section(text("Aufbewahrung", "Retention")) {
                historyRetentionContent
            }
            Section(text("Transkriptverlauf", "Transcript History")) {
                historyEntriesContent
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: 760, alignment: .leading)
    }

    private var aboutForm: some View {
        Form {
            Section(text("Über mich", "About me")) {
                aboutDeveloperRows
            }
            Section(text("Changelog", "Changelog")) {
                aboutChangelogContent
            }
            if appState.isLicenseUIEnabledForDevelopment {
                Section(text("Support", "Support")) {
                    aboutSupportContent
                }
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: 760, alignment: .leading)
    }

    private var snippetsForm: some View {
        Form {
            Section(text("Neues Snippet", "New snippet")) {
                snippetNewEntryRows
            }
            Section(text("Import und Export", "Import and export")) {
                snippetImportExportRows
            }
            Section(text("Gespeicherte Snippets", "Saved snippets")) {
                snippetSavedRows
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: 760, alignment: .leading)
    }

    private var advancedForm: some View {
        Form {
            Section {
                advancedOverviewContent
            }
            Section(text("App", "App")) {
                aboutAppInfoRows
            }
            Section(text("Modelllaufzeit", "Model runtime")) {
                voiceModelRuntimeContent
            }
            Section(text("Speicherort", "Storage location")) {
                advancedStorageContent
            }
            Section(text("Updates", "Updates")) {
                updatesContent
            }
            Section(text("Diagnose", "Diagnostics")) {
                diagnosticsContent
            }
            if appState.isLicenseUIEnabledForDevelopment {
                Section(text("Lizenz", "License")) {
                    licenseContent
                }
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: 760, alignment: .leading)
    }

    private var searchResultsForm: some View {
        Form {
            if generalHasMatches {
                Section(text("Allgemein", "General")) {
                    generalAppearanceContent
                    generalMenuBarContent
                    generalPermissionsContent
                }
            }

            if dictationHasMatches {
                Section(text("Diktat", "Dictation")) {
                    liveRewriteContent
                    dictationDeliveryContent
                }
            }

            if speechHasMatches {
                Section(text("Speech", "Speech")) {
                    speechOverviewContent
                    speechProviderContent
                    speechModelSelectionContent
                    speechLanguageContent
                    speechQualityContent
                    translationContent
                    installedSpeechModelsContent
                }
            }

            if soundHasMatches {
                Section(text("Sound", "Sound")) {
                    soundInputContent
                    soundFeedbackContent
                }
            }

            if shortcutsHasMatches {
                Section(text("Kurzbefehle", "Shortcuts")) {
                    startStopShortcutContent
                    holdShortcutContent
                    cancelShortcutContent
                    modeSwitchShortcutContent
                }
            }

            if aiHasMatches {
                Section(text("AI", "AI")) {
                    aiProcessingContent
                    aiProviderContent
                    aiModelContent
                }
            }

            if historyHasMatches {
                Section(text("Verlauf", "History")) {
                    historyActionContent
                    historyRetentionContent
                    historyEntriesContent
                }
            }

            if aboutHasMatches {
                Section(text("About", "About")) {
                    aboutDeveloperRows
                    aboutChangelogContent
                    if appState.isLicenseUIEnabledForDevelopment {
                        aboutSupportContent
                    }
                }
            }

            if snippetsHasMatches {
                Section(text("Snippets", "Snippets")) {
                    snippetNewEntryRows
                    snippetImportExportRows
                    snippetSavedRows
                }
            }

            if advancedHasMatches {
                Section(text("Erweitert", "Advanced")) {
                    if aboutAppMetadataMatchesSearch {
                        aboutAppInfoRows
                    }
                    advancedOverviewContent
                    voiceModelRuntimeContent
                    updatesContent
                    diagnosticsContent
                    if appState.isLicenseUIEnabledForDevelopment {
                        licenseContent
                    }
                }
            }

            if !generalHasMatches && !speechHasMatches && !dictationHasMatches && !soundHasMatches
                && !shortcutsHasMatches && !aiHasMatches && !historyHasMatches && !aboutHasMatches
                && !snippetsHasMatches && !advancedHasMatches
            {
                Section {
                    Text(
                        text(
                            "Keine passenden Einstellungen gefunden.", "No matching settings found."
                        )
                    )
                    .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: 760, alignment: .leading)
    }

    @ViewBuilder
    private var generalAppearanceContent: some View {
        if matches(["language", "sprache", "dock", "launch on login", "updates"]) {
            LabeledContent {
                Picker(text("App-Sprache", "App Language"), selection: $uiLanguageRaw) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.pickerDisplayName(uiContentLanguage: effectiveLanguage)).tag(
                            language.rawValue)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .settingsFormMenuPickerSlot(minWidth: 170)
            } label: {
                SettingsFieldLabel(title: text("App-Sprache", "App language"))
            }

            Toggle(text("Im Dock anzeigen", "Show in Dock"), isOn: $appState.showInDock)

            Toggle(isOn: $appState.launchOnLoginEnabled) {
                SettingsFieldLabel(
                    title: text("Beim Anmelden starten", "Launch on login"),
                    helpText: text(
                        "Startet WisprLocal automatisch nach der macOS-Anmeldung.",
                        "Starts WisprLocal automatically after you sign in to macOS."
                    )
                )
            }

            Toggle(isOn: $appState.automaticallyCheckForUpdates) {
                SettingsFieldLabel(
                    title: text("Updates automatisch prüfen", "Automatically check for updates"),
                    helpText: text(
                        "Prüft im Hintergrund regelmäßig über Sparkle, ob eine neuere Version verfügbar ist.",
                        "Checks in the background via Sparkle to see whether a newer version is available."
                    )
                )
            }
        }
    }

    @ViewBuilder
    private var generalMenuBarContent: some View {
        if matches(["menüleiste", "menu bar", "shortcut hints", "compact", "kompakt"]) {
            Toggle(isOn: $appState.compactMenuBarDesign) {
                SettingsFieldLabel(
                    title: text("Kompaktes Menüleisten-Design", "Compact menu bar design"),
                    helpText: text(
                        "Macht das Menüleisten-Popup schmaler und ruhiger, lässt aber Verlauf, Kopieren und Trennlinien sichtbar.",
                        "Makes the menu bar popup narrower and calmer while keeping history, copy actions, and separators visible."
                    )
                )
            }

            Toggle(isOn: $appState.showMenuBarShortcutHints) {
                SettingsFieldLabel(
                    title: text(
                        "Kurzbefehl-Hinweise im Menü anzeigen", "Show shortcut hints in menu"),
                    helpText: text(
                        "Zeigt Tastenkombinationen direkt neben passenden Einträgen im Menüleisten-Menü an.",
                        "Shows keyboard shortcuts directly next to matching menu bar items."
                    )
                )
            }
        }
    }

    private var advancedOverviewContent: some View {
        Text(
            text(
                "Hier liegen Laufzeitoptionen, Speicherort, Updates und technische Diagnose. Nur ändern, wenn du weißt, warum du es brauchst.",
                "Model runtime, storage location, updates, and technical diagnostics live here. Change these only when you know why you need them."
            )
        )
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var advancedStorageContent: some View {
        if matches([
            "storage", "folder", "app support", "speicherort", "datenordner", "app folder", "logs",
            "protokolle",
        ]) {
            LabeledContent {
                VStack(alignment: .leading, spacing: 10) {
                    Text(appState.appSupportDirectoryPathText)
                        .font(.footnote.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)

                    Button(text("Ordner im Finder öffnen", "Open folder in Finder")) {
                        appState.revealAppDataFolder()
                    }
                    .liquidGlassSecondaryButtonStyle()
                }
            } label: {
                SettingsFieldLabel(
                    title: text("App-Datenordner", "App data folder"),
                    helpText: text(
                        "Hier liegen Verlauf, Snippets, Logs und weitere lokale App-Daten.",
                        "This folder stores history, snippets, logs, and other local app data."
                    )
                )
            }
        }
    }

    @ViewBuilder
    private var voiceModelRuntimeContent: some View {
        if matches([
            "voice", "sprachmodell", "model runtime", "runtime", "duration", "dauer", "warm",
            "speicher halten", "modelllaufzeit",
        ]) {
            LabeledContent {
                Picker(
                    text("Sprachmodell im Speicher halten", "Keep voice model in memory"),
                    selection: $appState.voiceModelActiveDuration
                ) {
                    ForEach(VoiceModelActiveDuration.allCases) { duration in
                        Text(
                            duration.localizedDisplayName(
                                interfaceLanguageCode: effectiveLanguage.embeddedInterfaceCode)
                        ).tag(duration)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .settingsFormMenuPickerSlot(minWidth: 220)
            } label: {
                SettingsFieldLabel(
                    title: text("Sprachmodell im Speicher halten", "Keep voice model in memory"),
                    helpText: text(
                        "Längere Laufzeiten machen den nächsten Start schneller, kürzere sparen Speicher.",
                        "Longer durations make the next start faster, shorter ones save memory."
                    )
                )
            }
        }
    }

    @ViewBuilder
    private var updatesContent: some View {
        if matches(["update", "updates", "aktualisierung"]) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 10) {
                    Button(text("Nach Updates suchen", "Check for updates")) {
                        appState.checkForUpdates()
                    }
                    .liquidGlassSecondaryButtonStyle()
                    .disabled(!appState.updaterConfigured)

                    if !appState.updaterStatusText.isEmpty {
                        Text(appState.updaterStatusText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                if !appState.updaterFeedURLText.isEmpty {
                    Text(appState.updaterFeedURLText)
                        .font(.footnote.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
    }

    @ViewBuilder
    private var aboutAppInfoRows: some View {
        LabeledContent(text("App", "App")) {
            Text("WisprLocal")
        }
        LabeledContent(text("Version", "Version")) {
            Text("\(appMarketingVersion) (\(appBuildNumber))")
                .monospacedDigit()
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private var aboutDeveloperRows: some View {
        if matches([
            "about", "über", "ueber", "leon", "stadler", "website", "webseite", "proprietär",
            "proprietary", "lizenz", "intermedia", "design", "fotografie", "vorarlberg",
        ]) {
            LabeledContent(text("Entwickler", "Developer")) {
                Text("Leon Stadler")
            }
            Text(
                text(
                    "Ich bin in München aufgewachsen, lebe heute am Bodensee und arbeite an digitalen Produkten, die Design, Technik und Alltag sinnvoll verbinden. Schwerpunkte sind Webdesign, UX/UI, Prototyping und kreative technische Systeme — mit einem starken Blick auf ruhige, native Oberflächen.",
                    "I grew up in Munich and now live near Lake Constance, building digital products that connect design, technology, and everyday work. My focus is web design, UX/UI, prototyping, and creative technical systems — with a strong preference for calm, native-feeling interfaces."
                )
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            Text(
                text(
                    "WisprLocal ist daraus entstanden: eine lokale, datensparsame Diktierlösung für den Mac, die sich nicht aufdrängt, sondern zuverlässig im Hintergrund mitarbeitet.",
                    "WisprLocal grew out of that mindset: a local, privacy-conscious dictation tool for the Mac that stays out of the way while remaining dependable."
                )
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            Link(destination: personalWebsiteURL) {
                Text(text("Website besuchen", "Visit website"))
            }
            .liquidGlassPrimaryButtonStyle()
        }
    }

    @ViewBuilder
    private var aboutChangelogContent: some View {
        if matches([
            "changelog", "neuigkeiten", "release", "release notes", "änderungen", "aenderungen",
            "features", "fixes",
        ]) {
            ChangelogSectionView(
                entries: AppChangelogCatalog.latestEntries, language: effectiveLanguage)
        }
    }

    @ViewBuilder
    private var aboutSupportContent: some View {
        if matches(["support", "spenden", "donate", "website", "webseite"]) {
            Text(
                text(
                    "WisprLocal ist proprietäre Software und wird nicht als Open Source veröffentlicht. Support, Lizenzierung und Hintergrund zum Projekt findest du auf der Website.",
                    "WisprLocal is proprietary software and is not distributed as open source. Visit the website for support, licensing, and project information."
                )
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            Link(destination: personalWebsiteURL) {
                Label(text("Projekt unterstützen", "Support the project"), systemImage: "heart")
            }
            .liquidGlassPrimaryButtonStyle()
        }
    }

    @ViewBuilder
    private var generalPermissionsContent: some View {
        if matches([
            "mikrofon", "accessibility", "bedienungshilfen", "permissions", "berechtigungen",
        ]) {
            Text(
                text(
                    "Freigaben kannst du hier prüfen. „Freigabe anfragen“ öffnet den Systemdialog; „Öffnen“ führt zu den Datenschutz-Einstellungen. Direkt nach einem App-Neustart kann der Status einmal kurz hinterherhängen – dann erneut öffnen oder kurz warten.",
                    "You can verify access here. “Request access” shows the system prompt; “Open” goes to Privacy settings. Right after launching the app, the status row can briefly lag—open again or wait a moment."
                )
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            PermissionStatusRow(
                title: text("Mikrofon", "Microphone"),
                status: appState.microphonePermissionStatus,
                detail: text("Erforderlich für die Audioaufnahme.", "Required for audio capture."),
                actionTitle: appState.microphonePermissionStatus == .notDetermined
                    ? text("Freigabe anfragen", "Request access")
                    : text("Öffnen", "Open"),
                actionHint: appState.microphonePermissionStatus == .notDetermined
                    ? text("Systemdialog zur Mikrofonfreigabe", "System prompt for microphone access")
                    : text("Mikrofon-Einstellungen öffnen", "Open microphone settings"),
                action: {
                    if appState.microphonePermissionStatus == .notDetermined {
                        appState.requestMicrophoneAccessFromSettings()
                    } else {
                        appState.openMicrophoneSettings()
                    }
                }
            )

            PermissionStatusRow(
                title: text("Bedienungshilfen", "Accessibility"),
                status: appState.accessibilityPermissionStatus,
                detail: text(
                    "Erforderlich zum Einfügen in das aktive Textfeld.",
                    "Required to insert into the active text field."),
                actionTitle: appState.accessibilityPermissionStatus != .granted
                    ? text("Freigabe anfragen", "Request access")
                    : text("Öffnen", "Open"),
                actionHint: appState.accessibilityPermissionStatus != .granted
                    ? text(
                        "Systemdialog zu Bedienungshilfen",
                        "System prompt for Accessibility")
                    : text("Bedienungshilfen öffnen", "Open accessibility settings"),
                action: {
                    if appState.accessibilityPermissionStatus != .granted {
                        appState.requestAccessibilityAccessFromSettings()
                    } else {
                        appState.openAccessibilitySettings()
                    }
                }
            )

            Text(appState.dictationCapability.localizedSummary)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var soundInputContent: some View {
        if soundHasMatches {
            Toggle(isOn: $appState.automaticMicrophoneGainBoost) {
                SettingsFieldLabel(
                    title: text("Leise Eingänge verstärken", "Boost quiet input"),
                    helpText: text(
                        "Hebt ein schwaches Eingangssignal an, bevor die Erkennung startet. Das ändert nicht die systemweite Mikrofonlautstärke.",
                        "Boosts a weak input signal before recognition begins. This does not change the system-wide microphone volume."
                    )
                )
            }
            Toggle(isOn: $appState.silenceRemovalEnabled) {
                SettingsFieldLabel(
                    title: text("Stille entfernen", "Silence removal"),
                    helpText: text(
                        "Filtert ruhige Abschnitte und schwache Störgeräusche vor der Erkennung. Das hilft besonders bei Live-Einfügen gegen Atem-, Raum- oder Tastaturreste.",
                        "Filters quiet passages and weak background noise before recognition. This is especially useful during live insertion against breathing, room, or keyboard residue."
                    )
                )
            }

            LabeledContent {
                VStack(alignment: .trailing, spacing: 6) {
                    Slider(value: $appState.noiseSuppressionLevel, in: 0...1, step: 0.05)
                        .frame(maxWidth: 300)
                    Text(
                        text("Filterstärke", "Filter strength")
                            + ": \(Int((appState.noiseSuppressionLevel * 100).rounded()))%"
                    )
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 300, alignment: .trailing)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            } label: {
                SettingsFieldLabel(
                    title: text("Störgeräusche filtern", "Filter background noise"),
                    helpText: text(
                        "Steuert, wie aggressiv leise Nebengeräusche und kurze Nicht-Sprachsignale unterdrückt werden. Höher hilft bei Husten, Atemgeräuschen oder Raumrauschen, kann aber sehr leise Sprache früher abschneiden.",
                        "Controls how aggressively quiet background noise and short non-speech signals are suppressed. Higher values help with coughing, breathing, or room noise, but may cut very quiet speech earlier."
                    )
                )
            }
            .disabled(!appState.silenceRemovalEnabled)

            Toggle(isOn: $appState.dynamicNormalizationEnabled) {
                SettingsFieldLabel(
                    title: text("Dynamische Normalisierung", "Dynamic normalization"),
                    helpText: text(
                        "Gleicht Lautstärkeunterschiede innerhalb des laufenden Signals aus. Anders als die Eingangsverstärkung reagiert diese Option auf wechselnde Pegel während der Aufnahme.",
                        "Balances loudness differences inside the live signal. Unlike quiet-input boosting, this reacts to changing levels while recording."
                    )
                )
            }
        }
    }

    @ViewBuilder
    private var soundFeedbackContent: some View {
        if soundHasMatches {
            Toggle(isOn: $appState.soundEffectsEnabled) {
                SettingsFieldLabel(
                    title: text("Soundeffekte aktivieren", "Enable sound effects"),
                    helpText: text(
                        "Spielt kurze Statussignale beim Starten, Stoppen oder bei wichtigen Zustandswechseln ab.",
                        "Plays short status cues when starting, stopping, or when important states change."
                    )
                )
            }

            LabeledContent {
                VStack(alignment: .trailing, spacing: 6) {
                    Slider(value: $appState.soundEffectsVolume, in: 0...100, step: 5)
                        .frame(maxWidth: 300)
                    Text(
                        text("Lautstärke", "Volume")
                            + ": \(Int(appState.soundEffectsVolume.rounded()))%"
                    )
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 300, alignment: .trailing)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            } label: {
                SettingsFieldLabel(
                    title: text("Lautstärke", "Volume"),
                    helpText: text(
                        "Regelt nur die internen App-Sounds, nicht die Systemlautstärke.",
                        "Controls only the app's internal sounds, not the system volume."
                    )
                )
            }
            .disabled(!appState.soundEffectsEnabled)
        }
    }

    @ViewBuilder
    private var speechProviderContent: some View {
        if speechHasMatches {
            LabeledContent {
                Picker(
                    text("Voice-Anbieter", "Voice provider"),
                    selection: $appState.selectedVoiceProviderID
                ) {
                    ForEach(appState.voiceProviders) { provider in
                        Text(provider.displayName).tag(provider.id)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .settingsFormMenuPickerSlot(minWidth: 240)
            } label: {
                SettingsFieldLabel(
                    title: text("Voice-Anbieter", "Voice provider"),
                    helpText: text(
                        "V1 bleibt komplett lokal. Zusätzliche Anbieter erscheinen nur, wenn ihr lokales Backend wirklich vorhanden ist.",
                        "V1 stays fully local. Additional providers only appear when their local backend is actually available."
                    )
                )
            }
        }
    }

    @ViewBuilder
    private var speechOverviewContent: some View {
        if speechHasMatches {
            VStack(alignment: .leading, spacing: 8) {
                Text(
                    text(
                        "Modell, Sprache und Übersetzung sind getrennt. Das Modell bestimmt Größe, Tempo und Fähigkeiten. Die Sprache begrenzt nur die sinnvollen Eingaben.",
                        "Model, language, and translation are separate. The model defines size, speed, and capabilities. Language only limits the sensible input choices."
                    )
                )
                .font(.subheadline)

                Text(
                    text(
                        "Qualität steuert Beam-Search, Chunking und Threads. Sie ändert nicht mehr das eigentliche Modell.",
                        "Quality controls beam search, chunking, and threads. It no longer changes the actual model."
                    )
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var speechModelSelectionContent: some View {
        if speechHasMatches {
            LabeledContent {
                Picker(
                    text("Voice-Modell", "Voice model"), selection: $appState.selectedVoiceModelID
                ) {
                    ForEach(appState.visibleVoiceModels) { model in
                        Text(model.displayName).tag(model.id)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .settingsFormMenuPickerSlot(minWidth: 240)
            } label: {
                SettingsFieldLabel(
                    title: text("Voice-Modell", "Voice model"),
                    helpText: text(
                        "Das Modell bestimmt die tatsächliche Transkriptions-Engine.",
                        "The model defines the actual transcription engine."
                    )
                )
            }
        }
    }

    @ViewBuilder
    private var speechLanguageContent: some View {
        if speechHasMatches {
            LabeledContent {
                Picker(
                    text("Eingabesprache", "Input language"), selection: $appState.selectedLanguage
                ) {
                    ForEach(appState.selectedVoiceModelLanguageOptions) { language in
                        Text(
                            language.localizedDisplayName(
                                interfaceLanguageCode: effectiveLanguage.embeddedInterfaceCode)
                        ).tag(language)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .settingsFormMenuPickerSlot(minWidth: 180)
            } label: {
                SettingsFieldLabel(
                    title: text("Eingabesprache", "Input language"),
                    helpText: text(
                        "Bei multilingualen Modellen kann die Sprache frei gewählt werden. Bei rein englischen Modellen reduziert sich die Auswahl automatisch.",
                        "For multilingual models you can choose freely. For English-only models the picker is reduced automatically."
                    )
                )
            }

            if let selectedModel = appState.selectedVoiceModel {
                Text(
                    selectedModel.languageCode == nil
                        ? text(
                            "Multilinguales Modell: alle Sprachen verfügbar.",
                            "Multilingual model: all languages available.")
                        : text(
                            "Sprache ist an das Modell gebunden.", "Language is bound to the model."
                        )
                )
                .font(.footnote)
                .foregroundStyle(.secondary)

                if let hint = appState.selectedVoiceModelLanguageHintText {
                    Text(hint)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var speechQualityContent: some View {
        if speechHasMatches {
            LabeledContent {
                Picker(
                    text("Qualitätsprofil", "Quality profile"),
                    selection: $appState.performanceProfile
                ) {
                    ForEach(DictationPerformance.allCases) { mode in
                        Text(
                            mode.localizedDisplayName(
                                interfaceLanguageCode: effectiveLanguage.embeddedInterfaceCode)
                        )
                        .tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .settingsFormMenuPickerSlot(minWidth: 180)
            } label: {
                SettingsFieldLabel(
                    title: text("Qualitätsprofil", "Quality profile"),
                    helpText: text(
                        "Steuert Laufzeitparameter wie Beam-Search, Chunking und Threads.",
                        "Controls runtime parameters like beam search, chunking, and threads."
                    )
                )
            }

            if let selectedModel = appState.selectedVoiceModel {
                LabeledContent(text("Modell-Details", "Model details")) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(
                            "\(text("Bereich", "Scope")): \(selectedModel.languageCode?.uppercased() ?? "ALL")"
                        )
                        Text(
                            "\(text("Übersetzung", "Translation")): \(selectedModel.supportsTranslationToEnglish ? text("Ja", "Yes") : text("Nein", "No"))"
                        )
                        Text(
                            "\(text("Geschwindigkeit", "Speed")) \(selectedModel.speedScore)/10  \(text("Genauigkeit", "Accuracy")) \(selectedModel.accuracyScore)/10  \(selectedModel.sizeLabel)"
                        )
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    @ViewBuilder
    private var translationContent: some View {
        if speechHasMatches, appState.speechTranslationAvailable {
            LabeledContent {
                Picker(
                    text("Übersetzen nach", "Translate to"),
                    selection: $appState.translationOutputMode
                ) {
                    ForEach(TranslationOutputMode.allCases) { mode in
                        Text(
                            mode.localizedDisplayName(
                                interfaceLanguageCode: effectiveLanguage.embeddedInterfaceCode)
                        )
                        .tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .settingsFormMenuPickerSlot(minWidth: 170)
                .disabled(!appState.speechTranslationAvailable)
            } label: {
                SettingsFieldLabel(
                    title: text("Übersetzen nach", "Translate to"),
                    helpText: text(
                        "Die Option \"Keine Übersetzung\" gibt die gesprochene Sprache zurück. Die Option \"Nach Englisch\" aktiviert ausschließlich die lokale Whisper-Übersetzung. Sprachspezifische English-Modelle unterstützen das nicht.",
                        "The Option \"No translation\" returns the spoken language. The Option \"To English\" enables only local Whisper translation. Language-specific English models do not support this."
                    )
                )
            }
        } else if speechHasMatches {
            Text(
                text(
                    "Dieses Modell unterstützt keine Übersetzung.",
                    "This model does not support translation."
                )
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var installedSpeechModelsContent: some View {
        if speechHasMatches {
            ForEach(appState.visibleVoiceModels) { model in
                LabeledContent {
                    HStack(alignment: .center, spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.displayName)
                            Text(
                                "\(model.languageCode?.uppercased() ?? "ALL") • Speed \(model.speedScore)/10 • Accuracy \(model.accuracyScore)/10 • \(model.sizeLabel)"
                            )
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 12)
                        Text(
                            appState.isVoiceModelInstalled(model)
                                ? text("Installiert", "Installed")
                                : text("Nicht installiert", "Not installed")
                        )
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(
                            appState.isVoiceModelInstalled(model) ? .secondary : .tertiary)
                        if appState.isVoiceModelInstalled(model) {
                            Button(text("Als Standard verwenden", "Use as default")) {
                                appState.setSelectedVoiceModel(model)
                            }
                            .liquidGlassSecondaryButtonStyle()
                            .disabled(
                                appState.selectedVoiceModelID == model.id
                                    || appState.isVoiceModelBusy(model))

                            if model.installState != .bundled {
                                Button(role: .destructive) {
                                    appState.removeVoiceModel(model)
                                } label: {
                                    Text(text("Entfernen", "Remove"))
                                }
                                .liquidGlassDestructiveButtonStyle()
                                .disabled(appState.isVoiceModelBusy(model))
                            }
                        } else {
                            Button(text("Installieren", "Install")) {
                                appState.installVoiceModel(model)
                            }
                            .liquidGlassPrimaryButtonStyle()
                            .disabled(
                                model.installState == .unavailable
                                    || appState.isVoiceModelBusy(model))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    EmptyView()
                }
            }
        }
    }

    @ViewBuilder
    private var liveRewriteContent: some View {
        if matches([
            "anpassung",
            "anpassungsradius",
            "anpassen",
            "rückwirkung",
            "rückwirkend",
            "rückwirkungsbereich",
            "rueckwirkung",
            "rueckwirkend",
            "rueckwirkungsbereich",
            "rewrite",
            "kontext",
            "retroaktiv",
            "weit zurück",
            "live",
        ]) {
            LabeledContent {
                Picker(
                    text("Anpassungsradius", "Adjustment radius"),
                    selection: $appState.liveRewriteScope
                ) {
                    ForEach(LiveRewriteScope.allCases) { scope in
                        Text(
                            scope.localizedDisplayName(
                                interfaceLanguageCode: effectiveLanguage.embeddedInterfaceCode)
                        ).tag(scope)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .settingsFormMenuPickerSlot(minWidth: 260)
                .disabled(!isLiveRewriteScopeApplicable)
            } label: {
                SettingsFieldLabel(
                    title: text("Anpassungsradius", "Adjustment radius"),
                    helpText: text(
                        "Wirkt nur, wenn „Live-Text einfügen“ aktiv ist und nicht „Nur Zwischenablage“ gewählt ist. Kleinere Bereiche sind stabiler. Größere Bereiche glätten stärker, dürfen aber weiter zurückliegende Wörter noch einmal anfassen.",
                        "Only applies when Insert live text is on and delivery is not clipboard-only. Smaller scopes are more stable. Larger scopes smooth more aggressively but may revisit words further back."
                    )
                )
            }
        }
    }

    @ViewBuilder
    private var dictationDeliveryContent: some View {
        if matches([
            "sprache", "language", "qualität", "quality", "streaming", "clipboard",
            "zwischenablage", "insert", "translation", "übersetzung", "uebersetzung", "paste",
            "auto-send", "keypress",
        ]) {
            LabeledContent {
                Picker(
                    text("Finales Ergebnis", "Final result"),
                    selection: $appState.finalResultDeliveryMode
                ) {
                    Text(text("In Textfeld einfügen", "Insert into text field")).tag(
                        FinalResultDeliveryMode.insert)
                    Text(text("Nur in Zwischenablage kopieren", "Copy to clipboard only")).tag(
                        FinalResultDeliveryMode.clipboardOnly)
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .settingsFormMenuPickerSlot(minWidth: 220)
            } label: {
                SettingsFieldLabel(
                    title: text("Finales Ergebnis", "Final result"),
                    helpText: text(
                        "Legt fest, wie das abgeschlossene Diktat ausgeliefert wird: direkt ins aktive Textfeld oder nur über die Zwischenablage.",
                        "Controls how the finished dictation is delivered: directly into the active text field or only through the clipboard."
                    )
                )
            }

            Toggle(isOn: $appState.streamingEnabled) {
                SettingsFieldLabel(
                    title: text("Live-Text einfügen", "Insert live text"),
                    helpText: text(
                        "Zeigt laufende Zwischenergebnisse direkt im Zieltextfeld an, solange gestreamt wird.",
                        "Shows live intermediate results directly in the target text field while streaming is active."
                    )
                )
            }
            .disabled(
                appState.finalResultDeliveryMode == .clipboardOnly
                    || !appState.dictationCapability.allowsDirectInsertion)

            Toggle(isOn: $appState.clipboardFallbackWhenNoTarget) {
                SettingsFieldLabel(
                    title: text(
                        "Wenn kein Textfeld aktiv ist: Ergebnis in Zwischenablage kopieren",
                        "If no text field is active: copy result to clipboard"),
                    helpText: text(
                        "Verwendet die Zwischenablage als Fallback, wenn macOS gerade kein direkt beschreibbares Textziel meldet.",
                        "Uses the clipboard as a fallback when macOS does not currently report a directly writable text target."
                    )
                )
            }
            .disabled(appState.finalResultDeliveryMode == .clipboardOnly)

            Toggle(isOn: $appState.autoSendAfterPaste) {
                SettingsFieldLabel(
                    title: text("Nach dem Einfügen automatisch senden", "Auto-send after paste"),
                    helpText: text(
                        "Sendet nach dem finalen Einfügen eine Eingabetaste (Return), auch wenn der Text direkt ins Feld geschrieben wurde – nicht nur bei Einfügen über die Zwischenablage. Nützlich in Chats oder Formularen.",
                        "Sends Return after final text is inserted, including when text is written directly into the field—not only when pasting from the clipboard. Useful in chats or forms."
                    )
                )
            }
            Toggle(isOn: $appState.restoreClipboardAfterPaste) {
                SettingsFieldLabel(
                    title: text(
                        "Zwischenablage nach dem Einfügen wiederherstellen",
                        "Restore clipboard after paste"),
                    helpText: text(
                        "Stellt den vorherigen Inhalt der Zwischenablage nach dem finalen Einfügen wieder her.",
                        "Restores the previous clipboard contents after final insertion."
                    )
                )
            }
            Toggle(isOn: $appState.simulateKeypresses) {
                SettingsFieldLabel(
                    title: text("Tastatureingaben simulieren", "Simulate keypresses"),
                    helpText: text(
                        "Gilt nur für das finale Einfügen am Ende der Aufnahme und für Einfüge-Fallbacks per Tastatur. Laufende Live-Zwischenergebnisse werden weiterhin direkt im Zieltextfeld aktualisiert.",
                        "Applies only to final insertion at the end of recording and to keyboard-based fallbacks. Live streaming updates still go directly into the target field."
                    )
                )
            }

            if !appState.dictationCapability.allowsDirectInsertion {
                Text(
                    text(
                        "Ohne Bedienungshilfen startet die Aufnahme weiterhin, aber direktes Einfügen bleibt deaktiviert.",
                        "Without Accessibility, recording still starts, but direct insertion remains disabled."
                    )
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var aiProcessingContent: some View {
        if aiHasMatches {
            Toggle(
                text("AI-Verarbeitung aktivieren", "Enable AI processing"),
                isOn: $appState.aiProcessingEnabled
            )
            .disabled(appState.selectedAIModel?.availability.isAvailable != true)

            if !appState.aiProcessingEnabled {
                Text(
                    text(
                        "Richte weiter unten Anbieter und Modell ein, dann aktiviere die Verarbeitung. In der Menüleiste erscheinen LLM und Feinsteuerung erst nach Aktivierung.",
                        "Configure a provider and model below, then enable processing. The menu bar shows the LLM and fine controls only after processing is enabled."
                    )
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            if appState.aiProcessingEnabled {
                LabeledContent {
                    VStack(alignment: .trailing, spacing: 8) {
                        Toggle(
                            text("Inhaltsstreaming", "Content streaming"),
                            isOn: $appState.aiProcessingApplyDuringLiveInsertion
                        )
                        .disabled(!appState.streamingEnabled)

                        Toggle(
                            text("Endergebnis einfügen", "Insert final result"),
                            isOn: $appState.aiProcessingApplyToFinalResult
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                } label: {
                    SettingsFieldLabel(
                        title: text("AI anwenden bei", "Apply AI for"),
                        helpText: text(
                            "Steuert, ob das Modell schon auf Live-Zwischenergebnisse, erst auf das finale Ergebnis oder auf beides angewendet wird.",
                            "Controls whether the model is applied to live intermediate text, only to the final result, or to both."
                        )
                    )
                }
                .disabled(appState.selectedAIModel?.availability.isAvailable != true)

                LabeledContent {
                    VStack(alignment: .trailing, spacing: 8) {
                        Toggle(
                            text("Stil / Ton", "Style / Tone"),
                            isOn: $appState.aiTaskToneEnabled
                        )
                        Toggle(
                            text("Anrede", "Salutation"),
                            isOn: $appState.aiTaskSalutationEnabled
                        )
                        Toggle(
                            text("Format / Modus", "Format / Mode"),
                            isOn: $appState.aiTaskFormatEnabled
                        )
                        Toggle(
                            text("Bereinigen", "Clean up"),
                            isOn: $appState.aiTaskCleanupEnabled
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                } label: {
                    SettingsFieldLabel(
                        title: text("AI-Aufgaben", "AI tasks"),
                        helpText: text(
                            "Reihenfolge wie in der Menüleiste: Stil, Anrede, Format, Bereinigung. Kombinierbar; „Wie gesprochen“ bei Format oder Stil/Anrede bedeutet: kein Zusatzaufwand in dieser Dimension.",
                            "Same order as the menu bar: style, salutation, format, cleanup. “As spoken” for format or style/salutation means no extra work in that dimension."
                        )
                    )
                }
                .disabled(appState.selectedAIModel?.availability.isAvailable != true)

                if appState.aiShowsWritingStyleControls {
                    LabeledContent {
                        Picker(
                            text("Stil / Ton", "Style / Tone"),
                            selection: $appState.aiWritingStyle
                        ) {
                            ForEach(appState.availableAIWritingStyles) { style in
                                Text(
                                    style.localizedDisplayName(
                                        interfaceLanguageCode: effectiveLanguage
                                            .embeddedInterfaceCode)
                                ).tag(style)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .settingsFormMenuPickerSlot(minWidth: 220)
                    } label: {
                        SettingsFieldLabel(
                            title: text("Stil / Ton", "Style / Tone"),
                            helpText: text(
                                "Zeigt nur Stile an, die zum gewählten Modus passen. Für Dokumentation oder wissenschaftliche Texte bleiben zum Beispiel nur sachliche Varianten übrig.",
                                "Shows only styles that fit the selected mode. For documentation or scientific text, only fitting formal variants remain available."
                            )
                        )
                    }
                    .disabled(appState.selectedAIModel?.availability.isAvailable != true)
                }

                if appState.aiShowsSalutationControls {
                    LabeledContent {
                        Picker(text("Anrede", "Salutation"), selection: $appState.aiSalutation) {
                            ForEach(AISalutation.allCases) { salutation in
                                Text(
                                    salutation.localizedDisplayName(
                                        interfaceLanguageCode: effectiveLanguage
                                            .embeddedInterfaceCode)
                                ).tag(salutation)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .settingsFormMenuPickerSlot(minWidth: 220)
                    } label: {
                        SettingsFieldLabel(
                            title: text("Anrede", "Salutation"),
                            helpText: text(
                                "Die Anrede wird nur dort angeboten, wo sie sinnvoll ist, etwa bei E-Mails, Nachrichten oder WhatsApp.",
                                "Salutation is shown only where it makes sense, such as email, messages, or WhatsApp."
                            )
                        )
                    }
                    .disabled(appState.selectedAIModel?.availability.isAvailable != true)
                }

                if appState.aiShowsModeControls {
                    LabeledContent {
                        Picker(text("Modus", "Mode"), selection: $appState.aiFormattingMode) {
                            ForEach(AIFormattingMode.allCases) { mode in
                                Text(
                                    mode.localizedDisplayName(
                                        interfaceLanguageCode: effectiveLanguage
                                            .embeddedInterfaceCode)
                                ).tag(mode)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .settingsFormMenuPickerSlot(minWidth: 220)
                    } label: {
                        SettingsFieldLabel(
                            title: text("Modus", "Mode"),
                            helpText: text(
                                "„Wie gesprochen“: keine aufgezwungene Struktur. „Automatische Formatierung“: aus dem Gesprochenen Listen und Absätze ableiten. Weitere Modi richten Text an E-Mail, Chat usw. aus.",
                                "“As spoken”: no imposed structure. “Automatic formatting” infers lists and paragraphs from speech. Other modes target email, chat, and similar shapes."
                            )
                        )
                    }
                    .disabled(appState.selectedAIModel?.availability.isAvailable != true)
                }

                if appState.aiTaskCleanupEnabled {
                    LabeledContent {
                        VStack(alignment: .trailing, spacing: 6) {
                            Slider(
                                value: $appState.aiCleanupIntensity,
                                in: 0...1,
                                label: {
                                    Text(text("Bereinigungsstärke", "Cleanup strength"))
                                }
                            )
                            .frame(maxWidth: 280)
                            Text(
                                text(
                                    "Ganz links: praktisch keine Bereinigung (kein Modellaufruf, wenn sonst nichts aktiv ist). Rechts: kräftigere Korrektur.",
                                    "Far left: almost no cleanup (and no model call if nothing else is active). Right: stronger cleanup."
                                )
                            )
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 280, alignment: .trailing)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    } label: {
                        SettingsFieldLabel(
                            title: text("Bereinigung", "Cleanup"),
                            helpText: text(
                                "Nur in den Einstellungen; steuert, wie aggressiv erkannt wird und korrigiert wird.",
                                "Settings only; controls how aggressively recognition issues are fixed."
                            )
                        )
                    }
                    .disabled(appState.selectedAIModel?.availability.isAvailable != true)
                }
            }
        }
    }

    @ViewBuilder
    private var aiProviderContent: some View {
        if aiHasMatches {
            VStack(alignment: .leading, spacing: 14) {
                DisclosureGroup(
                    isExpanded: $addProviderDisclosureExpanded,
                    content: {
                        providerPresetGrid
                        providerPresetAddConfirmationRow
                    },
                    label: {
                        Text(text("Anbieter hinzufügen", "Add provider"))
                            .font(.headline)
                    }
                )

                if !appState.remoteProviders.isEmpty {
                    Text(text("Aktiver Anbieter", "Active provider"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                    providerSelectionRow
                    providerEditorCard
                }
            }
        }
    }

    @ViewBuilder
    private var providerPresetAddConfirmationRow: some View {
        if let preset = selectedRemoteProviderPreset {
            VStack(alignment: .leading, spacing: 10) {
                Text(
                    text(
                        "Ausgewählt: \(preset.localizedDisplayName(interfaceLanguageCode: effectiveLanguage.embeddedInterfaceCode)). Mit „Hinzufügen“ in die Liste übernehmen.",
                        "Selected: \(preset.localizedDisplayName(interfaceLanguageCode: effectiveLanguage.embeddedInterfaceCode)). Use “Add” to add it to the list."
                    )
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    Button(text("Abbrechen", "Cancel")) {
                        selectedRemoteProviderPreset = nil
                    }
                    .liquidGlassSecondaryButtonStyle()
                    Button(text("Hinzufügen", "Add")) {
                        appState.addRemoteProvider(preset: preset)
                        selectedRemoteProviderPreset = nil
                    }
                    .liquidGlassPrimaryButtonStyle()
                }
            }
            .padding(.top, 6)
        }
    }

    @ViewBuilder
    private var providerPresetGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            providerPresetGroup(
                title: text("Cloud-APIs", "Cloud APIs"),
                presets: [
                    .openRouter, .openAI, .groq, .mistral, .deepSeek, .togetherAI, .fireworksAI,
                    .xAI,
                ]
            )

            providerPresetGroup(
                title: text("Lokale Server", "Local servers"),
                presets: [.ollama, .lmStudio]
            )

            providerPresetGroup(
                title: text("Eigenes Setup", "Custom setup"),
                presets: [.customOpenAICompatible]
            )
        }
    }

    @ViewBuilder
    private func providerPresetGroup(title: String, presets: [AIRemoteProviderPreset]) -> some View
    {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 170), spacing: 10, alignment: .leading)],
                alignment: .leading,
                spacing: 10
            ) {
                ForEach(presets) { preset in
                    let isSelected = selectedRemoteProviderPreset == preset
                    Button {
                        selectedRemoteProviderPreset = preset
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(
                                preset.localizedDisplayName(
                                    interfaceLanguageCode: effectiveLanguage
                                        .embeddedInterfaceCode)
                            )
                            .font(.body.weight(.semibold))
                            Text(providerPresetDescription(for: preset))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(
                                    Color(nsColor: .controlBackgroundColor).opacity(
                                        isSelected ? 0.55 : 0.2))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(
                                    isSelected
                                        ? Color.accentColor : Color.primary.opacity(0.08),
                                    lineWidth: isSelected ? 2 : 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func providerPresetDescription(for preset: AIRemoteProviderPreset) -> String {
        switch preset {
        case .openRouter:
            return text(
                "Viele Modelle über einen zentralen Zugang.",
                "Many models through one unified gateway.")
        case .openAI:
            return text("Offizielle OpenAI-API.", "Official OpenAI API.")
        case .groq:
            return text(
                "Schnelle OpenAI-kompatible Cloud-API.", "Fast OpenAI-compatible cloud API.")
        case .mistral:
            return text(
                "Mistral über die OpenAI-kompatible Schnittstelle.",
                "Mistral via the OpenAI-compatible surface.")
        case .deepSeek:
            return text("DeepSeek mit Standard-Endpunkten.", "DeepSeek with standard endpoints.")
        case .togetherAI:
            return text("Modellvielfalt für Remote-Setups.", "Model variety for remote setups.")
        case .fireworksAI:
            return text(
                "Gehostete Modelle mit klaren Endpunkten.", "Hosted models with clear endpoints.")
        case .xAI:
            return text("xAI über OpenAI-kompatible Calls.", "xAI over OpenAI-compatible calls.")
        case .ollama:
            return text("Lokale Modelle ohne API-Key.", "Local models without an API key.")
        case .lmStudio:
            return text("Lokaler Server für eigene Modelle.", "Local server for your own models.")
        case .customOpenAICompatible:
            return text(
                "Eigene Base-URL und Endpunkte definieren.",
                "Define your own base URL and endpoints.")
        }
    }

    @ViewBuilder
    private var providerSelectionRow: some View {
        LabeledContent(text("Aktiver Anbieter", "Active provider")) {
            Picker(
                text("Aktiver Anbieter", "Active provider"),
                selection: Binding(
                    get: { appState.selectedRemoteProviderID ?? "" },
                    set: { appState.selectedRemoteProviderID = $0.isEmpty ? nil : $0 }
                )
            ) {
                ForEach(appState.remoteProviders) { provider in
                    Text(provider.displayName).tag(provider.id)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .settingsFormMenuPickerSlot(minWidth: 240)
        }
    }

    @ViewBuilder
    private var providerEditorCard: some View {
        if let provider = appState.selectedRemoteProvider {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(provider.displayName)
                            .font(.headline)
                        Text(
                            provider.preset.localizedDisplayName(
                                interfaceLanguageCode: effectiveLanguage.embeddedInterfaceCode)
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Toggle(
                        text("Aktiv", "Enabled"),
                        isOn: selectedRemoteProviderBinding(\.isEnabled, default: false)
                    )
                    .toggleStyle(.switch)
                }

                Divider()

                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                    GridRow {
                        Text(text("Name", "Name"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        TextField(
                            text("Name", "Name"),
                            text: selectedRemoteProviderBinding(\.displayName, default: "")
                        )
                        .textFieldStyle(.roundedBorder)
                    }

                    GridRow {
                        Text(text("Base URL", "Base URL"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        TextField(
                            "", text: selectedRemoteProviderBinding(\.baseURLString, default: "")
                        )
                        .textFieldStyle(.roundedBorder)
                    }

                    GridRow {
                        Text(text("Modelle", "Models"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        TextField(
                            "",
                            text: selectedRemoteProviderBinding(\.modelsPath, default: "/models")
                        )
                        .textFieldStyle(.roundedBorder)
                    }

                    GridRow {
                        Text(text("Text-API", "Text API"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        TextField(
                            "",
                            text: selectedRemoteProviderBinding(
                                \.chatCompletionsPath, default: "/chat/completions")
                        )
                        .textFieldStyle(.roundedBorder)
                    }

                    GridRow {
                        Text(text("API-Key nötig", "API key required"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Toggle(
                            text("Ja", "Yes"),
                            isOn: selectedRemoteProviderBinding(\.requiresAPIKey, default: true)
                        )
                        .toggleStyle(.switch)
                    }

                    GridRow {
                        Text(text("API-Key", "API key"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        SecureField("", text: $appState.remoteProviderAPIKeyDraft)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                HStack(spacing: 8) {
                    Button(text("Speichern", "Save")) {
                        appState.saveSelectedRemoteProvider()
                    }
                    .liquidGlassPrimaryButtonStyle()

                    Spacer()

                    Button(role: .destructive) {
                        appState.removeSelectedRemoteProvider()
                    } label: {
                        Text(text("Anbieter entfernen", "Remove provider"))
                    }
                    .liquidGlassDestructiveButtonStyle()
                }

                if !provider.discoveredModels.isEmpty {
                    Text(
                        text(
                            "Verfügbare Modelle: \(provider.discoveredModels.count)",
                            "Available models: \(provider.discoveredModels.count)"
                        )
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.45))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
    }

    @ViewBuilder
    private var aiModelContent: some View {
        if aiHasMatches {
            LabeledContent {
                Picker(
                    text("Modell", "Model"),
                    selection: Binding(
                        get: { appState.selectedAIModelID ?? "" },
                        set: { appState.selectedAIModelID = $0.isEmpty ? nil : $0 }
                    )
                ) {
                    if appState.visibleAIModels.isEmpty {
                        Text(text("Keine Modelle erkannt", "No models detected")).tag("")
                    } else {
                        ForEach(appState.visibleAIModels) { model in
                            Text(model.displayName).tag(model.id)
                        }
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .settingsFormMenuPickerSlot(minWidth: 220)
            } label: {
                SettingsFieldLabel(
                    title: text("Modell", "Model"),
                    helpText: text(
                        "Zeigt alle aktuell erkannten lokalen und entfernten Modelle an, die WisprLocal verwenden kann.",
                        "Shows all currently detected local and remote models that WisprLocal can use."
                    )
                )
            }

            if appState.visibleAIModels.isEmpty {
                Text(
                    text(
                        "Es wurde aktuell kein AI-Modell erkannt.",
                        "There is currently no AI model available.")
                )
                .foregroundStyle(.secondary)
            } else {
                ForEach(appState.visibleAIModels, id: \AIModelDescriptor.id) {
                    (model: AIModelDescriptor) in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.displayName)
                            .font(.body.weight(.semibold))
                        Text(model.providerKind.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(
                            model.availability.localizedDisplayName(
                                interfaceLanguageCode: effectiveLanguage.embeddedInterfaceCode)
                        )
                        .font(.footnote)
                        .foregroundStyle(
                            model.availability.isAvailable ? Color.secondary : Color.orange)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    @ViewBuilder
    private var startStopShortcutContent: some View {
        if matches(["shortcut", "kurzbefehl", "hold", "dictation", "diktat"]) {
            Toggle(
                text("Start/Stopp-Kurzbefehl aktiv", "Enable start/stop shortcut"),
                isOn: $appState.toggleShortcutEnabled)

            LabeledContent(text("Kurzbefehl", "Shortcut")) {
                HotkeyRecorderField(
                    hotkey: $appState.selectedHotkey,
                    label: text("Diktier-Kurzbefehl", "Dictation shortcut"),
                    language: effectiveLanguage
                )
                .frame(width: 260)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            if let advisory = appState.hotkeyAdvisory {
                HotkeyAdvisoryBox(advisory: advisory)
            }
        }
    }

    @ViewBuilder
    private var holdShortcutContent: some View {
        if matches(["shortcut", "kurzbefehl", "hold", "dictation", "diktat"]) {
            Toggle(
                text("Halten-zum-Diktieren aktiv", "Enable hold-to-dictate"),
                isOn: $appState.holdToDictateEnabled)

            LabeledContent {
                HotkeyRecorderField(
                    hotkey: $appState.holdShortcut,
                    label: text("Halten-zum-Diktieren-Kurzbefehl", "Hold-to-dictate shortcut"),
                    language: effectiveLanguage
                )
                .frame(width: 260)
                .frame(maxWidth: .infinity, alignment: .trailing)
            } label: {
                SettingsFieldLabel(
                    title: text("Hold-Kurzbefehl", "Hold shortcut"),
                    helpText: text(
                        "Fn allein wird im aktuellen globalen Hotkey-Pfad nicht zuverlässig unterstützt.",
                        "Fn by itself is not supported reliably in the current global hotkey path."
                    )
                )
            }
            .disabled(!appState.holdToDictateEnabled)

            if appState.holdToDictateEnabled, let advisory = appState.holdShortcutAdvisory {
                HotkeyAdvisoryBox(advisory: advisory)
            }
        }
    }

    @ViewBuilder
    private var cancelShortcutContent: some View {
        if matches(["shortcut", "kurzbefehl", "cancel", "abbrechen", "diktat"]) {
            Toggle(
                text("Abbrechen-Shortcut aktiv", "Enable cancel shortcut"),
                isOn: $appState.cancelShortcutEnabled)

            LabeledContent(text("Abbrechen-Kurzbefehl", "Cancel shortcut")) {
                HotkeyRecorderField(
                    hotkey: $appState.cancelShortcut,
                    label: text("Abbrechen-Kurzbefehl", "Cancel shortcut"),
                    language: effectiveLanguage
                )
                .frame(width: 260)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .disabled(!appState.cancelShortcutEnabled)

            if appState.cancelShortcutEnabled, let advisory = appState.cancelShortcutAdvisory {
                HotkeyAdvisoryBox(advisory: advisory)
            }
        }
    }

    @ViewBuilder
    private var modeSwitchShortcutContent: some View {
        if matches(["shortcut", "kurzbefehl", "mode", "modus", "diktat"]) {
            Toggle(
                text("Moduswechsel-Shortcut aktiv", "Enable mode switch shortcut"),
                isOn: $appState.modeSwitchShortcutEnabled)

            LabeledContent(text("Moduswechsel-Kurzbefehl", "Mode switch shortcut")) {
                HotkeyRecorderField(
                    hotkey: $appState.modeSwitchShortcut,
                    label: text("Moduswechsel-Kurzbefehl", "Mode switch shortcut"),
                    language: effectiveLanguage
                )
                .frame(width: 260)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .disabled(!appState.modeSwitchShortcutEnabled)

            if appState.modeSwitchShortcutEnabled,
                let advisory = appState.modeSwitchShortcutAdvisory
            {
                HotkeyAdvisoryBox(advisory: advisory)
            }
        }
    }

    @ViewBuilder
    private var historyActionContent: some View {
        if historyHasMatches {
            HStack(alignment: .center, spacing: 10) {
                Button(text("Letztes Diktat kopieren", "Copy last dictation")) {
                    copyToClipboard(appState.latestDictationText)
                }
                .liquidGlassPrimaryButtonStyle()
                .disabled(appState.latestDictationText.isEmpty)

                Button(text("Verlauf exportieren", "Export history")) {
                    appState.exportHistoryAsText()
                }
                .liquidGlassSecondaryButtonStyle()

                Button(role: .destructive) {
                    appState.clearHistory()
                } label: {
                    Text(text("Verlauf leeren", "Clear history"))
                }
                .liquidGlassDestructiveButtonStyle()
            }
        }
    }

    @ViewBuilder
    private var historyRetentionContent: some View {
        if historyHasMatches {
            LabeledContent {
                Picker(
                    text("Verlauf aufbewahren", "Keep history"),
                    selection: $appState.historyRetentionPolicy
                ) {
                    ForEach(HistoryRetentionPolicy.allCases) { policy in
                        Text(
                            policy.localizedDisplayName(
                                interfaceLanguageCode: effectiveLanguage.embeddedInterfaceCode)
                        ).tag(policy)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .settingsFormMenuPickerSlot(minWidth: 180)
            } label: {
                SettingsFieldLabel(
                    title: text("Verlauf aufbewahren", "Keep history"),
                    helpText: text(
                        "Bereinigt nur den lokalen Transkriptverlauf. Systemdateien oder Roh-Audio werden dabei nicht verändert.",
                        "Prunes only the local transcript history. System files or raw audio are not changed."
                    )
                )
            }
        }
    }

    @ViewBuilder
    private var historyEntriesContent: some View {
        if filteredHistory.isEmpty {
            Text(text("Keine Transkripte gefunden.", "No transcripts found."))
                .foregroundStyle(.secondary)
        } else {
            Table(compactHistoryEntries) {
                TableColumn(text("Datum", "Date")) { entry in
                    Text(formattedHistoryDate(entry.createdAt))
                        .textSelection(.enabled)
                }
                .width(min: 118, ideal: 140)
                TableColumn(text("Modus", "Mode")) { entry in
                    Text("[\(entry.mode) • \(entry.languageCode)]")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                .width(min: 100, ideal: 120)
                TableColumn(text("Vorschau", "Preview")) { entry in
                    Text(entry.text)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .textSelection(.enabled)
                }
                TableColumn("") { entry in
                    HStack(spacing: 6) {
                        Button {
                            appState.copyHistoryEntry(entry)
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(
                            text("Diktat kopieren", "Copy dictation")
                        )
                        Button(role: .destructive) {
                            appState.removeHistoryEntry(entry.id)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(
                            text("Diktat löschen: ", "Delete dictation: ")
                                + formattedHistoryDate(entry.createdAt))
                    }
                }
                .width(ideal: 72)
            }
            .frame(minHeight: 200)

            if !isSearching, filteredHistory.count > compactHistoryEntries.count {
                Text(
                    text(
                        "Es werden zuerst die letzten \(compactHistoryEntries.count) Diktate angezeigt. Über die Suche findest du ältere Einträge.",
                        "The latest \(compactHistoryEntries.count) dictations are shown first. Use search to find older entries."
                    )
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var snippetNewEntryRows: some View {
        if matches(["snippet", "textbaustein", "replacement", "trigger"]) {
            LabeledContent(text("Trigger", "Trigger")) {
                TextField(text("Trigger", "Trigger"), text: $newSnippetTrigger)
                    .textFieldStyle(.plain)
                    .frame(minWidth: 200)
                    .accessibilityLabel(text("Snippet-Trigger", "Snippet trigger"))
                    .onSubmit { commitNewSnippet() }
            }
            LabeledContent(text("Ersetzung", "Replacement")) {
                TextField(
                    text("Ersetzung", "Replacement"),
                    text: $newSnippetReplacement,
                    axis: .vertical
                )
                .textFieldStyle(.plain)
                .lineLimit(3, reservesSpace: true)
                .accessibilityLabel(text("Snippet-Ersetzung", "Snippet replacement"))
                .onSubmit { commitNewSnippet() }
            }
            if newSnippetTriggerIsDuplicate, !trimmedNewSnippetTrigger.isEmpty {
                Text(
                    text("Dieser Trigger ist bereits vergeben.", "This trigger is already in use.")
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            Button(text("Hinzufügen", "Add")) {
                commitNewSnippet()
            }
            .liquidGlassPrimaryButtonStyle()
            .disabled(!canCommitNewSnippet)
            .keyboardShortcut(.defaultAction)
        }
    }

    @ViewBuilder
    private var snippetImportExportRows: some View {
        if matches([
            "snippet", "textbaustein", "replacement", "trigger", "json", "import", "export",
            "importieren", "exportieren",
        ]) {
            HStack(alignment: .center, spacing: 10) {
                Button(text("JSON importieren", "Import JSON")) {
                    appState.importSnippetsFromJSON()
                }
                .liquidGlassSecondaryButtonStyle()
                Button(text("JSON exportieren", "Export JSON")) {
                    appState.exportSnippetsToJSON()
                }
                .liquidGlassSecondaryButtonStyle()
            }
        }
    }

    @ViewBuilder
    private var snippetSavedRows: some View {
        if matches(["snippet", "textbaustein", "replacement", "trigger"])
            || !filteredSnippets.isEmpty
        {
            if filteredSnippets.isEmpty {
                Text(text("Keine Snippets gespeichert.", "No snippets saved."))
                    .foregroundStyle(.secondary)
            } else {
                Table(filteredSnippets) {
                    TableColumn(text("Trigger", "Trigger")) { rule in
                        Text(rule.trigger)
                            .textSelection(.enabled)
                    }
                    TableColumn(text("Ersetzung", "Replacement")) { rule in
                        Text(rule.replacement)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    TableColumn("") { rule in
                        Button(role: .destructive) {
                            appState.removeSnippet(ruleID: rule.id)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(
                            text("Snippet löschen: ", "Delete snippet: ") + rule.trigger)
                    }
                    .width(ideal: 44)
                }
                .frame(minHeight: 200)
            }
        }
    }

    @ViewBuilder
    private var diagnosticsContent: some View {
        if matches(["diagnose", "diagnostics", "lizenz", "license", "capability", "audit"]) {
            VStack(alignment: .leading, spacing: 12) {
                Text(appState.capabilitySummary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                Text(
                    text(
                        "Smoke-Test: Log-Datei artifacts/mac/dev-run.log (Projektroot).",
                        "Smoke test: log file artifacts/mac/dev-run.log (project root)."
                    )
                )
                .font(.caption2)
                .foregroundStyle(.tertiary)

                Toggle(isOn: $appState.debugModeEnabled) {
                    SettingsFieldLabel(
                        title: text("Technische Protokollierung", "Technical logging"),
                        helpText: text(
                            "Erfasst zusätzliche Laufzeit- und Prozessdetails für die Diagnose. Nur einschalten, wenn du ein Problem genauer untersuchen willst.",
                            "Captures additional runtime and process details for diagnostics. Enable this only when you want to investigate a problem more closely."
                        )
                    )
                }

                if appState.debugModeEnabled {
                    DisclosureGroup(
                        content: {
                            Text(
                                appState.debugLogText.isEmpty
                                    ? text(
                                        "Noch keine Diagnoseprotokoll-Einträge erfasst.",
                                        "No diagnostic log entries captured yet.")
                                    : appState.debugLogText
                            )
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        },
                        label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(
                                    text(
                                        "Technisches Diagnoseprotokoll", "Technical diagnostic log")
                                )
                                Text(
                                    appState.debugLogText.isEmpty
                                        ? text(
                                            "Die technische Protokollierung ist aktiv. Neue Laufzeit- und Prozessereignisse erscheinen hier.",
                                            "Technical logging is active. New runtime and process events will appear here."
                                        )
                                        : appState.debugLogText.components(separatedBy: .newlines)
                                            .suffix(3).joined(separator: " ")
                                )
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .textSelection(.enabled)
                            }
                            .frame(minHeight: 38, alignment: .topLeading)
                        }
                    )
                }

                DisclosureGroup(
                    isExpanded: $diagnosticsExpanded,
                    content: {
                        Text(appState.diagnosticsText)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    },
                    label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(text("Letzte Diagnosezeilen", "Recent diagnostic lines"))
                            Text(
                                compressedDiagnosticsText.replacingOccurrences(of: "\n", with: " ")
                            )
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .textSelection(.enabled)
                        }
                        .frame(minHeight: 38, alignment: .topLeading)
                    }
                )

                HStack(alignment: .center, spacing: 10) {
                    Button(
                        text(
                            "Alles kopieren (Diagnose + Protokoll)",
                            "Copy all (diagnostics + log)")
                    ) {
                        copyToClipboard(appState.diagnosticsAndDebugCombinedForClipboard())
                    }
                    .liquidGlassSecondaryButtonStyle()

                    Button(text("Diagnose kopieren", "Copy diagnostics")) {
                        copyToClipboard(compressedDiagnosticsText)
                    }
                    .liquidGlassSecondaryButtonStyle()
                    .disabled(compressedDiagnosticsText.isEmpty)

                    Button(text("Diagnose exportieren", "Export diagnostics")) {
                        appState.exportDiagnosticsReport()
                    }
                    .liquidGlassSecondaryButtonStyle()

                    if appState.debugModeEnabled {
                        Button(text("Diagnoseprotokoll exportieren", "Export diagnostic log")) {
                            appState.exportDebugLog()
                        }
                        .liquidGlassSecondaryButtonStyle()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var licenseContent: some View {
        if matches(["diagnose", "diagnostics", "lizenz", "license", "capability", "audit"]) {
            HStack {
                SecureField(text("Lizenzschlüssel", "License key"), text: $appState.licenseInput)
                    .textFieldStyle(.roundedBorder)
                Button(text("Aktivieren", "Activate")) {
                    appState.activateLicense()
                }
                .liquidGlassPrimaryButtonStyle()
                .disabled(
                    appState.licenseInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button(role: .destructive) {
                    appState.deactivateLicense()
                } label: {
                    Text(text("Deaktivieren", "Deactivate"))
                }
                .liquidGlassDestructiveButtonStyle()
            }

            if let storedLicenseSummary = appState.storedLicenseSummary {
                Text(text("Gespeicherter Schlüssel", "Stored key") + ": " + storedLicenseSummary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Text(appState.licenseStatusText)
                .foregroundStyle(appState.licensePresentationState.color)
                .font(.footnote)
        }
    }

    private func copyToClipboard(_ string: String) {
        guard !string.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }

}
