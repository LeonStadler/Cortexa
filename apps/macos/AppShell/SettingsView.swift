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

    private var historyHasMatches: Bool {
        matches(["history", "verlauf", "transkript", "dictation", "diktat"]) || !filteredHistory.isEmpty
    }

    private var advancedHasMatches: Bool {
        matches(["snippet", "textbaustein", "replacement", "trigger", "diagnose", "diagnostics", "lizenz", "license", "capability", "audit"]) ||
            !filteredSnippets.isEmpty ||
            appState.diagnosticsText.lowercased().contains(searchQuery) ||
            appState.licenseStatusText.lowercased().contains(searchQuery) ||
            appState.capabilitySummary.lowercased().contains(searchQuery)
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
                List(selection: $selectedTab) {
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
                Text(isSearching ? text("Suchergebnisse", "Search Results") : selectedTab.title(language: appLanguage))
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
        switch selectedTab {
        case .general:
            generalForm
        case .dictation:
            dictationForm
        case .shortcuts:
            shortcutsForm
        case .history:
            historyForm
        case .advanced:
            advancedForm
        }
    }

    private var dictationForm: some View {
        Form {
            Section(text("Erkennung", "Recognition")) {
                dictationRecognitionContent
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

    private var advancedForm: some View {
        Form {
            Section(text("Snippets", "Snippets")) {
                snippetsContent
            }
            Section(text("Diagnose", "Diagnostics")) {
                diagnosticsContent
            }
            Section(text("Lizenz", "License")) {
                licenseContent
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

            if historyHasMatches {
                Section(text("Verlauf", "History")) {
                    historyActionContent
                    historyEntriesContent
                }
            }

            if advancedHasMatches {
                Section(text("Erweitert", "Advanced")) {
                    snippetsContent
                    diagnosticsContent
                    licenseContent
                }
            }

            if !generalHasMatches && !dictationHasMatches && !shortcutsHasMatches && !historyHasMatches && !advancedHasMatches {
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
        if matches(["sprache", "language", "qualität", "quality", "streaming", "clipboard", "zwischenablage", "insert"]) {
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
        if matches(["sprache", "language", "qualität", "quality", "streaming", "clipboard", "zwischenablage", "insert"]) {
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
            } else if !appState.dictationCapability.allowsDirectInsertion {
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

private enum SettingsTab: Hashable, CaseIterable {
    case general
    case dictation
    case shortcuts
    case history
    case advanced

    var symbolName: String {
        switch self {
        case .general: return "gearshape"
        case .dictation: return "mic"
        case .shortcuts: return "command"
        case .history: return "clock.arrow.circlepath"
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
        case .history:
            return language.text("Verlauf", "History")
        case .advanced:
            return language.text("Erweitert", "Advanced")
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
