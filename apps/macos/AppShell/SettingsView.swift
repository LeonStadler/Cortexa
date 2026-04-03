import AppKit
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
        matches(["language", "sprache", "menüleiste", "menu bar", "shortcut hints", "zugriff", "permissions", "berechtigungen", "mikrofon", "accessibility", "bedienungshilfen"])
    }

    private var dictationHasMatches: Bool {
        matches([
            "sprache",
            "language",
            "translation",
            "translate",
            "übersetzung",
            "uebersetzung",
            "qualität",
            "quality",
            "streaming",
            "clipboard",
            "zwischenablage",
            "insert",
            "delivery",
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

    private var shortcutsHasMatches: Bool {
        matches(["shortcut", "kurzbefehl", "hold", "dictation", "diktat"]) 
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
            "key"
        ])
    }

    private var historyHasMatches: Bool {
        matches(["history", "verlauf", "transkript", "dictation", "diktat"]) || !filteredHistory.isEmpty
    }

    private var aboutHasMatches: Bool {
        matches(["about", "über", "ueber", "leon", "stadler", "website", "webseite", "opensource", "open source", "intermedia", "design", "fotografie", "vorarlberg"])
    }

    private var snippetsHasMatches: Bool {
        matches(["snippet", "textbaustein", "replacement", "trigger"]) || !filteredSnippets.isEmpty
    }

    private var advancedHasMatches: Bool {
        matches(["update", "updates", "aktualisierung", "diagnose", "diagnostics", "capability", "audit"]) ||
            appState.diagnosticsText.lowercased().contains(searchQuery) ||
            appState.capabilitySummary.lowercased().contains(searchQuery) ||
            appState.updaterStatusText.lowercased().contains(searchQuery)
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
        case .dictation:
            dictationForm
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

    private var dictationForm: some View {
        Form {
            Section(text("Erkennung", "Recognition")) {
                dictationRecognitionContent
            }
            Section(text("Übersetzung", "Translation")) {
                translationContent
            }
            Section(text("Live-Anpassung", "Live rewriting")) {
                liveRewriteContent
            }
            Section(text("Ablage", "Delivery")) {
                dictationDeliveryContent
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
        }
        .formStyle(.grouped)
        .frame(maxWidth: 760, alignment: .leading)
    }

    private var aiForm: some View {
        Form {
            Section(text("Verarbeitung", "Processing")) {
                aiProcessingContent
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
                    generalPermissionsContent
                }
            }

            if dictationHasMatches {
                Section(text("Diktat", "Dictation")) {
                    dictationRecognitionContent
                    translationContent
                    liveRewriteContent
                    dictationDeliveryContent
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
                    updatesContent
                    diagnosticsContent
                    if appState.isLicenseUIEnabledForDevelopment {
                        licenseContent
                    }
                }
            }

            if !generalHasMatches && !dictationHasMatches && !shortcutsHasMatches && !aiHasMatches && !historyHasMatches && !aboutHasMatches && !snippetsHasMatches && !advancedHasMatches {
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
        if matches(["language", "sprache", "menüleiste", "menu bar", "shortcut hints"]) {
            LabeledContent(text("App-Sprache", "App language")) {
                Picker(text("App-Sprache", "App Language"), selection: $uiLanguageRaw) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language.rawValue)
                    }
                }
                .labelsHidden()
                .frame(minWidth: 170)
            }

            Toggle(text("Kurzbefehl-Hinweise im Menü anzeigen", "Show shortcut hints in menu"), isOn: $appState.showMenuBarShortcutHints)

            Text(text(
                "Diese Option zeigt Tastenkombinationen direkt neben passenden Einträgen im Dropdown-Menü an.",
                "This option shows keyboard shortcuts next to matching items in the dropdown menu."
            ))
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var advancedOverviewContent: some View {
        if matches(["update", "updates", "aktualisierung", "diagnose", "diagnostics", "capability", "audit"]) {
            VStack(alignment: .leading, spacing: 6) {
                Text(text(
                    "Hier bündelt WisprLocal alles, was eher administrativ ist: Update-Status, technische Diagnose und interne Prüfpfade.",
                    "This section groups the more administrative parts of WisprLocal: update status, technical diagnostics, and internal inspection paths."
                ))
                .font(.footnote)
                .foregroundStyle(.secondary)

                Text(text(
                    "Updates laufen im Hintergrund über Sparkle; manuelle Checks bleiben hier erreichbar.",
                    "Updates run in the background through Sparkle; manual checks remain available here."
                ))
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var updatesContent: some View {
        if matches(["update", "updates", "aktualisierung"]) {
            VStack(alignment: .leading, spacing: 12) {
                Text(text(
                    "WisprLocal nutzt Sparkle direkt in der App und sucht automatisch im Hintergrund nach Aktualisierungen.",
                    "WisprLocal uses Sparkle directly inside the app and checks for updates automatically in the background."
                ))
                .font(.footnote)
                .foregroundStyle(.secondary)

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
                detail: text("Erforderlich für die Audioaufnahme.", "Required for audio capture.")
            )

            PermissionStatusRow(
                title: text("Bedienungshilfen", "Accessibility"),
                status: appState.accessibilityPermissionStatus,
                detail: text("Erforderlich zum Einfügen in das aktive Textfeld.", "Required to insert into the active text field.")
            )

            HStack(alignment: .center, spacing: 10) {
                Button(text("Mikrofon öffnen", "Open microphone settings")) {
                    appState.openMicrophoneSettings()
                }
                .buttonStyle(.bordered)
                Button(text("Bedienungshilfen öffnen", "Open accessibility settings")) {
                    appState.openAccessibilitySettings()
                }
                .buttonStyle(.bordered)
            }

            Text(appState.dictationCapability.localizedSummary)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var dictationRecognitionContent: some View {
        if matches(["sprache", "language", "qualität", "quality", "streaming", "clipboard", "zwischenablage", "insert", "translation", "übersetzung", "uebersetzung"]) {
            LabeledContent(text("Diktatsprache", "Dictation language")) {
                Picker(text("Diktatsprache", "Dictation language"), selection: $appState.selectedLanguage) {
                    ForEach(DictationLanguage.allCases) { language in
                        Text(language.localizedDisplayName(interfaceLanguageCode: appLanguage.rawValue)).tag(language)
                    }
                }
                .labelsHidden()
                .frame(minWidth: 170)
            }

            LabeledContent(text("Erkennungsqualität", "Recognition quality")) {
                Picker(text("Erkennungsqualität", "Recognition quality"), selection: $appState.performanceProfile) {
                    ForEach(DictationPerformance.allCases) { mode in
                        Text(mode.localizedDisplayName(interfaceLanguageCode: appLanguage.rawValue)).tag(mode)
                    }
                }
                .labelsHidden()
                .frame(minWidth: 170)
            }
        }
    }

    @ViewBuilder
    private var translationContent: some View {
        if matches(["translation", "translate", "übersetzung", "uebersetzung", "sprache", "language"]) {
            LabeledContent(text("Übersetzen nach", "Translate to")) {
                Picker(text("Übersetzen nach", "Translate to"), selection: $appState.translationOutputMode) {
                    ForEach(TranslationOutputMode.allCases) { mode in
                        Text(mode.localizedDisplayName(interfaceLanguageCode: appLanguage.rawValue)).tag(mode)
                    }
                }
                .labelsHidden()
                .frame(minWidth: 170)
            }

            Text(text(
                "Auto-Spracherkennung übersetzt nicht mehr implizit. 'Keine Übersetzung' gibt die gesprochene Sprache zurück; 'Nach Englisch' aktiviert gezielt die Whisper-Übersetzung.",
                "Auto language detection no longer translates implicitly. 'Original' returns the spoken language; 'English' explicitly enables Whisper translation."
            ))
            .font(.footnote)
            .foregroundStyle(.secondary)
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
            LabeledContent(text("Anpassungsradius", "Adjustment radius")) {
                Picker(text("Anpassungsradius", "Adjustment radius"), selection: $appState.liveRewriteScope) {
                    ForEach(LiveRewriteScope.allCases) { scope in
                        Text(scope.localizedDisplayName(interfaceLanguageCode: appLanguage.rawValue)).tag(scope)
                    }
                }
                .labelsHidden()
                .frame(minWidth: 260)
            }

            Text(text(
                "Kleinere Bereiche sind stabiler und greifen nur am aktuellen Satz an; größere Bereiche glätten stärker, können aber weiter zurückliegende Wörter erneut anfassen.",
                "Smaller scopes are more stable and only touch the current sentence; larger scopes smooth more aggressively and can revisit words further back."
            ))
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var dictationDeliveryContent: some View {
        if matches(["sprache", "language", "qualität", "quality", "streaming", "clipboard", "zwischenablage", "insert", "translation", "übersetzung", "uebersetzung"]) {
            LabeledContent(text("Finales Ergebnis", "Final result")) {
                Picker(text("Finales Ergebnis", "Final result"), selection: $appState.finalResultDeliveryMode) {
                    Text(text("In Textfeld einfügen", "Insert into text field")).tag(FinalResultDeliveryMode.insert)
                    Text(text("Nur in Zwischenablage kopieren", "Copy to clipboard only")).tag(FinalResultDeliveryMode.clipboardOnly)
                }
                .labelsHidden()
                .frame(minWidth: 220)
            }

            Toggle(text("Live-Text einfügen", "Insert live text"), isOn: $appState.streamingEnabled)
                .disabled(appState.finalResultDeliveryMode == .clipboardOnly || !appState.dictationCapability.allowsDirectInsertion)

            Toggle(text("Wenn kein Textfeld aktiv ist: Ergebnis in Zwischenablage kopieren", "If no text field is active: copy result to clipboard"), isOn: $appState.clipboardFallbackWhenNoTarget)
                .disabled(appState.finalResultDeliveryMode == .clipboardOnly)

            if appState.finalResultDeliveryMode == .clipboardOnly {
                Text(text(
                    "Nur Zwischenablage verwendet immer den Abschluss-Pfad. Live-Einfügen wird in diesem Modus deaktiviert.",
                    "Clipboard-only always uses the finalize path. Live insert is disabled in this mode."
                ))
                .font(.footnote)
                .foregroundStyle(.secondary)

                Text(text(
                    "Datenschutzhinweis: Zwischenablage ist absichtlich global. Andere Apps oder Clipboard-Tools können kopierten Text kurzfristig sehen.",
                    "Privacy note: the clipboard is intentionally global. Other apps or clipboard tools may briefly observe copied text."
                ))
                .font(.footnote)
                .foregroundStyle(.secondary)
            } else if !appState.dictationCapability.allowsDirectInsertion {
                Text(text(
                    "Ohne Bedienungshilfen startet die Aufnahme weiterhin, aber direktes Einfügen bleibt deaktiviert.",
                    "Without Accessibility, recording still starts, but direct insertion remains disabled."
                ))
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            if appState.clipboardFallbackWhenNoTarget && appState.finalResultDeliveryMode != .clipboardOnly {
                Text(text(
                    "Wenn kein Textfeld aktiv ist, wird der finale Text über die globale Zwischenablage zugestellt. Das ist gewollt, aber weniger privat als direktes Einfügen.",
                    "When no text field is active, the final text is delivered through the global clipboard. This is intentional, but less private than direct insertion."
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
                LabeledContent(text("Modell", "Model")) {
                    Picker(text("Modell", "Model"), selection: Binding(
                        get: { appState.selectedAIModelID ?? "" },
                        set: { appState.selectedAIModelID = $0.isEmpty ? nil : $0 }
                    )) {
                        if appState.aiModels.isEmpty {
                            Text(text("Keine Modelle erkannt", "No models detected")).tag("")
                        } else {
                            ForEach(appState.aiModels) { model in
                                Text(model.displayName).tag(model.id)
                            }
                        }
                    }
                    .labelsHidden()
                    .frame(minWidth: 220)
                }

                LabeledContent(text("AI anwenden bei", "Apply AI for")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(
                            text("Live-Einfügen", "Live insertion"),
                            isOn: $appState.aiProcessingApplyDuringLiveInsertion
                        )
                        .disabled(!appState.streamingEnabled)

                        Toggle(
                            text("Finalem Ergebnis", "Final result"),
                            isOn: $appState.aiProcessingApplyToFinalResult
                        )
                    }
                    .frame(minWidth: 220, alignment: .leading)
                }
                .disabled(appState.selectedAIModel?.availability.isAvailable != true)

                LabeledContent(text("Stil / Ton", "Style / Tone")) {
                    Picker(text("Stil / Ton", "Style / Tone"), selection: $appState.aiWritingStyle) {
                        ForEach(AIWritingStyle.allCases) { style in
                            Text(style.localizedDisplayName(interfaceLanguageCode: appLanguage.rawValue)).tag(style)
                        }
                    }
                    .labelsHidden()
                    .frame(minWidth: 220)
                }
                .disabled(appState.selectedAIModel?.availability.isAvailable != true)

                LabeledContent(text("Anrede", "Salutation")) {
                    Picker(text("Anrede", "Salutation"), selection: $appState.aiSalutation) {
                        ForEach(AISalutation.allCases) { salutation in
                            Text(salutation.localizedDisplayName(interfaceLanguageCode: appLanguage.rawValue)).tag(salutation)
                        }
                    }
                    .labelsHidden()
                    .frame(minWidth: 220)
                }
                .disabled(appState.selectedAIModel?.availability.isAvailable != true)
            }

            Section(text("API-Anbieter", "API providers")) {
                HStack(spacing: 8) {
                    Menu(text("Anbieter hinzufügen", "Add provider")) {
                        ForEach(AIRemoteProviderPreset.allCases) { preset in
                            Button(preset.localizedDisplayName(interfaceLanguageCode: appLanguage.rawValue)) {
                                appState.addRemoteProvider(preset: preset)
                            }
                        }
                    }
                    if appState.selectedRemoteProvider != nil {
                        Button(role: .destructive) {
                            appState.removeSelectedRemoteProvider()
                        } label: {
                            Text(text("Entfernen", "Remove"))
                        }
                    }
                }

                if !appState.remoteProviders.isEmpty {
                    LabeledContent(text("Anbieter", "Provider")) {
                        Picker(text("Anbieter", "Provider"), selection: Binding(
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

                if appState.selectedRemoteProvider != nil {
                    LabeledContent(text("Typ", "Type")) {
                        Text(appState.selectedRemoteProvider?.preset.localizedDisplayName(interfaceLanguageCode: appLanguage.rawValue) ?? "")
                    }

                    Toggle(
                        text("Anbieter aktivieren", "Enable provider"),
                        isOn: selectedRemoteProviderBinding(\.isEnabled, default: false)
                    )

                    LabeledContent(text("Name", "Name")) {
                        TextField(
                            text("Name", "Name"),
                            text: selectedRemoteProviderBinding(\.displayName, default: "")
                        )
                        .frame(minWidth: 260)
                    }

                    LabeledContent(text("Base URL", "Base URL")) {
                        TextField(
                            "https://api.example.com/v1",
                            text: selectedRemoteProviderBinding(\.baseURLString, default: "")
                        )
                        .frame(minWidth: 260)
                    }

                    LabeledContent(text("Modelle laden über", "Load models from")) {
                        TextField(
                            "/models",
                            text: selectedRemoteProviderBinding(\.modelsPath, default: "/models")
                        )
                        .frame(minWidth: 220)
                    }

                    LabeledContent(text("Text-API", "Text API")) {
                        TextField(
                            "/chat/completions",
                            text: selectedRemoteProviderBinding(\.chatCompletionsPath, default: "/chat/completions")
                        )
                        .frame(minWidth: 220)
                    }

                    Toggle(
                        text("API-Key erforderlich", "API key required"),
                        isOn: selectedRemoteProviderBinding(\.requiresAPIKey, default: true)
                    )

                    LabeledContent(text("API-Key", "API key")) {
                        SecureField("sk-...", text: $appState.remoteProviderAPIKeyDraft)
                            .frame(minWidth: 260)
                    }

                    HStack(spacing: 8) {
                        Button(text("API-Key speichern", "Save API key")) {
                            appState.saveSelectedRemoteProviderAPIKey()
                        }
                        Button(text("Modelle aktualisieren", "Refresh models")) {
                            appState.refreshSelectedRemoteProviderModels()
                        }
                    }

                    if let provider = appState.selectedRemoteProvider, !provider.discoveredModels.isEmpty {
                        Text(text(
                            "Verfügbare Modelle: \(provider.discoveredModels.count)",
                            "Available models: \(provider.discoveredModels.count)"
                        ))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    } else if let provider = appState.selectedRemoteProvider, !provider.requiresAPIKey {
                        Text(text(
                            "Für lokale OpenAI-kompatible Server wie Ollama oder LM Studio ist kein API-Key nötig.",
                            "No API key is required for local OpenAI-compatible servers such as Ollama or LM Studio."
                        ))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                }
            }

        }
    }

    @ViewBuilder
    private var aiModelContent: some View {
        if aiHasMatches {
            if appState.aiModels.isEmpty {
                Text(text("Es wurde aktuell kein AI-Modell erkannt.", "There is currently no AI model available."))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(appState.aiModels, id: \AIModelDescriptor.id) { (model: AIModelDescriptor) in
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

            LabeledContent(text("Hold-Kurzbefehl", "Hold shortcut")) {
                HotkeyRecorderField(
                    hotkey: $appState.holdShortcut,
                    label: text("Halten-zum-Diktieren-Kurzbefehl", "Hold-to-dictate shortcut"),
                    language: appLanguage
                )
                .frame(width: 260)
            }
            .disabled(!appState.holdToDictateEnabled)

            if appState.holdToDictateEnabled, let advisory = appState.holdShortcutAdvisory {
                HotkeyAdvisoryBox(advisory: advisory)
            }

            Text(text(
                "Fn allein wird im aktuellen globalen Hotkey-Pfad nicht zuverlässig unterstützt.",
                "Fn by itself is not supported reliably in the current global hotkey path."
            ))
            .font(.footnote)
            .foregroundStyle(.secondary)
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

                Toggle(text("Debug-Modus aktivieren", "Enable debug mode"), isOn: $appState.debugModeEnabled)

                if appState.debugModeEnabled {
                    DisclosureGroup(
                        content: {
                            Text(appState.debugLogText.isEmpty ? text("Noch keine Debug-Ereignisse erfasst.", "No debug events captured yet.") : appState.debugLogText)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        },
                        label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(text("Aktuelle Debug-Logs", "Recent debug logs"))
                                Text(appState.debugLogText.isEmpty ? text("Debug-Modus ist aktiv. Neue Laufzeit- und Prozessereignisse erscheinen hier.", "Debug mode is enabled. New runtime and process events will appear here.") : appState.debugLogText.components(separatedBy: .newlines).suffix(3).joined(separator: "\n"))
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
                        Button(text("Debug-Log exportieren", "Export debug log")) {
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
    case dictation
    case shortcuts
    case ai
    case history
    case about
    case snippets
    case advanced

    var symbolName: String {
        switch self {
        case .general: return "gearshape"
        case .dictation: return "mic"
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
        case .dictation:
            return language.text("Diktat", "Dictation")
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

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(status.label)
                .foregroundStyle(status.color)
        }
        .padding(.vertical, 2)
    }
}
