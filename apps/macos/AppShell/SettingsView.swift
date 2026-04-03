import AppKit
import ASRCore
import AIProcessingCore
import Carbon
import SnippetCore
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: MacAppState
    @AppStorage("wispr.uiLanguage") private var uiLanguageRaw: String = AppLanguage.german.rawValue

    @State private var diagnosticsExpanded = false
    @State private var newSnippetTrigger: String = ""
    @State private var newSnippetReplacement: String = ""
    @State private var searchText: String = ""

    private let personalWebsiteURL = URL(string: "https://leon-stadler.com")!

    private static let historyDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter
    }()

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: uiLanguageRaw) ?? .german
    }

    private func text(_ german: String, _ english: String) -> String {
        appLanguage.text(german, english)
    }

    private var searchQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var isSearching: Bool {
        !searchQuery.isEmpty
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
            $0.text.lowercased().contains(searchQuery) ||
            $0.languageCode.lowercased().contains(searchQuery) ||
            $0.mode.lowercased().contains(searchQuery)
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
            $0.trigger.lowercased().contains(searchQuery) ||
            $0.replacement.lowercased().contains(searchQuery)
        }
    }

    private var generalHasMatches: Bool {
        matches(["language", "sprache", "menüleiste", "menu bar", "shortcut hints", "compact", "kompakt", "dock", "launch on login", "updates", "zugriff", "permissions", "berechtigungen", "mikrofon", "accessibility", "bedienungshilfen"])
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
            "weit zurück"
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
            "download"
        ])
    }

    private var shortcutsHasMatches: Bool {
        matches(["shortcut", "kurzbefehl", "hold", "dictation", "diktat", "cancel", "abbrechen", "mode", "modus"])
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
            "api key"
        ])
    }

    private var showsExpandedAIControls: Bool {
        !appState.compactMenuBarDesign
    }

    private var historyHasMatches: Bool {
        matches(["history", "verlauf", "transkript", "dictation", "diktat", "retention", "aufbewahrung", "storage", "folder"]) || !filteredHistory.isEmpty
    }

    private var aboutHasMatches: Bool {
        matches(["about", "über", "ueber", "leon", "stadler", "website", "webseite", "opensource", "open source", "intermedia", "design", "fotografie", "vorarlberg", "changelog", "neuigkeiten", "release", "release notes", "änderungen", "aenderungen"])
    }

    private var snippetsHasMatches: Bool {
        matches(["snippet", "textbaustein", "replacement", "trigger"]) || !filteredSnippets.isEmpty
    }

    private var advancedHasMatches: Bool {
        matches(["update", "updates", "aktualisierung", "diagnose", "diagnostics", "capability", "audit", "storage", "folder", "app support", "logs", "protokolle", "voice", "modell", "model", "warm", "dauer", "duration", "laufzeit", "speicher halten", "runtime"]) ||
            appState.diagnosticsText.lowercased().contains(searchQuery) ||
            appState.capabilitySummary.lowercased().contains(searchQuery) ||
            appState.updaterStatusText.lowercased().contains(searchQuery)
    }

    private var soundHasMatches: Bool {
        matches(["sound", "audio", "mikrofon", "volume", "loudness", "silence", "normalization", "normalisierung", "verstärkung", "gain", "feedback"])
    }

    private var compressedDiagnosticsText: String {
        let lines = appState.diagnosticsText
            .split(separator: "\n")
            .map(String.init)
        let preview = lines.suffix(8).joined(separator: "\n")
        return preview.isEmpty ? appState.diagnosticsText : preview
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                List(selection: selectedTabSelection) {
                    Section {
                        ForEach(SettingsTab.allCases, id: \.self) { tab in
                            Label(tab.title(language: appLanguage), systemImage: tab.symbolName)
                                .tag(tab)
                                .font(.system(size: 14, weight: .medium))
                        }
                    }
                }
                .listStyle(.sidebar)
                .environment(\.defaultMinListRowHeight, 32)
                .scrollContentBackground(.hidden)
                .safeAreaPadding(.top, 8)
                .padding(.horizontal, 6)
            }
            .frame(width: 260)
            .background(.regularMaterial)

            Divider()

            VStack(alignment: .leading, spacing: 14) {
                Text(isSearching ? text("Suchergebnisse", "Search Results") : currentSelectedTab.title(language: appLanguage))
                    .font(.title2.weight(.semibold))
                    .frame(maxWidth: 780, alignment: .leading)

                NativeSearchField(
                    placeholder: text("Einstellungen durchsuchen", "Search settings"),
                    text: $searchText
                )
                .frame(width: 360)
                .frame(maxWidth: 780, alignment: .leading)

                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.62))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                        )

                    Group {
                        if isSearching {
                            searchResultsForm
                        } else {
                    selectedForm
                }
                    }
                    .padding(8)
                }
                .frame(maxWidth: 780, maxHeight: .infinity, alignment: .topLeading)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .environment(\.locale, appLanguage.locale)
        .frame(width: 1000, height: 650)
        .controlSize(.regular)
        .background(.ultraThinMaterial)
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
            set: { appState.selectedSettingsTab = $0 }
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
            if showsExpandedAIControls {
                Section(text("Anbieter", "Providers")) {
                    aiProviderContent
                }
                Section(text("Modelle", "Models")) {
                    aiModelContent
                }
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
                aboutProfileContent
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
            Section(text("Snippets", "Snippets")) {
                snippetsContent
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
                    speechProviderContent
                    speechModelSelectionContent
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
                    historyEntriesContent
                }
            }

            if aboutHasMatches {
                Section(text("About", "About")) {
                    aboutProfileContent
                    aboutChangelogContent
                    if appState.isLicenseUIEnabledForDevelopment {
                        aboutSupportContent
                    }
                }
            }

            if snippetsHasMatches {
                Section(text("Snippets", "Snippets")) {
                    snippetsContent
                }
            }

            if advancedHasMatches {
                Section(text("Erweitert", "Advanced")) {
                    advancedOverviewContent
                    voiceModelRuntimeContent
                    updatesContent
                    diagnosticsContent
                    if appState.isLicenseUIEnabledForDevelopment {
                        licenseContent
                    }
                }
            }

            if !generalHasMatches && !speechHasMatches && !dictationHasMatches && !soundHasMatches && !shortcutsHasMatches && !aiHasMatches && !historyHasMatches && !aboutHasMatches && !snippetsHasMatches && !advancedHasMatches {
                Section {
                    Text(text("Keine passenden Einstellungen gefunden.", "No matching settings found."))
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
                        Text(language.displayName).tag(language.rawValue)
                    }
                }
                .labelsHidden()
                .frame(minWidth: 170)
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
                    title: text("Kurzbefehl-Hinweise im Menü anzeigen", "Show shortcut hints in menu"),
                    helpText: text(
                        "Zeigt Tastenkombinationen direkt neben passenden Einträgen im Menüleisten-Menü an.",
                        "Shows keyboard shortcuts directly next to matching menu bar items."
                    )
                )
            }
        }
    }

    @ViewBuilder
    private var advancedOverviewContent: some View {
        if matches(["update", "updates", "aktualisierung", "diagnose", "diagnostics", "capability", "audit"]) {
            EmptyView()
        }
    }

    @ViewBuilder
    private var advancedStorageContent: some View {
        if matches(["storage", "folder", "app support", "speicherort", "datenordner", "app folder", "logs", "protokolle"]) {
            LabeledContent {
                VStack(alignment: .leading, spacing: 10) {
                    Text(appState.appSupportDirectoryPathText)
                        .font(.footnote.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)

                    Button(text("Ordner im Finder öffnen", "Open folder in Finder")) {
                        appState.revealAppDataFolder()
                    }
                    .buttonStyle(.bordered)
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
        if matches(["voice", "sprachmodell", "model runtime", "runtime", "duration", "dauer", "warm", "speicher halten", "modelllaufzeit"]) {
            LabeledContent {
                Picker(text("Sprachmodell im Speicher halten", "Keep voice model in memory"), selection: $appState.voiceModelActiveDuration) {
                    ForEach(VoiceModelActiveDuration.allCases) { duration in
                        Text(duration.localizedDisplayName(interfaceLanguageCode: appLanguage.rawValue)).tag(duration)
                    }
                }
                .labelsHidden()
                .frame(minWidth: 220)
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
                    .buttonStyle(.bordered)
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
    private var aboutProfileContent: some View {
        if matches(["about", "über", "ueber", "leon", "stadler", "website", "webseite", "opensource", "open source", "intermedia", "design", "fotografie", "vorarlberg"]) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(.quaternary.opacity(0.55))
                            .frame(width: 52, height: 52)

                        Text("LS")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.primary)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Leon Stadler")
                            .font(.title3.weight(.semibold))

                        Text(text(
                            "Kommunikationsdesigner, Entwickler und Intermedia-Student",
                            "Communication designer, developer, and Intermedia student"
                        ))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }

                Text(text(
                    "Ich bin in München aufgewachsen, lebe heute am Bodensee und arbeite an zeitgemäßen digitalen Produkten zwischen Design, Technik und kreativer Problemlösung. WisprLocal ist aus genau diesem Zusammenspiel entstanden: eine lokale Offline-Diktierlösung für den Mac, die ruhig, nativ und alltagstauglich wirkt.",
                    "I grew up in Munich, now live near Lake Constance, and work on contemporary digital products across design, technology, and creative problem-solving. WisprLocal grew out of exactly that intersection: a local offline dictation tool for the Mac that aims to feel calm, native, and genuinely useful in everyday work."
                ))
                .fixedSize(horizontal: false, vertical: true)

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    AboutFactRow(
                        title: text("Schwerpunkte", "Focus"),
                        detail: text("Webdesign, UX/UI, Prototyping, Fotografie und kreative technische Systeme", "Web design, UX/UI, prototyping, photography, and creative technical systems")
                    )
                    AboutFactRow(
                        title: text("Standort", "Location"),
                        detail: text("Bodensee / Dornbirn, Vorarlberg", "Lake Constance / Dornbirn, Vorarlberg")
                    )
                    AboutFactRow(
                        title: text("Projektgedanke", "Project intent"),
                        detail: text("Lokale, datensparsame Tools mit klarer nativer Benutzerführung", "Local, privacy-conscious tools with clear native user experience")
                    )
                }

                Link(destination: personalWebsiteURL) {
                    Label(text("Mehr über mich", "Learn more about me"), systemImage: "globe")
                }
                .buttonStyle(.bordered)
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var aboutChangelogContent: some View {
        if matches(["changelog", "neuigkeiten", "release", "release notes", "änderungen", "aenderungen", "features", "fixes"]) {
            ChangelogSectionView(entries: AppChangelogCatalog.latestEntries, language: appLanguage)
        }
    }

    @ViewBuilder
    private var aboutSupportContent: some View {
        if matches(["support", "spenden", "donate", "website", "webseite"]) {
            Text(text(
                "Die App bleibt offen und frei nutzbar. Wenn du das Projekt unterstützen möchtest, findest du über die Website künftig weitere Möglichkeiten dafür.",
                "The app stays open and free to use. If you want to support the project, the website will later be the place for additional support options."
            ))
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            Link(destination: personalWebsiteURL) {
                Label(text("Projekt unterstützen", "Support the project"), systemImage: "heart")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    private var generalPermissionsContent: some View {
        if matches(["mikrofon", "accessibility", "bedienungshilfen", "permissions", "berechtigungen"]) {
            PermissionStatusRow(
                title: text("Mikrofon", "Microphone"),
                status: appState.microphonePermissionStatus,
                detail: text("Erforderlich für die Audioaufnahme.", "Required for audio capture."),
                actionTitle: text("Öffnen", "Open"),
                actionHint: text("Mikrofon-Einstellungen öffnen", "Open microphone settings"),
                action: {
                    appState.openMicrophoneSettings()
                }
            )

            PermissionStatusRow(
                title: text("Bedienungshilfen", "Accessibility"),
                status: appState.accessibilityPermissionStatus,
                detail: text("Erforderlich zum Einfügen in das aktive Textfeld.", "Required to insert into the active text field."),
                actionTitle: text("Öffnen", "Open"),
                actionHint: text("Bedienungshilfen öffnen", "Open accessibility settings"),
                action: {
                    appState.openAccessibilitySettings()
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
                VStack(alignment: .leading, spacing: 6) {
                    Slider(value: $appState.noiseSuppressionLevel, in: 0...1, step: 0.05)
                    Text(text("Filterstärke", "Filter strength") + ": \(Int((appState.noiseSuppressionLevel * 100).rounded()))%")
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .frame(minWidth: 240)
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
                VStack(alignment: .leading, spacing: 6) {
                    Slider(value: $appState.soundEffectsVolume, in: 0...100, step: 1)
                    Text("\(Int(appState.soundEffectsVolume.rounded()))%")
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .frame(minWidth: 240)
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
                Picker(text("Voice-Anbieter", "Voice provider"), selection: $appState.selectedVoiceProviderID) {
                    ForEach(appState.voiceProviders) { provider in
                        Text(provider.displayName).tag(provider.id)
                    }
                }
                .labelsHidden()
                .frame(minWidth: 240)
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
                Text(text(
                    "Modell, Sprache und Übersetzung sind getrennt. Das Modell bestimmt Größe, Tempo und Fähigkeiten. Die Sprache begrenzt nur die sinnvollen Eingaben.",
                    "Model, language, and translation are separate. The model defines size, speed, and capabilities. Language only limits the sensible input choices."
                ))
                .font(.subheadline)

                Text(text(
                    "Qualität steuert Beam-Search, Chunking und Threads. Sie ändert nicht mehr das eigentliche Modell.",
                    "Quality controls beam search, chunking, and threads. It no longer changes the actual model."
                ))
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var speechModelSelectionContent: some View {
        if speechHasMatches {
            LabeledContent {
                Picker(text("Voice-Modell", "Voice model"), selection: $appState.selectedVoiceModelID) {
                    ForEach(appState.visibleVoiceModels) { model in
                        Text(model.displayName).tag(model.id)
                    }
                }
                .labelsHidden()
                .frame(minWidth: 240)
            } label: {
                SettingsFieldLabel(
                    title: text("Voice-Modell", "Voice model"),
                    helpText: text(
                        "Das Modell bestimmt die tatsächliche Transkriptions-Engine. Qualität darunter steuert nur Laufzeitparameter wie Beam und Chunking.",
                        "The model defines the actual transcription engine. Quality below only adjusts runtime parameters like beam and chunking."
                    )
                )
            }
        }
    }

    @ViewBuilder
    private var speechLanguageContent: some View {
        if speechHasMatches {
            LabeledContent {
                Picker(text("Eingabesprache", "Input language"), selection: $appState.selectedLanguage) {
                    ForEach(appState.selectedVoiceModelLanguageOptions) { language in
                        Text(language.localizedDisplayName(interfaceLanguageCode: appLanguage.rawValue)).tag(language)
                    }
                }
                .labelsHidden()
                .frame(minWidth: 180)
            } label: {
                SettingsFieldLabel(
                    title: text("Eingabesprache", "Input language"),
                    helpText: text(
                        "Bei multilingualen Modellen kannst du die Sprache frei wählen. Bei rein englischen Modellen reduziert sich die Auswahl automatisch.",
                        "For multilingual models you can choose freely. For English-only models the picker is reduced automatically."
                    )
                )
            }

            if let selectedModel = appState.selectedVoiceModel {
                Text(selectedModel.languageCode == nil
                    ? text("Multilinguales Modell: alle Sprachen verfügbar.", "Multilingual model: all languages available.")
                    : text("Sprache ist an das Modell gebunden.", "Language is bound to the model.")
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
                Picker(text("Qualitätsprofil", "Quality profile"), selection: $appState.performanceProfile) {
                    ForEach(DictationPerformance.allCases) { mode in
                        Text(mode.localizedDisplayName(interfaceLanguageCode: appLanguage.rawValue)).tag(mode)
                    }
                }
                .labelsHidden()
                .frame(minWidth: 180)
            } label: {
                SettingsFieldLabel(
                    title: text("Qualitätsprofil", "Quality profile"),
                    helpText: text(
                        "Steuert Laufzeitparameter wie Beam-Search, Chunking und Threads. Es ändert nicht mehr heimlich das Modell.",
                        "Controls runtime parameters like beam search, chunking, and threads. It no longer changes the model behind your back."
                    )
                )
            }

            if let selectedModel = appState.selectedVoiceModel {
                LabeledContent(text("Modell-Details", "Model details")) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(text("Bereich", "Scope")): \(selectedModel.languageCode?.uppercased() ?? "ALL")")
                        Text("\(text("Übersetzung", "Translation")): \(selectedModel.supportsTranslationToEnglish ? text("Ja", "Yes") : text("Nein", "No"))")
                        Text("\(text("Geschwindigkeit", "Speed")) \(selectedModel.speedScore)/10  \(text("Genauigkeit", "Accuracy")) \(selectedModel.accuracyScore)/10  \(selectedModel.sizeLabel)")
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
                Picker(text("Übersetzen nach", "Translate to"), selection: $appState.translationOutputMode) {
                    ForEach(TranslationOutputMode.allCases) { mode in
                        Text(mode.localizedDisplayName(interfaceLanguageCode: appLanguage.rawValue)).tag(mode)
                    }
                }
                .labelsHidden()
                .frame(minWidth: 170)
                .disabled(!appState.speechTranslationAvailable)
            } label: {
                SettingsFieldLabel(
                    title: text("Übersetzen nach", "Translate to"),
                    helpText: text(
                        "Keine Übersetzung gibt die gesprochene Sprache zurück. Nach Englisch aktiviert ausschließlich die lokale Whisper-Übersetzung. Sprachspezifische English-Modelle unterstützen das nicht.",
                        "No translation returns the spoken language. English only enables local Whisper translation. Language-specific English models do not support it."
                    )
                )
            }
        }
        else if speechHasMatches {
            Text(text(
                "Dieses Modell unterstützt keine Übersetzung. Die Option bleibt deshalb ausgeblendet.",
                "This model does not support translation. The option is therefore hidden."
            ))
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
                        Text(appState.isVoiceModelInstalled(model) ? text("Installiert", "Installed") : text("Nicht installiert", "Not installed"))
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(appState.isVoiceModelInstalled(model) ? .secondary : .tertiary)
                        if appState.isVoiceModelInstalled(model) {
                            Button(text("Als Standard verwenden", "Use as default")) {
                                appState.setSelectedVoiceModel(model)
                            }
                            .disabled(appState.selectedVoiceModelID == model.id || appState.isVoiceModelBusy(model))

                            if model.installState != .bundled {
                                Button(text("Entfernen", "Remove")) {
                                    appState.removeVoiceModel(model)
                                }
                                .disabled(appState.isVoiceModelBusy(model))
                            }
                        } else {
                            Button(text("Installieren", "Install")) {
                                appState.installVoiceModel(model)
                            }
                            .disabled(model.installState == .unavailable || appState.isVoiceModelBusy(model))
                        }
                    }
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
            "live"
        ]) {
            LabeledContent {
                Picker(text("Anpassungsradius", "Adjustment radius"), selection: $appState.liveRewriteScope) {
                    ForEach(LiveRewriteScope.allCases) { scope in
                        Text(scope.localizedDisplayName(interfaceLanguageCode: appLanguage.rawValue)).tag(scope)
                    }
                }
                .labelsHidden()
                .frame(minWidth: 260)
            } label: {
                SettingsFieldLabel(
                    title: text("Anpassungsradius", "Adjustment radius"),
                    helpText: text(
                        "Kleinere Bereiche sind stabiler. Größere Bereiche glätten stärker, dürfen aber weiter zurückliegende Wörter noch einmal anfassen.",
                        "Smaller scopes are more stable. Larger scopes smooth more aggressively but may revisit words further back."
                    )
                )
            }
        }
    }

    @ViewBuilder
    private var dictationDeliveryContent: some View {
        if matches(["sprache", "language", "qualität", "quality", "streaming", "clipboard", "zwischenablage", "insert", "translation", "übersetzung", "uebersetzung", "paste", "auto-send", "keypress"]) {
            LabeledContent {
                Picker(text("Finales Ergebnis", "Final result"), selection: $appState.finalResultDeliveryMode) {
                    Text(text("In Textfeld einfügen", "Insert into text field")).tag(FinalResultDeliveryMode.insert)
                    Text(text("Nur in Zwischenablage kopieren", "Copy to clipboard only")).tag(FinalResultDeliveryMode.clipboardOnly)
                }
                .labelsHidden()
                .frame(minWidth: 220)
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
                .disabled(appState.finalResultDeliveryMode == .clipboardOnly || !appState.dictationCapability.allowsDirectInsertion)

            Toggle(isOn: $appState.clipboardFallbackWhenNoTarget) {
                SettingsFieldLabel(
                    title: text("Wenn kein Textfeld aktiv ist: Ergebnis in Zwischenablage kopieren", "If no text field is active: copy result to clipboard"),
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
                        "Nützlich in Chats oder Formularen, wenn das eingefügte Ergebnis direkt abgeschickt werden soll.",
                        "Useful in chats or forms when the inserted result should be sent immediately."
                    )
                )
            }
            Toggle(isOn: $appState.restoreClipboardAfterPaste) {
                SettingsFieldLabel(
                    title: text("Zwischenablage nach dem Einfügen wiederherstellen", "Restore clipboard after paste"),
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
                        "Verwendet simulierte Tastenanschläge für finales Einfügen und Fallbacks, wenn der direkte Einfügepfad nicht ausreicht.",
                        "Uses simulated keypresses for final insertion and fallbacks when the direct insertion path is not enough."
                    )
                )
            }

            if !appState.dictationCapability.allowsDirectInsertion {
                Text(text(
                    "Ohne Bedienungshilfen startet die Aufnahme weiterhin, aber direktes Einfügen bleibt deaktiviert.",
                    "Without Accessibility, recording still starts, but direct insertion remains disabled."
                ))
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var aiProcessingContent: some View {
        if aiHasMatches {
            Toggle(text("AI-Verarbeitung aktivieren", "Enable AI processing"), isOn: $appState.aiProcessingEnabled)
                .disabled(appState.selectedAIModel?.availability.isAvailable != true)

            if appState.aiProcessingEnabled {
                LabeledContent {
                    VStack(alignment: .leading, spacing: 8) {
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
                    .frame(minWidth: 220, alignment: .leading)
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

                if showsExpandedAIControls {
                    LabeledContent {
                        Picker(text("AI-Ziel", "AI goal"), selection: $appState.aiRevisionGoal) {
                            ForEach(AIRevisionGoal.allCases) { goal in
                                Text(goal.localizedDisplayName(interfaceLanguageCode: appLanguage.rawValue)).tag(goal)
                            }
                        }
                        .labelsHidden()
                        .frame(minWidth: 220)
                    } label: {
                        SettingsFieldLabel(
                            title: text("AI-Ziel", "AI goal"),
                            helpText: text(
                                "Standardmäßig bereinigt die AI den diktierten Text. Alternativ kannst du sie gezielt für Ton, Anrede oder Format einsetzen.",
                                "By default, AI cleans up dictated text. You can also use it specifically for tone, salutation, or formatting."
                            )
                        )
                        }
                    }
                    .disabled(appState.selectedAIModel?.availability.isAvailable != true)

                    LabeledContent {
                        Picker(text("Modus", "Mode"), selection: $appState.aiFormattingMode) {
                            ForEach(AIFormattingMode.allCases) { mode in
                                Text(mode.localizedDisplayName(interfaceLanguageCode: appLanguage.rawValue)).tag(mode)
                            }
                        }
                        .labelsHidden()
                        .frame(minWidth: 220)
                    } label: {
                        SettingsFieldLabel(
                            title: text("Modus", "Mode"),
                            helpText: text(
                                "Legt fest, für welche Art von Text die AI optimieren soll, zum Beispiel E-Mail, Nachricht, Dokumentation oder wissenschaftliche Arbeit.",
                                "Defines which kind of text the AI should optimize for, such as email, message, documentation, or scientific writing."
                            )
                        )
                    }
                    .disabled(appState.selectedAIModel?.availability.isAvailable != true)

                    if appState.aiShowsWritingStyleControls {
                        LabeledContent {
                            Picker(text("Stil / Ton", "Style / Tone"), selection: $appState.aiWritingStyle) {
                                ForEach(appState.availableAIWritingStyles) { style in
                                    Text(style.localizedDisplayName(interfaceLanguageCode: appLanguage.rawValue)).tag(style)
                                }
                            }
                            .labelsHidden()
                            .frame(minWidth: 220)
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
                                    Text(salutation.localizedDisplayName(interfaceLanguageCode: appLanguage.rawValue)).tag(salutation)
                                }
                            }
                            .labelsHidden()
                            .frame(minWidth: 220)
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
                }

                if !showsExpandedAIControls {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(text("Kompakte Ansicht", "Compact view"))
                            .font(.subheadline.weight(.semibold))

                        Text(text(
                            "Hier bleiben nur die wichtigsten Schalter sichtbar. Modell, Ziel, Modus, Stil und Anrede findest du in der erweiterten Ansicht.",
                            "Only the most important switches stay visible here. Model, goal, mode, style, and salutation live in the expanded view."
                        ))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.top, 2)
                }
            }
        }
    }

    @ViewBuilder
    private var aiProviderContent: some View {
        if aiHasMatches {
            VStack(alignment: .leading, spacing: 14) {
                Text(text("Anbieter hinzufügen", "Add provider"))
                    .font(.headline)

                providerPresetGrid

                if appState.remoteProviders.isEmpty {
                    EmptyView()
                } else {
                    providerSelectionRow
                    providerEditorCard
                }
            }
        }
    }

    @ViewBuilder
    private var providerPresetGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            providerPresetGroup(
                title: text("Cloud-APIs", "Cloud APIs"),
                presets: [.openRouter, .openAI, .groq, .mistral, .deepSeek, .togetherAI, .fireworksAI, .xAI]
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
    private func providerPresetGroup(title: String, presets: [AIRemoteProviderPreset]) -> some View {
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
                    Button {
                        appState.addRemoteProvider(preset: preset)
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(preset.localizedDisplayName(interfaceLanguageCode: appLanguage.rawValue))
                                .font(.body.weight(.semibold))
                            Text(providerPresetDescription(for: preset))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private func providerPresetDescription(for preset: AIRemoteProviderPreset) -> String {
        switch preset {
        case .openRouter:
            return text("Viele Modelle über einen zentralen Zugang.", "Many models through one unified gateway.")
        case .openAI:
            return text("Offizielle OpenAI-API.", "Official OpenAI API.")
        case .groq:
            return text("Schnelle OpenAI-kompatible Cloud-API.", "Fast OpenAI-compatible cloud API.")
        case .mistral:
            return text("Mistral über die OpenAI-kompatible Schnittstelle.", "Mistral via the OpenAI-compatible surface.")
        case .deepSeek:
            return text("DeepSeek mit Standard-Endpunkten.", "DeepSeek with standard endpoints.")
        case .togetherAI:
            return text("Modellvielfalt für Remote-Setups.", "Model variety for remote setups.")
        case .fireworksAI:
            return text("Gehostete Modelle mit klaren Endpunkten.", "Hosted models with clear endpoints.")
        case .xAI:
            return text("xAI über OpenAI-kompatible Calls.", "xAI over OpenAI-compatible calls.")
        case .ollama:
            return text("Lokale Modelle ohne API-Key.", "Local models without an API key.")
        case .lmStudio:
            return text("Lokaler Server für eigene Modelle.", "Local server for your own models.")
        case .customOpenAICompatible:
            return text("Eigene Base-URL und Endpunkte definieren.", "Define your own base URL and endpoints.")
        }
    }

    @ViewBuilder
    private var providerSelectionRow: some View {
        LabeledContent(text("Aktiver Anbieter", "Active provider")) {
            Picker(text("Aktiver Anbieter", "Active provider"), selection: Binding(
                get: { appState.selectedRemoteProviderID ?? "" },
                set: { appState.selectedRemoteProviderID = $0.isEmpty ? nil : $0 }
            )) {
                ForEach(appState.remoteProviders) { provider in
                    Text(provider.displayName).tag(provider.id)
                }
            }
            .labelsHidden()
            .frame(minWidth: 240)
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
                        Text(provider.preset.localizedDisplayName(interfaceLanguageCode: appLanguage.rawValue))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Toggle(text("Aktiv", "Enabled"), isOn: selectedRemoteProviderBinding(\.isEnabled, default: false))
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
                        TextField("", text: selectedRemoteProviderBinding(\.baseURLString, default: ""))
                        .textFieldStyle(.roundedBorder)
                    }

                    GridRow {
                        Text(text("Modelle", "Models"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        TextField("", text: selectedRemoteProviderBinding(\.modelsPath, default: "/models"))
                        .textFieldStyle(.roundedBorder)
                    }

                    GridRow {
                        Text(text("Text-API", "Text API"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        TextField("", text: selectedRemoteProviderBinding(\.chatCompletionsPath, default: "/chat/completions"))
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
                    .buttonStyle(.bordered)

                    Spacer()

                    Button(role: .destructive) {
                        appState.removeSelectedRemoteProvider()
                    } label: {
                        Text(text("Anbieter entfernen", "Remove provider"))
                    }
                    .buttonStyle(.bordered)
                }

                if !provider.discoveredModels.isEmpty {
                    Text(text(
                        "Verfügbare Modelle: \(provider.discoveredModels.count)",
                        "Available models: \(provider.discoveredModels.count)"
                    ))
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
                Picker(text("Modell", "Model"), selection: Binding(
                    get: { appState.selectedAIModelID ?? "" },
                    set: { appState.selectedAIModelID = $0.isEmpty ? nil : $0 }
                )) {
                    if appState.visibleAIModels.isEmpty {
                        Text(text("Keine Modelle erkannt", "No models detected")).tag("")
                    } else {
                        ForEach(appState.visibleAIModels) { model in
                            Text(model.displayName).tag(model.id)
                        }
                    }
                }
                .labelsHidden()
                .frame(minWidth: 220)
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
                Text(text("Es wurde aktuell kein AI-Modell erkannt.", "There is currently no AI model available."))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(appState.visibleAIModels, id: \AIModelDescriptor.id) { (model: AIModelDescriptor) in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.displayName)
                            .font(.body.weight(.semibold))
                        Text(model.providerKind.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(model.availability.localizedDisplayName(interfaceLanguageCode: appLanguage.rawValue))
                            .font(.footnote)
                            .foregroundStyle(model.availability.isAvailable ? Color.secondary : Color.orange)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    @ViewBuilder
    private var startStopShortcutContent: some View {
        if matches(["shortcut", "kurzbefehl", "hold", "dictation", "diktat"]) {
            Toggle(text("Start/Stopp-Kurzbefehl aktiv", "Enable start/stop shortcut"), isOn: $appState.toggleShortcutEnabled)

            LabeledContent(text("Kurzbefehl", "Shortcut")) {
                HotkeyRecorderField(
                    hotkey: $appState.selectedHotkey,
                    label: text("Diktier-Kurzbefehl", "Dictation shortcut"),
                    language: appLanguage
                )
                .frame(width: 260)
            }

            if let advisory = appState.hotkeyAdvisory {
                HotkeyAdvisoryBox(advisory: advisory)
            }
        }
    }

    @ViewBuilder
    private var holdShortcutContent: some View {
        if matches(["shortcut", "kurzbefehl", "hold", "dictation", "diktat"]) {
            Toggle(text("Halten-zum-Diktieren aktiv", "Enable hold-to-dictate"), isOn: $appState.holdToDictateEnabled)

            LabeledContent {
                HotkeyRecorderField(
                    hotkey: $appState.holdShortcut,
                    label: text("Halten-zum-Diktieren-Kurzbefehl", "Hold-to-dictate shortcut"),
                    language: appLanguage
                )
                .frame(width: 260)
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
            Toggle(text("Abbrechen-Shortcut aktiv", "Enable cancel shortcut"), isOn: $appState.cancelShortcutEnabled)

            LabeledContent(text("Abbrechen-Kurzbefehl", "Cancel shortcut")) {
                HotkeyRecorderField(
                    hotkey: $appState.cancelShortcut,
                    label: text("Abbrechen-Kurzbefehl", "Cancel shortcut"),
                    language: appLanguage
                )
                .frame(width: 260)
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
            Toggle(text("Moduswechsel-Shortcut aktiv", "Enable mode switch shortcut"), isOn: $appState.modeSwitchShortcutEnabled)

            LabeledContent(text("Moduswechsel-Kurzbefehl", "Mode switch shortcut")) {
                HotkeyRecorderField(
                    hotkey: $appState.modeSwitchShortcut,
                    label: text("Moduswechsel-Kurzbefehl", "Mode switch shortcut"),
                    language: appLanguage
                )
                .frame(width: 260)
            }
            .disabled(!appState.modeSwitchShortcutEnabled)

            if appState.modeSwitchShortcutEnabled, let advisory = appState.modeSwitchShortcutAdvisory {
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
                .buttonStyle(.borderedProminent)
                .disabled(appState.latestDictationText.isEmpty)

                Button(text("Verlauf exportieren", "Export history")) {
                    appState.exportHistoryAsText()
                }
                .buttonStyle(.bordered)

                Button(text("Verlauf leeren", "Clear history")) {
                    appState.clearHistory()
                }
                .buttonStyle(.bordered)
            }
        }
    }

    @ViewBuilder
    private var historyRetentionContent: some View {
        if historyHasMatches {
            LabeledContent {
                Picker(text("Verlauf aufbewahren", "Keep history"), selection: $appState.historyRetentionPolicy) {
                    ForEach(HistoryRetentionPolicy.allCases) { policy in
                        Text(policy.localizedDisplayName(interfaceLanguageCode: appLanguage.rawValue)).tag(policy)
                    }
                }
                .labelsHidden()
                .frame(minWidth: 180)
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
            ForEach(compactHistoryEntries) { entry in
                HistoryEntryRow(
                    entry: entry,
                    dateText: Self.historyDateFormatter.string(from: entry.createdAt),
                    language: appLanguage,
                    onCopy: { appState.copyHistoryEntry(entry) },
                    onDelete: { appState.removeHistoryEntry(entry.id) }
                )
            }

            if !isSearching, filteredHistory.count > compactHistoryEntries.count {
                Text(text(
                    "Es werden zuerst die letzten \(compactHistoryEntries.count) Diktate angezeigt. Über die Suche findest du ältere Einträge.",
                    "The latest \(compactHistoryEntries.count) dictations are shown first. Use search to find older entries."
                ))
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var snippetsContent: some View {
        if matches(["snippet", "textbaustein", "replacement", "trigger"]) {
            HStack(alignment: .center, spacing: 10) {
                TextField(text("Trigger", "Trigger"), text: $newSnippetTrigger)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel(text("Snippet-Trigger", "Snippet trigger"))
                TextField(text("Ersetzung", "Replacement"), text: $newSnippetReplacement)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel(text("Snippet-Ersetzung", "Snippet replacement"))
                Button(text("Hinzufügen", "Add")) {
                    appState.addSnippet(trigger: newSnippetTrigger, replacement: newSnippetReplacement)
                    newSnippetTrigger = ""
                    newSnippetReplacement = ""
                }
                .buttonStyle(.borderedProminent)
            }

            HStack(alignment: .center, spacing: 10) {
                Button(text("JSON importieren", "Import JSON")) {
                    appState.importSnippetsFromJSON()
                }
                .buttonStyle(.bordered)
                Button(text("JSON exportieren", "Export JSON")) {
                    appState.exportSnippetsToJSON()
                }
                .buttonStyle(.bordered)
            }

            if filteredSnippets.isEmpty {
                Text(text("Keine Snippets gespeichert.", "No snippets saved."))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(filteredSnippets) { rule in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(rule.trigger)
                            Text(rule.replacement)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(text("Löschen", "Delete")) {
                            appState.removeSnippet(ruleID: rule.id)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(text("Snippet löschen: ", "Delete snippet: ") + rule.trigger)
                    }
                }
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
                            Text(appState.debugLogText.isEmpty ? text("Noch keine Diagnoseprotokoll-Einträge erfasst.", "No diagnostic log entries captured yet.") : appState.debugLogText)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        },
                        label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(text("Technisches Diagnoseprotokoll", "Technical diagnostic log"))
                                Text(appState.debugLogText.isEmpty ? text("Die technische Protokollierung ist aktiv. Neue Laufzeit- und Prozessereignisse erscheinen hier.", "Technical logging is active. New runtime and process events will appear here.") : appState.debugLogText.components(separatedBy: .newlines).suffix(3).joined(separator: "\n"))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
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
                            Text(compressedDiagnosticsText)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                )

                HStack(alignment: .center, spacing: 10) {
                    Button(text("Diagnose kopieren", "Copy diagnostics")) {
                        copyToClipboard(compressedDiagnosticsText)
                    }
                    .buttonStyle(.bordered)
                    .disabled(compressedDiagnosticsText.isEmpty)

                    Button(text("Diagnose exportieren", "Export diagnostics")) {
                        appState.exportDiagnosticsReport()
                    }
                    .buttonStyle(.bordered)

                    if appState.debugModeEnabled {
                        Button(text("Diagnoseprotokoll exportieren", "Export diagnostic log")) {
                            appState.exportDebugLog()
                        }
                        .buttonStyle(.bordered)
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
                .buttonStyle(.borderedProminent)
                .disabled(appState.licenseInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button(text("Deaktivieren", "Deactivate")) {
                    appState.deactivateLicense()
                }
                .buttonStyle(.bordered)
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

enum SettingsTab: Hashable, CaseIterable {
    case general
    case speech
    case dictation
    case sound
    case shortcuts
    case ai
    case history
    case about
    case snippets
    case advanced

    var symbolName: String {
        switch self {
        case .general: return "gearshape"
        case .speech: return "waveform.badge.mic"
        case .dictation: return "mic"
        case .sound: return "speaker.wave.2"
        case .shortcuts: return "command"
        case .ai: return "sparkles"
        case .history: return "clock.arrow.circlepath"
        case .about: return "person.crop.circle"
        case .snippets: return "text.badge.plus"
        case .advanced: return "wrench.and.screwdriver"
        }
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .general:
            return language.text("Allgemein", "General")
        case .speech:
            return language.text("Speech", "Speech")
        case .dictation:
            return language.text("Diktat", "Dictation")
        case .sound:
            return language.text("Sound", "Sound")
        case .shortcuts:
            return language.text("Kurzbefehle", "Shortcuts")
        case .ai:
            return "AI"
        case .history:
            return language.text("Verlauf", "History")
        case .about:
            return language.text("About", "About")
        case .snippets:
            return language.text("Snippets", "Snippets")
        case .advanced:
            return language.text("Erweitert", "Advanced")
        }
    }
}

private struct AboutFactRow: View {
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)
            Text(detail)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct SettingsFieldLabel: View {
    let title: String
    var helpText: String? = nil

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
            if let helpText, !helpText.isEmpty {
                SettingsHelpIcon(text: helpText)
            }
        }
    }
}

private struct SettingsHelpIcon: View {
    let text: String
    @State private var isHovering = false
    @State private var showPopover = false
    @State private var hoverTask: Task<Void, Never>?

    var body: some View {
        Image(systemName: "info.circle")
            .font(.caption)
            .foregroundStyle(showPopover ? .primary : .secondary)
            .onHover { hovering in
                isHovering = hovering
                hoverTask?.cancel()
                hoverTask = Task { @MainActor in
                    if hovering {
                        try? await Task.sleep(nanoseconds: 350_000_000)
                        if isHovering {
                            showPopover = true
                        }
                    } else {
                        try? await Task.sleep(nanoseconds: 120_000_000)
                        if !isHovering {
                            showPopover = false
                        }
                    }
                }
            }
            .popover(isPresented: $showPopover, attachmentAnchor: .point(.bottom), arrowEdge: .top) {
                ScrollView {
                    Text(text)
                        .font(.callout)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(12)
                }
                .frame(width: 320)
                .frame(maxHeight: 220)
            }
            .accessibilityLabel(text)
            .onDisappear {
                hoverTask?.cancel()
            }
    }
}

private struct HistoryEntryRow: View {
    let entry: TranscriptHistoryEntry
    let dateText: String
    let language: AppLanguage
    let onCopy: () -> Void
    let onDelete: () -> Void
    @State private var isExpanded = false

    private func text(_ german: String, _ english: String) -> String {
        language.text(german, english)
    }

    private var requiresExpansion: Bool {
        entry.text.count > 180 || entry.text.split(separator: "\n").count > 3
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(dateText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("[\(entry.mode) • \(entry.languageCode)]")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(text("Kopieren", "Copy")) {
                    onCopy()
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(text("Diktat kopieren vom ", "Copy dictation from ") + dateText)
                Button(text("Löschen", "Delete")) {
                    onDelete()
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(text("Diktat löschen vom ", "Delete dictation from ") + dateText)
            }

            Text(entry.text)
                .lineLimit(3)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)

            if requiresExpansion {
                DisclosureGroup(text("Vollständiges Diktat anzeigen", "Show full transcript"), isExpanded: $isExpanded) {
                    Text(entry.text)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                        .padding(.top, 2)
                }
                .font(.footnote)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct HotkeyRecorderField: NSViewRepresentable {
    @Binding var hotkey: HotkeyBinding
    let label: String
    let language: AppLanguage

    func makeNSView(context: Context) -> HotkeyRecorderButton {
        let view = HotkeyRecorderButton()
        view.onChange = { newHotkey in
            hotkey = newHotkey
        }
        return view
    }

    func updateNSView(_ nsView: HotkeyRecorderButton, context: Context) {
        nsView.displayedHotkey = hotkey
        nsView.fieldLabel = label
        nsView.language = language
    }
}

private struct HotkeyAdvisoryBox: View {
    let advisory: HotkeyAdvisory

    private var accentColor: Color {
        switch advisory.severity {
        case .critical:
            return .red
        case .warning:
            return .orange
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(advisory.title)
                .font(.footnote.weight(.semibold))
            Text(advisory.message)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(accentColor.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(accentColor.opacity(0.3), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

private struct NativeSearchField: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField(frame: .zero)
        field.delegate = context.coordinator
        field.placeholderString = placeholder
        field.sendsSearchStringImmediately = true
        return field
    }

    func updateNSView(_ nsView: NSSearchField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        nsView.placeholderString = placeholder
    }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        @Binding var text: String

        init(text: Binding<String>) {
            _text = text
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSSearchField else { return }
            text = field.stringValue
        }
    }
}

private final class HotkeyRecorderButton: NSButton {
    var onChange: ((HotkeyBinding) -> Void)?
    var displayedHotkey: HotkeyBinding = .optionSpace {
        didSet { updatePresentation() }
    }
    var fieldLabel: String = "Shortcut" {
        didSet { updatePresentation() }
    }
    var language: AppLanguage = .german {
        didSet { updatePresentation() }
    }

    private var isRecording = false {
        didSet { updatePresentation() }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        bezelStyle = .rounded
        setButtonType(.momentaryPushIn)
        target = self
        action = #selector(beginRecording)
        updatePresentation()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var acceptsFirstResponder: Bool { true }

    @objc private func beginRecording() {
        isRecording = true
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == UInt16(kVK_Escape) && event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty {
            isRecording = false
            updatePresentation()
            return
        }

        guard let binding = HotkeyBinding.from(event: event) else {
            NSSound.beep()
            return
        }

        displayedHotkey = binding
        isRecording = false
        onChange?(binding)
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        updatePresentation()
        return true
    }

    private func updatePresentation() {
        title = isRecording
            ? language.text("Jetzt Tastenkombination drücken", "Press shortcut now")
            : displayedHotkey.displayName
        setAccessibilityLabel(fieldLabel)
        setAccessibilityValue(title)
        setAccessibilityHelp(language.text(
            "Leertaste oder Return zum Aufnehmen, Escape zum Abbrechen.",
            "Press Space or Return to start recording, Escape to cancel."
        ))
    }
}

private struct PermissionStatusRow: View {
    let title: String
    let status: PermissionStatus
    let detail: String
    let actionTitle: String?
    let actionHint: String?
    let action: (() -> Void)?

    init(
        title: String,
        status: PermissionStatus,
        detail: String,
        actionTitle: String? = nil,
        actionHint: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.status = status
        self.detail = detail
        self.actionTitle = actionTitle
        self.actionHint = actionHint
        self.action = action
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 10) {
                Text(status.label)
                    .foregroundStyle(status.color)

                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                        .buttonStyle(.bordered)
                        .help(actionHint ?? actionTitle)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
