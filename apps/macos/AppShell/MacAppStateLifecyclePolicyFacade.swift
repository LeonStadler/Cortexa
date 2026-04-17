import AppKit
import Foundation
#if canImport(ServiceManagement)
import ServiceManagement
#endif

@MainActor
final class MacAppStateLifecyclePolicyFacade {
    weak var updaterController: SparkleUpdaterController?

    private let appConfiguration: MacAppConfiguration
    private let appendDiagnostic: (String) -> Void
    private let currentOpenSettingsHandler: () -> (() -> Void)?
    private let currentDockPolicySettingsReopenWorkItem: () -> DispatchWorkItem?
    private let setDockPolicySettingsReopenWorkItem: (DispatchWorkItem?) -> Void

    init(
        appConfiguration: MacAppConfiguration,
        appendDiagnostic: @escaping (String) -> Void,
        currentOpenSettingsHandler: @escaping () -> (() -> Void)?,
        currentDockPolicySettingsReopenWorkItem: @escaping () -> DispatchWorkItem?,
        setDockPolicySettingsReopenWorkItem: @escaping (DispatchWorkItem?) -> Void
    ) {
        self.appConfiguration = appConfiguration
        self.appendDiagnostic = appendDiagnostic
        self.currentOpenSettingsHandler = currentOpenSettingsHandler
        self.currentDockPolicySettingsReopenWorkItem = currentDockPolicySettingsReopenWorkItem
        self.setDockPolicySettingsReopenWorkItem = setDockPolicySettingsReopenWorkItem
    }

    func bindUpdater(_ updaterController: SparkleUpdaterController?) {
        self.updaterController = updaterController
    }

    @discardableResult
    func applyActivationPolicy(showInDock: Bool) -> Bool {
        let app = NSApplication.shared
        let targetPolicy: NSApplication.ActivationPolicy = showInDock ? .regular : .accessory
        guard app.activationPolicy() != targetPolicy else {
            return false
        }

        let ok = app.setActivationPolicy(targetPolicy)
        if !ok {
            appendDiagnostic(
                "Die Aktivierungsrichtlinie konnte nicht auf \(showInDock ? "Dock" : "nur Menüleiste") umgestellt werden."
            )
        }
        return ok
    }

    func scheduleSettingsReopenAfterDockPolicyChange() {
        guard currentOpenSettingsHandler() != nil else { return }

        currentDockPolicySettingsReopenWorkItem()?.cancel()

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.setDockPolicySettingsReopenWorkItem(nil)
            self.currentOpenSettingsHandler()?()
        }

        setDockPolicySettingsReopenWorkItem(work)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.065, execute: work)
    }

    func syncLaunchOnLogin(isEnabled: Bool) {
        do {
            if isEnabled {
                if #available(macOS 13.0, *), SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                    appendDiagnostic("Anmeldung beim Systemstart aktiviert.")
                }
            } else if #available(macOS 13.0, *), SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
                appendDiagnostic("Anmeldung beim Systemstart deaktiviert.")
            }
        } catch {
            appendDiagnostic(
                "Anmeldung beim Systemstart konnte nicht aktualisiert werden: \(error.localizedDescription)"
            )
        }
    }

    func syncAutomaticUpdateChecks(_ automaticallyCheckForUpdates: Bool) {
        updaterController?.setAutomaticallyChecksEnabled(automaticallyCheckForUpdates)
    }

    func updaterStateSnapshot() -> (configured: Bool, feedURLText: String, statusText: String) {
        let configured = appConfiguration.isUpdaterConfigured
        let feedURLText = appConfiguration.sparkleFeedURL?.absoluteString ?? ""
        let statusText = configured ? "Updater konfiguriert" : "Updater nicht konfiguriert"
        return (configured, feedURLText, statusText)
    }

    static func currentLaunchOnLoginEnabled() -> Bool {
        #if canImport(ServiceManagement)
            if #available(macOS 13.0, *) {
                return SMAppService.mainApp.status == .enabled
            }
        #endif
        return false
    }
}

extension MacAppState {
    static func currentLaunchOnLoginEnabled() -> Bool {
        MacAppStateLifecyclePolicyFacade.currentLaunchOnLoginEnabled()
    }

    @discardableResult
    func applyActivationPolicy() -> Bool {
        lifecyclePolicyFacade.applyActivationPolicy(showInDock: showInDock)
    }

    func scheduleSettingsReopenAfterDockPolicyChange() {
        lifecyclePolicyFacade.scheduleSettingsReopenAfterDockPolicyChange()
    }

    func syncLaunchOnLogin() {
        lifecyclePolicyFacade.syncLaunchOnLogin(isEnabled: launchOnLoginEnabled)
    }

    func syncAutomaticUpdateChecks() {
        lifecyclePolicyFacade.syncAutomaticUpdateChecks(automaticallyCheckForUpdates)
    }

    func updateUpdaterState() {
        let snapshot = lifecyclePolicyFacade.updaterStateSnapshot()
        updaterConfigured = snapshot.configured
        updaterFeedURLText = snapshot.feedURLText
        updaterStatusText = snapshot.statusText
    }
}
