import AppKit
import SwiftUI

/// Smoke-/Automatisierungspfad: Einstellungen ohne System-Events-Tastatur öffnen (kein Bedienungshilfen-Zugriff für Terminal nötig).
private enum WisprSmokeLaunch {
    static var shouldOpenSettingsAfterLaunch: Bool {
        if ProcessInfo.processInfo.environment["WISPR_SMOKE_OPEN_SETTINGS"] == "1" {
            return true
        }
        return ProcessInfo.processInfo.arguments.contains("--wispr-smoke-open-settings")
    }
}

/// Hält den einmaligen `didFinishLaunching`-Observer, ohne `var`-Capture in einer `@Sendable`-Closure.
private final class SmokeOpenSettingsLaunchObserver {
    private var notificationToken: NSObjectProtocol?
    private static var retained: SmokeOpenSettingsLaunchObserver?

    static func start(appState: MacAppState) {
        retained = SmokeOpenSettingsLaunchObserver(appState: appState)
    }

    private init(appState: MacAppState) {
        notificationToken = NotificationCenter.default.addObserver(
            forName: NSApplication.didFinishLaunchingNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else {
                Self.retained = nil
                return
            }
            if let token = notificationToken {
                NotificationCenter.default.removeObserver(token)
                notificationToken = nil
            }
            Self.retained = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                NSApplication.shared.activate(ignoringOtherApps: true)
                appState.openSettingsWindow()
            }
        }
    }
}

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

        if WisprSmokeLaunch.shouldOpenSettingsAfterLaunch {
            SmokeOpenSettingsLaunchObserver.start(appState: appState)
        }
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
