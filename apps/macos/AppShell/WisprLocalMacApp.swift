import AppKit
import AIProcessingCore
import SwiftUI

@main
struct WisprLocalMacApp: App {
    @StateObject private var updaterController: SparkleUpdaterController
    @StateObject private var appState: MacAppState
    private let settingsWindowPresenter: SettingsWindowPresenter

    init() {
        let configuration = MacAppConfiguration.load()
        let updaterController = SparkleUpdaterController(configuration: configuration)
        let appState = MacAppState(configuration: configuration)
        let settingsWindowPresenter = SettingsWindowPresenter(appState: appState)
        appState.bindUpdater(updaterController)
        appState.bindOpenSettingsHandler {
            settingsWindowPresenter.show()
        }
        _updaterController = StateObject(wrappedValue: updaterController)
        _appState = StateObject(wrappedValue: appState)
        self.settingsWindowPresenter = settingsWindowPresenter
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
                .environmentObject(appState)
                .environmentObject(updaterController)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: appState.menuBarIconName)
                if !appState.menuBarTitle.isEmpty {
                    Text(appState.menuBarTitle)
                        .lineLimit(1)
                }
            }
        }
    }
}

private final class SettingsWindowPresenter {
    private let appState: MacAppState
    private weak var window: NSWindow?

    init(appState: MacAppState) {
        self.appState = appState
    }

    func show() {
        let window = existingWindow ?? makeWindow()
        NSApplication.shared.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private var existingWindow: NSWindow? {
        guard let window, !window.isReleasedWhenClosed else {
            return nil
        }
        return window
    }

    private func makeWindow() -> NSWindow {
        let hostingController = NSHostingController(rootView: SettingsView().environmentObject(appState))
        let window = NSWindow(contentViewController: hostingController)
        window.title = "WisprLocal"
        window.toolbarStyle = .preference
        window.titleVisibility = .visible
        window.titlebarAppearsTransparent = false
        window.styleMask = [.titled, .closable, .resizable]
        window.setContentSize(NSSize(width: 980, height: 640))
        window.contentMinSize = NSSize(width: 940, height: 620)
        window.contentMaxSize = NSSize(width: 1_180, height: 1_080)
        window.center()
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("WisprLocalSettingsWindow")
        self.window = window
        return window
    }
}

struct MenuBarContentView: View {
    @EnvironmentObject private var appState: MacAppState
    @EnvironmentObject private var updaterController: SparkleUpdaterController
    @AppStorage("wispr.uiLanguage") private var uiLanguageRaw: String = AppLanguage.german.rawValue

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: uiLanguageRaw) ?? .german
    }

    private func text(_ german: String, _ english: String) -> String {
        appLanguage.text(german, english)
    }

    private var latestDictationPreview: String {
        let normalized = appState.latestDictationText
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count > 140 else {
            return normalized
        }
        return "\(normalized.prefix(140))…"
    }

    private var showsUpdateMenuItem: Bool {
        updaterController.state.allowsManualCheck
    }

    private var showsStatusHeader: Bool {
        appState.isSessionActive || appState.hasPermissionProblems || appState.recordingStatus == "Error"
    }

    private var primaryActionTitle: String {
        appState.isSessionActive
            ? text("Diktat stoppen", "Stop Dictation")
            : text("Diktat starten", "Start Dictation")
    }

    private var insertionModeLabel: String {
        if appState.finalResultDeliveryMode == .clipboardOnly {
            return text("Zwischenablage", "Clipboard")
        }
        return appState.streamingEnabled ? text("Live", "Live") : text("Am Ende einfügen", "Insert on Stop")
    }

    private var statusLine: String {
        switch appState.recordingStatus {
        case "Recording":
            return text("Hört zu…", "Listening…")
        case "Error":
            return text("Aufmerksamkeit erforderlich", "Needs attention")
        case "Idle":
            switch appState.dictationCapability {
            case .fullSystemInsertion:
                return text("Bereit", "Ready")
            case .limitedTranscription:
                return text("Eingeschränkt", "Limited")
            case .unavailable:
                return text("Zugriff erforderlich", "Needs access")
            }
        default:
            return text("Aktiv", "Active")
        }
    }

    private var statusColor: Color {
        switch appState.recordingStatus {
        case "Recording":
            return .red
        case "Error":
            return .orange
        default:
            return appState.hasPermissionProblems ? .yellow : .green
        }
    }

    private var secondaryLine: String? {
        if appState.isSessionActive {
            return "\(appState.selectedLanguage.localizedDisplayName(interfaceLanguageCode: appLanguage.rawValue)) • \(insertionModeLabel)"
        }
        if appState.recordingStatus == "Error" {
            return appState.statusHintText
        }
        if appState.hasPermissionProblems {
            return appState.permissionSummary
        }
        return nil
    }

    @ViewBuilder
    private var statusHeader: some View {
        if showsStatusHeader {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)

                    Text(statusLine)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                }

                if let secondaryLine {
                    Text(secondaryLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, 2)
            .padding(.bottom, 2)
        }
    }

    @ViewBuilder
    private var startDictationButton: some View {
        if appState.showMenuBarShortcutHints,
           let keyEquivalent = appState.selectedHotkey.swiftUIKeyEquivalent {
            Button {
                appState.toggleTranscriptionFromMenuBar()
            } label: {
                PrimaryMenuActionLabel(
                    title: primaryActionTitle,
                    shortcutGlyph: nil,
                    shortcutText: appState.selectedHotkey.displayName
                )
            }
            .keyboardShortcut(keyEquivalent, modifiers: appState.selectedHotkey.swiftUIEventModifiers)
        } else {
            Button {
                appState.toggleTranscriptionFromMenuBar()
            } label: {
                PrimaryMenuActionLabel(
                    title: primaryActionTitle,
                    shortcutGlyph: nil,
                    shortcutText: nil
                )
            }
        }
    }

    @ViewBuilder
    private var copyLastDictationButton: some View {
        if appState.showMenuBarShortcutHints {
            Button {
                copyToClipboard(appState.latestDictationText)
            } label: {
                MenuActionLabel(
                    title: text("Letztes Diktat kopieren", "Copy last dictation"),
                    shortcutGlyph: nil,
                    shortcutText: "Command + Shift + C"
                )
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])
        } else {
            Button {
                copyToClipboard(appState.latestDictationText)
            } label: {
                MenuActionLabel(
                    title: text("Letztes Diktat kopieren", "Copy last dictation"),
                    shortcutGlyph: nil,
                    shortcutText: nil
                )
            }
        }
    }

    @ViewBuilder
    private var openSettingsButton: some View {
        if appState.showMenuBarShortcutHints {
            Button {
                appState.openSettingsWindow()
            } label: {
                MenuActionLabel(
                    title: text("Einstellungen…", "Settings…"),
                    shortcutGlyph: nil,
                    shortcutText: "Command + ,"
                )
            }
            .keyboardShortcut(",", modifiers: [.command])
        } else {
            Button {
                appState.openSettingsWindow()
            } label: {
                MenuActionLabel(
                    title: text("Einstellungen…", "Settings…"),
                    shortcutGlyph: nil,
                    shortcutText: nil
                )
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            startDictationButton

            statusHeader

            if showsStatusHeader {
                Divider()
            }

            Toggle(text("Live-Text einfügen", "Insert live text"), isOn: $appState.streamingEnabled)
                .disabled(appState.finalResultDeliveryMode == .clipboardOnly)

            Picker(text("Sprache", "Language"), selection: $appState.selectedLanguage) {
                ForEach(DictationLanguage.allCases) { language in
                    Text(language.localizedDisplayName(interfaceLanguageCode: appLanguage.rawValue)).tag(language)
                }
            }

            Picker(text("Übersetzung", "Translation"), selection: $appState.translationOutputMode) {
                ForEach(TranslationOutputMode.allCases) { mode in
                    Text(mode.localizedDisplayName(interfaceLanguageCode: appLanguage.rawValue)).tag(mode)
                }
            }

            Divider()

            Toggle(text("AI-Verarbeitung", "AI processing"), isOn: $appState.aiProcessingEnabled)
                .disabled(appState.availableQuickSettingsAIModels.isEmpty)

            if appState.aiProcessingEnabled {
                Picker(text("AI-Modell", "AI model"), selection: Binding(
                    get: { appState.selectedAIModelID ?? "" },
                    set: { appState.selectedAIModelID = $0.isEmpty ? nil : $0 }
                )) {
                    if appState.availableQuickSettingsAIModels.isEmpty {
                        Text(text("Keine Modelle", "No models")).tag("")
                    } else {
                        ForEach(appState.availableQuickSettingsAIModels) { model in
                            Text(model.displayName).tag(model.id)
                        }
                    }
                }
                .disabled(appState.availableQuickSettingsAIModels.isEmpty)

                Toggle(text("Bei Live-Einfügen", "For live insertion"), isOn: $appState.aiProcessingApplyDuringLiveInsertion)
                    .disabled(!appState.streamingEnabled || appState.availableQuickSettingsAIModels.isEmpty)

                Toggle(text("Beim finalen Ergebnis", "For final result"), isOn: $appState.aiProcessingApplyToFinalResult)
                    .disabled(appState.availableQuickSettingsAIModels.isEmpty)

                Picker(text("Stil", "Style"), selection: $appState.aiWritingStyle) {
                    ForEach(AIWritingStyle.allCases) { style in
                        Text(style.localizedDisplayName(interfaceLanguageCode: appLanguage.rawValue)).tag(style)
                    }
                }
                .disabled(appState.availableQuickSettingsAIModels.isEmpty)

                Picker(text("Anrede", "Salutation"), selection: $appState.aiSalutation) {
                    ForEach(AISalutation.allCases) { salutation in
                        Text(salutation.localizedDisplayName(interfaceLanguageCode: appLanguage.rawValue)).tag(salutation)
                    }
                }
                .disabled(appState.availableQuickSettingsAIModels.isEmpty)
            }

            if appState.hasPermissionProblems {
                Divider()
                Text(text("Berechtigungen", "Permissions"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if appState.microphonePermissionStatus != .granted {
                    Button(text("Mikrofonzugriff öffnen", "Open microphone access")) {
                        appState.openMicrophoneSettings()
                    }
                }
                if appState.accessibilityPermissionStatus != .granted {
                    Button(text("Bedienungshilfen öffnen", "Open accessibility access")) {
                        appState.openAccessibilitySettings()
                    }
                }
            }

            if !appState.latestDictationText.isEmpty {
                Divider()
                copyLastDictationButton
                Button(text("Verlauf", "History")) {
                    appState.openHistorySettingsWindow()
                }
            }

            Divider()

            openSettingsButton

            if showsUpdateMenuItem {
                Button(text("Nach Updates suchen", "Check for updates")) {
                    appState.checkForUpdates()
                }
                .buttonStyle(.borderless)
            }

            Divider()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                MenuActionLabel(
                    title: text("Beenden", "Quit"),
                    shortcutGlyph: appState.showMenuBarShortcutHints ? "⌘Q" : nil,
                    shortcutText: appState.showMenuBarShortcutHints ? "Command + Q" : nil
                )
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(width: 300)
        .controlSize(.small)
    }

    private func copyToClipboard(_ string: String) {
        guard !string.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }
}

private struct MenuActionLabel: View {
    let title: String
    let shortcutGlyph: String?
    let shortcutText: String?

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
            Spacer(minLength: 12)
            if let shortcutGlyph, !shortcutGlyph.isEmpty {
                Text(shortcutGlyph)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(shortcutText.map { "\(title), \($0)" } ?? title)
    }
}

private struct PrimaryMenuActionLabel: View {
    let title: String
    let shortcutGlyph: String?
    let shortcutText: String?

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.body.weight(.semibold))
            Spacer(minLength: 12)
            if let shortcutGlyph, !shortcutGlyph.isEmpty {
                Text(shortcutGlyph)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.separator.opacity(0.08), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(shortcutText.map { "\(title), \($0)" } ?? title)
    }
}
