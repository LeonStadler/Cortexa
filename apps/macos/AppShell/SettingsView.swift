import AppKit
import Carbon
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: MacAppState
    @AppStorage("wispr.uiLanguage") private var uiLanguageRaw: String = InterfaceLanguage.german.rawValue
    @State private var selectedTab: SettingsTab = .general
    @State private var diagnosticsExpanded = false
    @State private var newSnippetTrigger: String = ""
    @State private var newSnippetReplacement: String = ""

    private static let historyDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter
    }()

    private var uiLanguage: InterfaceLanguage {
        InterfaceLanguage(rawValue: uiLanguageRaw) ?? .german
    }

    private var uiLocale: Locale {
        uiLanguage.locale
    }

    private var actionTitle: String {
        appState.recordingStatus == "Recording"
            ? text("Diktat stoppen", "Stop Dictation")
            : text("Diktat starten", "Start Dictation")
    }

    private func text(_ german: String, _ english: String) -> String {
        uiLanguage == .german ? german : english
    }

    private func copyToClipboard(_ string: String) {
        guard !string.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }

    private var compressedDiagnosticsText: String {
        let lines = appState.diagnosticsText
            .split(separator: "\n")
            .map(String.init)
        let preview = lines.suffix(8).joined(separator: "\n")
        return preview.isEmpty ? appState.diagnosticsText : preview
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Form {
                Section {
                    Picker(text("App-Sprache", "App Language"), selection: $uiLanguageRaw) {
                        ForEach(InterfaceLanguage.allCases) { language in
                            Text(language.displayName).tag(language.rawValue)
                        }
                    }

                    Text(text(
                        "Die Einstellungen und sichtbaren Bedienelemente dieser macOS-App verwenden diese Sprache.",
                        "Settings and visible controls in this macOS app use this language."
                    ))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                    Toggle(text("Hinweise in der Menüleiste anzeigen", "Show menu bar hints"), isOn: $appState.showMenuBarShortcutHints)

                    Text(appState.showMenuBarShortcutHints
                         ? text("Die Menüleiste zeigt Start-/Stop-Hinweise direkt neben dem Icon an.", "The menu bar shows start/stop hints next to the icon.")
                         : text("Die Menüleiste bleibt kompakt und zeigt nur Icon und kurze Statusanzeige.", "The menu bar stays compact and shows only the icon and a short status badge."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(text("Updates", "Updates"))
                            Text(appState.updaterStatusText)
                                .font(.footnote)
                                .foregroundStyle(appState.updaterConfigured ? Color.green : Color.secondary)
                            if !appState.updaterFeedURLText.isEmpty {
                                Text(appState.updaterFeedURLText)
                                    .font(.footnote)
                                    .textSelection(.enabled)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Button(text("Nach Updates suchen", "Check for updates")) {
                            appState.checkForUpdates()
                        }
                        .disabled(!appState.updaterConfigured)
                    }
                }
            }
            .tabItem {
                Label(text("Allgemein", "General"), systemImage: "gearshape")
            }
            .tag(SettingsTab.general)

            Form {
                Section {
                    Toggle(text("Streaming Insert", "Streaming insert"), isOn: $appState.streamingEnabled)

                    Picker(text("Diktatsprache", "Dictation language"), selection: $appState.selectedLanguage) {
                        ForEach(DictationLanguage.allCases) { language in
                            Text(language.displayName).tag(language)
                        }
                    }

                    Picker(text("Performance", "Performance"), selection: $appState.performanceProfile) {
                        ForEach(DictationPerformance.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }

                    HStack(alignment: .center, spacing: 12) {
                        Text(text("Tastenkombination", "Keyboard shortcut"))
                        HotkeyRecorderField(hotkey: $appState.selectedHotkey)
                        Spacer()
                    }

                    if let advisory = appState.hotkeyAdvisory {
                        HotkeyAdvisoryBox(advisory: advisory)
                    }

                    Text(text("Aktiver Start-Shortcut", "Active start shortcut") + ": \(appState.hotkeyDisplayText)")
                        .font(.footnote)

                    Text(text("Notfall-Stopp", "Emergency stop") + ": \(appState.emergencyShortcutDisplayText)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Text(text(
                        "Auto ist nur eine Best-Effort-Erkennung. Für stabilere Ergebnisse ist eine feste Sprache oft besser.",
                        "Auto is best-effort language detection. A fixed language often gives more stable results."
                    ))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                    Button(actionTitle) {
                        appState.toggleTranscriptionFromUI()
                    }
                }
            }
            .tabItem {
                Label(text("Diktat", "Dictation"), systemImage: "mic")
            }
            .tag(SettingsTab.dictation)

            Form {
                Section {
                    HStack {
                        Button(text("Letztes Diktat kopieren", "Copy last dictation")) {
                            copyToClipboard(appState.transcriptHistory.first?.text ?? appState.lastTranscript)
                        }
                        .disabled((appState.transcriptHistory.first?.text ?? appState.lastTranscript).isEmpty)

                        Button(text("History exportieren", "Export history")) {
                            appState.exportHistoryAsText()
                        }

                        Button(text("History leeren", "Clear history")) {
                            appState.clearHistory()
                        }
                    }

                    if appState.transcriptHistory.isEmpty {
                        Text(text("Noch keine finalen Transkripte vorhanden.", "No final transcripts yet."))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(appState.transcriptHistory) { entry in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(Self.historyDateFormatter.string(from: entry.createdAt))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("[\(entry.mode) • \(entry.languageCode)]")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Button(text("Kopieren", "Copy")) {
                                        appState.copyHistoryEntry(entry)
                                    }
                                    .buttonStyle(.borderless)
                                    Button(text("Löschen", "Delete")) {
                                        appState.removeHistoryEntry(entry.id)
                                    }
                                    .buttonStyle(.borderless)
                                }
                                Text(entry.text)
                                    .textSelection(.enabled)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .tabItem {
                Label(text("History", "History"), systemImage: "clock.arrow.circlepath")
            }
            .tag(SettingsTab.history)

            Form {
                Section {
                    HStack {
                        TextField(text("Trigger", "Trigger"), text: $newSnippetTrigger)
                        TextField(text("Replacement", "Replacement"), text: $newSnippetReplacement)
                        Button(text("Hinzufügen", "Add")) {
                            appState.addSnippet(trigger: newSnippetTrigger, replacement: newSnippetReplacement)
                            newSnippetTrigger = ""
                            newSnippetReplacement = ""
                        }
                    }

                    HStack {
                        Button(text("Import JSON", "Import JSON")) {
                            appState.importSnippetsFromJSON()
                        }
                        Button(text("Export JSON", "Export JSON")) {
                            appState.exportSnippetsToJSON()
                        }
                    }

                    if appState.snippetRules.isEmpty {
                        Text(text("Keine Snippets gespeichert.", "No snippets saved."))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(appState.snippetRules) { rule in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(rule.trigger)
                                        .font(.headline)
                                    Text(rule.replacement)
                                        .font(.subheadline)
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
            .tabItem {
                Label(text("Snippets", "Snippets"), systemImage: "text.badge.plus")
            }
            .tag(SettingsTab.snippets)

            Form {
                Section {
                    PermissionStatusRow(
                        title: text("Mikrofon", "Microphone"),
                        status: appState.microphonePermissionStatus,
                        detail: text(
                            "Ohne Mikrofonzugriff kann kein Audiosignal aufgenommen werden.",
                            "No audio can be captured without microphone access."
                        )
                    )
                    PermissionStatusRow(
                        title: text("Bedienungshilfen", "Accessibility"),
                        status: appState.accessibilityPermissionStatus,
                        detail: text(
                            "Erlaubt Einfügen und Steuerung an der aktiven Cursorposition.",
                            "Allows insertion and control at the active cursor position."
                        )
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
            .tabItem {
                Label(text("Berechtigungen", "Permissions"), systemImage: "hand.raised")
            }
            .tag(SettingsTab.permissions)

            Form {
                Section {
                    Text(appState.capabilitySummary)
                        .font(.footnote)
                        .textSelection(.enabled)

                    Button(text("Diagnose exportieren", "Export diagnostics")) {
                        appState.exportDiagnosticsReport()
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
                                Text(text("Diagnose", "Diagnostics"))
                                Text(compressedDiagnosticsText)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                        }
                    )

                    Button(text("Diagnose kopieren", "Copy diagnostics")) {
                        copyToClipboard(appState.diagnosticsText)
                    }
                    .disabled(appState.diagnosticsText.isEmpty)

                    Text(text(
                        "Die komprimierte Vorschau zeigt nur die letzten Diagnosezeilen. Für den Volltext aufklappen.",
                        "The compact preview shows only the latest diagnostic lines. Expand to view the full text."
                    ))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
            .tabItem {
                Label(text("Diagnose", "Diagnostics"), systemImage: "doc.text.magnifyingglass")
            }
            .tag(SettingsTab.diagnostics)

            Form {
                Section {
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
            .tabItem {
                Label(text("Lizenz", "License"), systemImage: "key")
            }
            .tag(SettingsTab.license)
        }
        .environment(\.locale, uiLocale)
        .tabViewStyle(.automatic)
        .frame(width: 980, height: 760)
        .padding()
    }
}

private enum InterfaceLanguage: String, CaseIterable, Identifiable {
    case german = "de"
    case english = "en"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .german:
            return "Deutsch"
        case .english:
            return "English"
        }
    }

    var locale: Locale {
        switch self {
        case .german:
            return Locale(identifier: "de_DE")
        case .english:
            return Locale(identifier: "en_US")
        }
    }
}

private enum SettingsTab: Hashable {
    case general
    case dictation
    case history
    case snippets
    case permissions
    case diagnostics
    case license
}

private struct HotkeyRecorderField: NSViewRepresentable {
    @Binding var hotkey: HotkeyBinding

    func makeNSView(context: Context) -> HotkeyRecorderButton {
        let view = HotkeyRecorderButton()
        view.onChange = { newHotkey in
            hotkey = newHotkey
        }
        return view
    }

    func updateNSView(_ nsView: HotkeyRecorderButton, context: Context) {
        nsView.displayedHotkey = hotkey
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
    }
}

private final class HotkeyRecorderButton: NSButton {
    var onChange: ((HotkeyBinding) -> Void)?
    var displayedHotkey: HotkeyBinding = .optionSpace {
        didSet { updateTitle() }
    }

    private var isRecording = false {
        didSet { updateTitle() }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        bezelStyle = .rounded
        setButtonType(.momentaryPushIn)
        target = self
        action = #selector(beginRecording)
        updateTitle()
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
            updateTitle()
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
        updateTitle()
        return true
    }

    private func updateTitle() {
        title = isRecording ? "Shortcut aufnehmen..." : displayedHotkey.displayName
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
