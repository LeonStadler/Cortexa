import AppKit
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
        MenuBarExtra(appState.menuBarTitle, systemImage: appState.menuBarIconName) {
            MenuBarContentView()
                .environmentObject(appState)
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

    private var showsUpdateBadge: Bool {
        let status = appState.updaterStatusText.lowercased()
        return (status.contains("update") || status.contains("aktualisierung")) &&
            (status.contains("verfügbar") || status.contains("available"))
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

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("WisprLocal")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    if showsUpdateBadge {
                        StatusPill(text: text("Update", "Update"), color: .blue, emphasis: .secondary)
                    }
                    if showsStatusHeader {
                        StatusPill(text: statusLine, color: statusColor, emphasis: .primary)
                    }
                }
                .accessibilityElement(children: .combine)
                if let secondaryLine {
                    Text(secondaryLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Button {
                appState.toggleTranscriptionFromMenuBar()
            } label: {
                PrimaryMenuActionLabel(
                    title: primaryActionTitle,
                    shortcutGlyph: appState.toggleShortcutEnabled ? appState.selectedHotkey.menuBarHint : nil,
                    shortcutText: appState.toggleShortcutEnabled ? appState.selectedHotkey.displayName : nil
                )
            }
            .buttonStyle(.plain)
            .padding(.bottom, 2)

            if !appState.hasPermissionProblems {
                MenuCard(emphasis: .subtle) {
                    Toggle(text("Live-Text einfügen", "Insert live text"), isOn: $appState.streamingEnabled)
                        .disabled(appState.finalResultDeliveryMode == .clipboardOnly)

                    Picker(text("Sprache", "Language"), selection: $appState.selectedLanguage) {
                        ForEach(DictationLanguage.allCases) { language in
                            Text(language.localizedDisplayName(interfaceLanguageCode: appLanguage.rawValue)).tag(language)
                        }
                    }
                    .labelsHidden()
                    .accessibilityLabel(text("Diktatsprache", "Dictation language"))
                }
            }

            if appState.hasPermissionProblems {
                MenuCard(emphasis: .strong) {
                    Text(text("Fehlende Berechtigungen", "Missing permissions"))
                        .font(.subheadline.weight(.medium))
                    Text(appState.permissionSummary)
                        .font(.footnote)
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
            }

            if !appState.latestDictationText.isEmpty {
                MenuCard(emphasis: .strong) {
                    Text(text("Letztes Diktat", "Last dictation"))
                        .font(.subheadline.weight(.medium))
                    Text(latestDictationPreview)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityLabel(appState.latestDictationText)
                    Button(text("Letztes Diktat kopieren", "Copy last dictation")) {
                        copyToClipboard(appState.latestDictationText)
                    }
                }
            }

            Divider()
                .padding(.top, 2)
                .padding(.bottom, 2)

            VStack(alignment: .leading, spacing: 4) {
                Button {
                    appState.openSettingsWindow()
                } label: {
                    MenuActionLabel(
                        title: text("Einstellungen…", "Settings…"),
                        shortcutGlyph: nil,
                        shortcutText: nil
                    )
                }
                .buttonStyle(.plain)
                .controlSize(.small)

                Button(text("Nach Updates suchen", "Check for updates")) {
                    appState.checkForUpdates()
                }
                .disabled(!appState.updaterConfigured)
                .buttonStyle(.plain)
                .controlSize(.small)

                Button(text("Beenden", "Quit")) {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .controlSize(.small)
            }
        }
        .padding(12)
        .frame(width: 324)
        .background(.regularMaterial)
    }

    private func copyToClipboard(_ string: String) {
        guard !string.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }
}

private struct StatusPill: View {
    enum Emphasis {
        case primary
        case secondary
    }

    let text: String
    let color: Color
    let emphasis: Emphasis

    var body: some View {
        Text(text)
            .font((emphasis == .primary ? Font.caption2.weight(.semibold) : Font.caption2.weight(.medium)))
            .padding(.horizontal, emphasis == .primary ? 8 : 7)
            .padding(.vertical, 3)
            .background(
                Capsule(style: .continuous)
                    .fill(color.opacity(emphasis == .primary ? 0.1 : 0.06))
            )
            .foregroundStyle(color)
    }
}

private enum MenuCardEmphasis {
    case subtle
    case strong
}

private struct MenuCard<Content: View>: View {
    let emphasis: MenuCardEmphasis
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            content
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(emphasis == .strong ? .thinMaterial : .ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(.separator.opacity(emphasis == .strong ? 0.12 : 0.05), lineWidth: 1)
        )
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
