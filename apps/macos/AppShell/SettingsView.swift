import AppKit
import Carbon
import SnippetCore
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: MacAppState
    @AppStorage("wispr.uiLanguage") private var uiLanguageRaw: String = AppLanguage.german.rawValue
    @State private var selectedTab: SettingsTab = .general
    @State private var diagnosticsExpanded = false
    @State private var newSnippetTrigger: String = ""
    @State private var newSnippetReplacement: String = ""
    @State private var searchText: String = ""

    private static let historyDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter
    }()

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: uiLanguageRaw) ?? .german
    }

    private var searchQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var isSearching: Bool {
        !searchQuery.isEmpty
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

    private var filteredSnippets: [SnippetRule] {
        guard isSearching else {
            return appState.snippetRules
        }
        return appState.snippetRules.filter {
            $0.trigger.lowercased().contains(searchQuery) ||
            $0.replacement.lowercased().contains(searchQuery)
        }
    }

    private func text(_ german: String, _ english: String) -> String {
        appLanguage.text(german, english)
    }

    private func matches(_ keywords: [String]) -> Bool {
        guard isSearching else { return true }
        return keywords.contains { $0.lowercased().contains(searchQuery) }
    }

    private func copyToClipboard(_ string: String) {
        guard !string.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }

    private var compactHistoryEntries: [TranscriptHistoryEntry] {
        if !isSearching {
            return Array(filteredHistory.prefix(12))
        }
        return filteredHistory
    }

    private var generalTabHasMatches: Bool {
        matches(["language", "sprache", "menüleiste", "menu bar", "shortcut hints", "zugriff", "permissions", "berechtigungen", "mikrofon", "accessibility", "bedienungshilfen"])
    }

    private var dictationTabHasMatches: Bool {
        matches(["sprache", "language", "qualität", "quality", "streaming", "clipboard", "zwischenablage", "insert", "delivery"])
    }

    private var shortcutsTabHasMatches: Bool {
        matches(["shortcut", "kurzbefehl", "hold", "dictation", "diktat"])
    }

    private var historyTabHasMatches: Bool {
        matches(["history", "verlauf", "transkript", "dictation", "diktat"]) || !filteredHistory.isEmpty
    }

    private var advancedTabHasMatches: Bool {
        matches(["snippet", "textbaustein", "replacement", "trigger", "diagnose", "diagnostics", "lizenz", "license", "capability", "audit"]) ||
        !filteredSnippets.isEmpty ||
        appState.diagnosticsText.lowercased().contains(searchQuery) ||
        appState.licenseStatusText.lowercased().contains(searchQuery) ||
        appState.capabilitySummary.lowercased().contains(searchQuery)
    }

    private var searchResultSectionCount: Int {
        [generalTabHasMatches, dictationTabHasMatches, shortcutsTabHasMatches, historyTabHasMatches, advancedTabHasMatches]
            .filter { $0 }
            .count
    }

    private var searchResultItemCount: Int {
        var count = 0
        if generalTabHasMatches { count += 1 }
        if dictationTabHasMatches { count += 1 }
        if shortcutsTabHasMatches { count += 1 }
        if historyTabHasMatches { count += compactHistoryEntries.count }
        if advancedTabHasMatches { count += max(filteredSnippets.count, 1) }
        return count
    }

    private var compressedDiagnosticsText: String {
        let lines = appState.diagnosticsText
            .split(separator: "\n")
            .map(String.init)
        let preview = lines.suffix(8).joined(separator: "\n")
        return preview.isEmpty ? appState.diagnosticsText : preview
    }

    var body: some View {
        Group {
            if isSearching {
                searchResultsView
            } else {
                TabView(selection: $selectedTab) {
                    generalPane
                        .tabItem { Label(text("Allgemein", "General"), systemImage: "gearshape") }
                        .tag(SettingsTab.general)

                    dictationPane
                        .tabItem { Label(text("Diktat", "Dictation"), systemImage: "mic") }
                        .tag(SettingsTab.dictation)

                    shortcutsPane
                        .tabItem { Label(text("Kurzbefehle", "Shortcuts"), systemImage: "command") }
                        .tag(SettingsTab.shortcuts)

                    historyPane
                        .tabItem { Label(text("Verlauf", "History"), systemImage: "clock.arrow.circlepath") }
                        .tag(SettingsTab.history)

                    advancedPane
                        .tabItem { Label(text("Erweitert", "Advanced"), systemImage: "wrench.and.screwdriver") }
                        .tag(SettingsTab.advanced)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 20)
        .environment(\.locale, appLanguage.locale)
        .frame(width: 760, height: 560)
        .background(.regularMaterial)
        .searchable(
            text: $searchText,
            placement: .toolbar,
            prompt: text("Einstellungen durchsuchen", "Search settings")
        )
    }

    private var searchResultsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if generalTabHasMatches {
                    SearchResultsGroup(
                        title: text("Allgemein", "General"),
                        systemImage: "gearshape",
                        showsDivider: dictationTabHasMatches || shortcutsTabHasMatches || historyTabHasMatches || advancedTabHasMatches
                    ) {
                        generalCards
                    }
                }

                if dictationTabHasMatches {
                    SearchResultsGroup(
                        title: text("Diktat", "Dictation"),
                        systemImage: "mic",
                        showsDivider: shortcutsTabHasMatches || historyTabHasMatches || advancedTabHasMatches
                    ) {
                        dictationCards
                    }
                }

                if shortcutsTabHasMatches {
                    SearchResultsGroup(
                        title: text("Kurzbefehle", "Shortcuts"),
                        systemImage: "command",
                        showsDivider: historyTabHasMatches || advancedTabHasMatches
                    ) {
                        shortcutsCards
                    }
                }

                if historyTabHasMatches {
                    SearchResultsGroup(
                        title: text("Verlauf", "History"),
                        systemImage: "clock.arrow.circlepath",
                        showsDivider: advancedTabHasMatches
                    ) {
                        historyCards
                    }
                }

                if advancedTabHasMatches {
                    SearchResultsGroup(
                        title: text("Erweitert", "Advanced"),
                        systemImage: "wrench.and.screwdriver",
                        showsDivider: false
                    ) {
                        advancedCards
                    }
                }

                if !generalTabHasMatches && !dictationTabHasMatches && !shortcutsTabHasMatches && !historyTabHasMatches && !advancedTabHasMatches {
                    Text(text("Keine passenden Einstellungen gefunden.", "No matching settings found."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 8)
        }
    }

    private var generalPane: some View {
        SettingsPane {
            generalCards
        }
    }

    @ViewBuilder
    private var generalCards: some View {
        if matches(["language", "sprache", "menüleiste", "menu bar", "shortcut hints"]) {
            SettingsCard(
                title: text("App & Menüleiste", "App & Menu Bar"),
                description: text(
                    "Sprache und Menüleistenverhalten der App.",
                    "Language and menu bar behavior for the app."
                )
            ) {
                SettingsRow(label: text("App-Sprache", "App Language")) {
                    Picker(text("App-Sprache", "App Language"), selection: $uiLanguageRaw) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.displayName).tag(language.rawValue)
                        }
                    }
                }

                Toggle(text("Shortcut-Hinweise im Menüleisten-Titel anzeigen", "Show shortcut hints in the menu bar title"), isOn: $appState.showMenuBarShortcutHints)

                Text(text(
                    "Diese Option blendet oberhalb nur Zusatztext wie `Start ⌥Space` oder `Stop ⇧⌘C` ein. Das Statussymbol selbst bleibt immer sichtbar.",
                    "This only adds helper text like `Start ⌥Space` or `Stop ⇧⌘C` to the menu bar title. The status icon itself always stays visible."
                ))
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }

        if matches(["mikrofon", "accessibility", "bedienungshilfen", "permissions", "berechtigungen"]) {
            SettingsCard(
                title: text("Zugriff & Status", "Access & Status"),
                description: text(
                    "Berechtigungen und Systemzugriff für Aufnahme und Einfügen.",
                    "Permissions and system access for recording and insertion."
                )
            ) {
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
                HStack {
                    Button(text("Mikrofon öffnen", "Open microphone settings")) {
                        appState.openMicrophoneSettings()
                    }
                    Button(text("Bedienungshilfen öffnen", "Open accessibility settings")) {
                        appState.openAccessibilitySettings()
                    }
                }
            }
        }
    }

    private var dictationPane: some View {
        SettingsPane {
            dictationCards
        }
    }

    @ViewBuilder
    private var dictationCards: some View {
        if matches(["sprache", "language", "qualität", "quality", "streaming", "clipboard", "zwischenablage", "insert"]) {
            SettingsCard(
                title: text("Erkennung", "Recognition"),
                description: text(
                    "Sprache und Qualitätsprofil für die lokale Transkription.",
                    "Language and quality profile for local transcription."
                )
            ) {
                SettingsRow(label: text("Diktatsprache", "Dictation language")) {
                    Picker(text("Diktatsprache", "Dictation language"), selection: $appState.selectedLanguage) {
                        ForEach(DictationLanguage.allCases) { language in
                            Text(language.localizedDisplayName(interfaceLanguageCode: appLanguage.rawValue)).tag(language)
                        }
                    }
                }

                SettingsRow(label: text("Erkennungsqualität", "Recognition quality")) {
                    Picker(text("Erkennungsqualität", "Recognition quality"), selection: $appState.performanceProfile) {
                        ForEach(DictationPerformance.allCases) { mode in
                            Text(mode.localizedDisplayName(interfaceLanguageCode: appLanguage.rawValue)).tag(mode)
                        }
                    }
                }
            }

            SettingsCard(
                title: text("Ablage", "Delivery"),
                description: text(
                    "Steuert, wie finale Diktate zugestellt oder zwischengespeichert werden.",
                    "Controls how final dictation is delivered or temporarily stored."
                )
            ) {
                SettingsRow(label: text("Finales Ergebnis", "Final result")) {
                    Picker(text("Finales Ergebnis", "Final result"), selection: $appState.finalResultDeliveryMode) {
                        Text(text("In Textfeld einfügen", "Insert into text field")).tag(FinalResultDeliveryMode.insert)
                        Text(text("Nur in Zwischenablage kopieren", "Copy to clipboard only")).tag(FinalResultDeliveryMode.clipboardOnly)
                    }
                }

                Toggle(text("Live-Text einfügen", "Insert live text"), isOn: $appState.streamingEnabled)
                    .disabled(appState.finalResultDeliveryMode == .clipboardOnly)

                Toggle(text("Wenn kein Textfeld aktiv ist: Ergebnis in Zwischenablage kopieren", "If no text field is active: copy result to clipboard"), isOn: $appState.clipboardFallbackWhenNoTarget)
                    .disabled(appState.finalResultDeliveryMode == .clipboardOnly)

                if appState.finalResultDeliveryMode == .clipboardOnly {
                    Text(text(
                        "Zwischenablage-only verwendet immer den Finalize-Pfad. Live-Insert wird dafür deaktiviert.",
                        "Clipboard-only always uses the finalize path. Live insert is disabled in this mode."
                    ))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var shortcutsPane: some View {
        SettingsPane {
            shortcutsCards
        }
    }

    @ViewBuilder
    private var shortcutsCards: some View {
        if matches(["shortcut", "kurzbefehl", "hold"]) {
            SettingsCard(
                title: text("Start / Stopp", "Start / Stop"),
                description: text(
                    "Globaler Shortcut zum Starten und Stoppen des Diktats.",
                    "Global shortcut for starting and stopping dictation."
                )
            ) {
                Toggle(text("Start/Stopp-Kurzbefehl aktiv", "Enable start/stop shortcut"), isOn: $appState.toggleShortcutEnabled)

                SettingsRow(label: text("Kurzbefehl", "Shortcut")) {
                    HotkeyRecorderField(
                        hotkey: $appState.selectedHotkey,
                        label: text("Diktier-Kurzbefehl", "Dictation shortcut"),
                        language: appLanguage
                    )
                }

                if let advisory = appState.hotkeyAdvisory {
                    HotkeyAdvisoryBox(advisory: advisory)
                }
            }

            SettingsCard(
                title: text("Halten zum Diktieren", "Hold to Dictate"),
                description: text(
                    "Separater Shortcut, der nur solange aktiv ist, wie du ihn gedrückt hältst.",
                    "Separate shortcut that stays active only while you keep it pressed."
                )
            ) {
                Toggle(text("Hold-to-dictate aktiv", "Enable hold-to-dictate"), isOn: $appState.holdToDictateEnabled)

                SettingsRow(label: text("Hold-Kurzbefehl", "Hold shortcut")) {
                    HotkeyRecorderField(
                        hotkey: $appState.holdShortcut,
                        label: text("Hold-to-dictate Kurzbefehl", "Hold-to-dictate shortcut"),
                        language: appLanguage
                    )
                }
                .disabled(!appState.holdToDictateEnabled)

                if appState.holdToDictateEnabled, let advisory = appState.holdShortcutAdvisory {
                    HotkeyAdvisoryBox(advisory: advisory)
                }

                Text(text(
                    "Fn allein wird im aktuellen globalen Hotkey-Pfad nicht zuverlässig unterstützt. Verwende eine Kombination mit Modifikatortasten.",
                    "Fn by itself is not supported reliably in the current global hotkey path. Use a shortcut with modifier keys."
                ))
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var historyPane: some View {
        SettingsPane {
            historyCards
        }
    }

    @ViewBuilder
    private var historyCards: some View {
        SettingsCard(
            title: text("Transkriptverlauf", "Transcript History"),
            description: text(
                "Finale Diktate bleiben hier zusätzlich gespeichert.",
                "Final dictations are retained here as an additional history."
            )
        ) {
            HStack {
                Button(text("Letztes Diktat kopieren", "Copy last dictation")) {
                    copyToClipboard(appState.latestDictationText)
                }
                .disabled(appState.latestDictationText.isEmpty)

                Button(text("Verlauf exportieren", "Export history")) {
                    appState.exportHistoryAsText()
                }

                Button(text("Verlauf leeren", "Clear history")) {
                    appState.clearHistory()
                }
            }

            if filteredHistory.isEmpty {
                Text(text("Keine Transkripte gefunden.", "No transcripts found."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Group {
                    if isSearching {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(compactHistoryEntries) { entry in
                                HistoryEntryCard(
                                    entry: entry,
                                    dateText: Self.historyDateFormatter.string(from: entry.createdAt),
                                    language: appLanguage,
                                    onCopy: { appState.copyHistoryEntry(entry) },
                                    onDelete: { appState.removeHistoryEntry(entry.id) }
                                )
                            }
                        }
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 12) {
                                ForEach(compactHistoryEntries) { entry in
                                    HistoryEntryCard(
                                        entry: entry,
                                        dateText: Self.historyDateFormatter.string(from: entry.createdAt),
                                        language: appLanguage,
                                        onCopy: { appState.copyHistoryEntry(entry) },
                                        onDelete: { appState.removeHistoryEntry(entry.id) }
                                    )
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(minHeight: 320, maxHeight: 360)
                    }
                }

                if !isSearching,
                   filteredHistory.count > compactHistoryEntries.count {
                    Text(text(
                        "Die Einstellungen zeigen zuerst die letzten \(compactHistoryEntries.count) Diktate. Über die Suche findest du ältere Einträge sofort wieder.",
                        "Settings show the latest \(compactHistoryEntries.count) dictations first. Use search to jump to older entries instantly."
                    ))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var advancedPane: some View {
        SettingsPane {
            advancedCards
        }
    }

    @ViewBuilder
    private var advancedCards: some View {
        if matches(["snippet", "textbaustein", "replacement", "trigger"]) {
            SettingsCard(
                title: text("Snippets", "Snippets"),
                description: text(
                    "Sprachbefehle für wiederkehrende Ersetzungen und Textbausteine.",
                    "Voice triggers for repeated replacements and snippets."
                )
            ) {
                HStack {
                    TextField(text("Trigger", "Trigger"), text: $newSnippetTrigger)
                    TextField(text("Ersetzung", "Replacement"), text: $newSnippetReplacement)
                    Button(text("Hinzufügen", "Add")) {
                        appState.addSnippet(trigger: newSnippetTrigger, replacement: newSnippetReplacement)
                        newSnippetTrigger = ""
                        newSnippetReplacement = ""
                    }
                }

                HStack {
                    Button(text("JSON importieren", "Import JSON")) {
                        appState.importSnippetsFromJSON()
                    }
                    Button(text("JSON exportieren", "Export JSON")) {
                        appState.exportSnippetsToJSON()
                    }
                }

                if filteredSnippets.isEmpty {
                    Text(text("Keine Snippets gespeichert.", "No snippets saved."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filteredSnippets) { rule in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(rule.trigger)
                                    .font(.subheadline.weight(.semibold))
                                Text(rule.replacement)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(text("Löschen", "Delete")) {
                                appState.removeSnippet(ruleID: rule.id)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }
        }

        if matches(["diagnose", "diagnostics", "lizenz", "license", "capability", "audit"]) {
            SettingsCard(
                title: text("Diagnose", "Diagnostics"),
                description: text(
                    "Technische Laufzeitinformationen für Analyse und Support.",
                    "Technical runtime information for analysis and support."
                )
            ) {
                Text(appState.capabilitySummary)
                    .font(.footnote)
                    .textSelection(.enabled)

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

                HStack {
                    Button(text("Diagnose kopieren", "Copy diagnostics")) {
                        copyToClipboard(compressedDiagnosticsText)
                    }
                    .disabled(compressedDiagnosticsText.isEmpty)

                    Button(text("Diagnose exportieren", "Export diagnostics")) {
                        appState.exportDiagnosticsReport()
                    }
                }
            }

            SettingsCard(
                title: text("Lizenz", "License"),
                description: text(
                    "Lizenzstatus und Aktivierung für zusätzliche Funktionen.",
                    "License status and activation for additional features."
                )
            ) {
                HStack {
                    TextField(text("Lizenzschlüssel", "License key"), text: $appState.licenseInput)
                    Button(text("Aktivieren", "Activate")) {
                        appState.activateLicense()
                    }
                    Button(text("Deaktivieren", "Deactivate")) {
                        appState.deactivateLicense()
                    }
                }
                Text(appState.licenseStatusText)
                    .foregroundStyle(appState.licensePresentationState.color)
                    .font(.footnote)
            }
        }
    }
}

private enum SettingsTab: Hashable {
    case general
    case dictation
    case shortcuts
    case history
    case advanced
}

private struct SettingsPane<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        Form {
            VStack(alignment: .leading, spacing: 14) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 10)
        }
    }
}

private struct SettingsCard<Content: View>: View {
    let title: String
    let description: String?
    @ViewBuilder let content: Content

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline.weight(.semibold))
                if let description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .groupBoxStyle(.automatic)
    }
}

private struct SettingsRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SearchResultsGroup<Content: View>: View {
    let title: String
    let systemImage: String
    let showsDivider: Bool
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 2)

            content

            if showsDivider {
                Divider()
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 10)
        .accessibilityElement(children: .contain)
    }
}

private struct HistoryEntryCard: View {
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

    private var accessibilityPreviewLabel: String {
        let preview = entry.text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(120)
        return "\(dateText), \(entry.languageCode), \(entry.mode), \(preview)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
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
                Button(text("Löschen", "Delete")) {
                    onDelete()
                }
                .buttonStyle(.borderless)
            }

            Text(entry.text)
                .font(.body)
                .lineLimit(3)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel(accessibilityPreviewLabel)

            if requiresExpansion {
                DisclosureGroup(isExpanded: $isExpanded) {
                    Text(entry.text)
                        .font(.body)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                } label: {
                    Text(text("Vollständiges Diktat anzeigen", "Show full transcript"))
                        .font(.footnote)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(.separator.opacity(0.14), lineWidth: 1)
        )
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
            RoundedRectangle(cornerRadius: 10)
                .fill(accentColor.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(accentColor.opacity(0.35), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
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
