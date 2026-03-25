import AppKit
import SwiftUI

@main
struct WisprLocalMacApp: App {
    @StateObject private var updaterController: SparkleUpdaterController
    @StateObject private var appState: MacAppState

    init() {
        let configuration = MacAppConfiguration.load()
        let updaterController = SparkleUpdaterController(configuration: configuration)
        let appState = MacAppState(configuration: configuration)
        appState.bindUpdater(updaterController)
        _updaterController = StateObject(wrappedValue: updaterController)
        _appState = StateObject(wrappedValue: appState)
    }

    var body: some Scene {
        MenuBarExtra(appState.menuBarTitle, systemImage: appState.menuBarIconName) {
            MenuBarContentView()
                .environmentObject(appState)
        }

        Window("WisprLocal Settings", id: "settings") {
            SettingsView()
                .environmentObject(appState)
        }
    }
}

struct MenuBarContentView: View {
    @EnvironmentObject private var appState: MacAppState
    @Environment(\.openWindow) private var openWindow
    @AppStorage("wispr.uiLanguage") private var uiLanguageRaw: String = InterfaceLanguage.german.rawValue
    @State private var didRunUpdateCheck = false

    private var uiLanguage: InterfaceLanguage {
        InterfaceLanguage(rawValue: uiLanguageRaw) ?? .german
    }

    private func text(_ german: String, _ english: String) -> String {
        uiLanguage == .german ? german : english
    }

    private var actionTitle: String {
        appState.recordingStatus == "Recording"
            ? text("Diktat stoppen", "Stop Dictation")
            : text("Diktat starten", "Start Dictating")
    }

    private var latestDictationText: String {
        appState.transcriptHistory.first?.text ?? appState.lastTranscript
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                StatusBadge(
                    text: appState.statusBadgeText,
                    color: appState.statusBadgeColor
                )
                Spacer()
            }

            Toggle(text("Streaming Insert", "Streaming insert"), isOn: $appState.streamingEnabled)

            Picker(text("Sprache", "Language"), selection: $appState.selectedLanguage) {
                ForEach(DictationLanguage.allCases) { language in
                    Text(language.displayName).tag(language)
                }
            }

            Divider()

            Button {
                appState.toggleTranscriptionFromMenuBar()
            } label: {
                MenuActionLabel(
                    title: actionTitle,
                    shortcut: appState.selectedHotkey.menuBarHint
                )
            }

            Button {
                copyToClipboard(latestDictationText)
            } label: {
                MenuActionLabel(
                    title: text("Letztes Diktat kopieren", "Copy last dictation"),
                    shortcut: ""
                )
            }
            .disabled(latestDictationText.isEmpty)

            Button {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "settings")
            } label: {
                MenuActionLabel(
                    title: text("Open Settings", "Open Settings"),
                    shortcut: "⌘,"
                )
            }

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Text(text("Beenden", "Quit"))
            }
        }
        .padding(12)
        .frame(width: 320)
        .task {
            guard !didRunUpdateCheck else { return }
            didRunUpdateCheck = true
            if appState.updaterConfigured {
                appState.checkForUpdates()
            }
        }
    }

    private func copyToClipboard(_ string: String) {
        guard !string.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
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
}

private struct MenuActionLabel: View {
    let title: String
    let shortcut: String

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
            Spacer(minLength: 12)
            if !shortcut.isEmpty {
                Text(shortcut)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct StatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.25))
            .foregroundColor(color)
            .cornerRadius(8)
    }
}
