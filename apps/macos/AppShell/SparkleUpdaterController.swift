#if canImport(Sparkle)
import Foundation
import Sparkle

@MainActor
final class SparkleUpdaterController: ObservableObject {
    enum UpdaterState: Equatable {
        case unavailableFramework
        case notConfigured
        case ready
        case checking
        case updateAvailable

        var allowsManualCheck: Bool {
            switch self {
            case .unavailableFramework, .notConfigured:
                return false
            case .ready, .checking, .updateAvailable:
                return true
            }
        }

        var statusText: String {
            switch self {
            case .unavailableFramework:
                return "Sparkle nicht verfügbar"
            case .notConfigured:
                return "Updates noch nicht konfiguriert"
            case .ready:
                return "Automatische Update-Prüfung aktiv"
            case .checking:
                return "Prüfe auf Updates..."
            case .updateAvailable:
                return "Neues Update verfügbar"
            }
        }

        var detailText: String {
            switch self {
            case .unavailableFramework:
                return "Die Update-Engine ist in diesem Build nicht eingebunden."
            case .notConfigured:
                return "Sparkle ist vorhanden, aber der Release-Feed ist noch nicht konfiguriert."
            case .ready:
                return "WisprLocal prüft Updates im Hintergrund und GitHub Releases dienen als Veröffentlichungsquelle."
            case .checking:
                return "Der Appcast-Feed wird gerade abgefragt."
            case .updateAvailable:
                return "Ein neues Release kann jetzt installiert werden."
            }
        }
    }

    @Published private(set) var state: UpdaterState
    @Published private(set) var feedURLDescription: String

    private let updaterController: SPUStandardUpdaterController?
    private var pendingStateResetTask: Task<Void, Never>?

    init(configuration: MacAppConfiguration = .load()) {
        self.state = configuration.isUpdaterConfigured ? .ready : .notConfigured
        self.feedURLDescription = configuration.sparkleFeedDisplayText

        guard configuration.isUpdaterConfigured else {
            self.updaterController = nil
            return
        }

        self.updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    var statusText: String {
        state.statusText
    }

    var isConfigured: Bool {
        state.allowsManualCheck
    }

    func checkForUpdates() {
        guard let updaterController else {
            state = .notConfigured
            return
        }

        state = .checking
        pendingStateResetTask?.cancel()
        pendingStateResetTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard let self else { return }
            guard !Task.isCancelled else { return }
            if self.state == .checking {
                self.state = .ready
            }
        }
        updaterController.checkForUpdates(nil)
    }

    func setAutomaticallyChecksEnabled(_ enabled: Bool) {
        guard let updaterController else { return }
        updaterController.updater.automaticallyChecksForUpdates = enabled
    }
}
#else
import Foundation

@MainActor
final class SparkleUpdaterController: ObservableObject {
    enum UpdaterState: Equatable {
        case unavailableFramework
        case notConfigured
        case ready
        case checking
        case updateAvailable

        var allowsManualCheck: Bool {
            switch self {
            case .unavailableFramework, .notConfigured:
                return false
            case .ready, .checking, .updateAvailable:
                return true
            }
        }

        var statusText: String {
            switch self {
            case .unavailableFramework:
                return "Sparkle-Framework nicht verfügbar"
            case .notConfigured:
                return "Updater nicht konfiguriert"
            case .ready:
                return "Updater konfiguriert"
            case .checking:
                return "Suche nach Updates gestartet"
            case .updateAvailable:
                return "Update verfügbar"
            }
        }
    }

    @Published private(set) var state: UpdaterState = .unavailableFramework
    @Published private(set) var feedURLDescription: String = ""
    private var pendingStateResetTask: Task<Void, Never>?

    var statusText: String {
        state.statusText
    }

    var isConfigured: Bool {
        state.allowsManualCheck
    }

    init(configuration: MacAppConfiguration = .load()) {
        state = configuration.isUpdaterConfigured ? .ready : .notConfigured
        feedURLDescription = configuration.sparkleFeedDisplayText
    }

    func checkForUpdates() {
        state = .checking
        pendingStateResetTask?.cancel()
        pendingStateResetTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard let self else { return }
            guard !Task.isCancelled else { return }
            if self.state == .checking {
                self.state = .ready
            }
        }
    }

    func setAutomaticallyChecksEnabled(_ enabled: Bool) {
        _ = enabled
    }
}
#endif
