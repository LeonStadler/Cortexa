import AppKit
import SwiftUI

/// Smoke-/Automatisierungspfad: Einstellungen ohne System-Events-Tastatur öffnen (kein Bedienungshilfen-Zugriff für Terminal nötig).
private enum WisprSmokeLaunch {
    static var shouldOpenSettingsAfterLaunch: Bool {
        return ProcessInfo.processInfo.arguments.contains("--wispr-smoke-open-settings")
    }
}

/// Erste sichtbare Oberfläche für Release-/DMG-Starts, damit eine reine Menüleisten-App nicht wie ein No-op wirkt.
private enum FirstVisibleLaunch {
    private static let didPresentKey = "cortexa.launch.didPresentInitialWindow"

    static func shouldPresent(using defaults: UserDefaults = .standard) -> Bool {
        !defaults.bool(forKey: didPresentKey)
    }

    static func markPresented(using defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: didPresentKey)
    }
}

/// Beendet frische Starts, wenn bereits eine Instanz mit derselben Bundle-ID läuft (z. B. direkter Binary-Start + `open`/AppleScript).
private enum SingleInstanceGuard {
    static func exitIfAnotherInstanceIsRunning() {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else { return }
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let otherInstances = NSRunningApplication.runningApplications(
            withBundleIdentifier: bundleIdentifier
        )
        .filter { $0.processIdentifier != currentPID }
        guard let existing = otherInstances.first else { return }
        if #available(macOS 14.0, *) {
            existing.activate()
        } else {
            existing.activate(options: [.activateIgnoringOtherApps])
        }
        exit(0)
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
    private let onboardingWindowPresenter: OnboardingWindowPresenter

    init() {
        SingleInstanceGuard.exitIfAnotherInstanceIsRunning()

        let configuration = MacAppConfiguration.load()
        let updaterController = SparkleUpdaterController(configuration: configuration)
        let appState = MacAppState(configuration: configuration)
        let settingsWindowPresenter = SettingsWindowPresenter(appState: appState)
        let onboardingWindowPresenter = OnboardingWindowPresenter(
            appState: appState,
            onboardingStore: appState.onboardingStore
        )
        appState.bindUpdater(updaterController)
        appState.bindOpenSettingsHandler {
            settingsWindowPresenter.show()
        }
        _updaterController = StateObject(wrappedValue: updaterController)
        _appState = StateObject(wrappedValue: appState)
        self.settingsWindowPresenter = settingsWindowPresenter
        self.onboardingWindowPresenter = onboardingWindowPresenter
        BundleSigningDiagnostics.logStartupIdentityIfDebug()

        if WisprSmokeLaunch.shouldOpenSettingsAfterLaunch {
            SmokeOpenSettingsLaunchObserver.start(appState: appState)
        } else {
            DispatchQueue.main.async {
                if appState.isOnboardingComplete {
                    guard FirstVisibleLaunch.shouldPresent() else { return }
                    FirstVisibleLaunch.markPresented()
                    appState.selectedSettingsTab = .general
                    settingsWindowPresenter.show()
                } else {
                    onboardingWindowPresenter.showIfNeeded()
                }
            }
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
                    .symbolRenderingMode(.monochrome)
                    .imageScale(.medium)
                    .foregroundStyle(.primary)
                if !appState.menuBarTitle.isEmpty {
                    Text(appState.menuBarTitle)
                        .lineLimit(1)
                }
            }
        }
    }
}
