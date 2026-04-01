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

    @Published private(set) var state: UpdaterState
    @Published private(set) var feedURLDescription: String

    private let updaterController: SPUStandardUpdaterController?

    init(configuration: MacAppConfiguration = .load()) {
        self.state = configuration.isUpdaterConfigured ? .ready : .notConfigured
        self.feedURLDescription = configuration.sparkleFeedURL?.absoluteString ?? ""

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
        updaterController.checkForUpdates(nil)
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

    var statusText: String {
        state.statusText
    }

    var isConfigured: Bool {
        state.allowsManualCheck
    }

    init(configuration: MacAppConfiguration = .load()) {
        state = configuration.isUpdaterConfigured ? .ready : .notConfigured
        feedURLDescription = configuration.sparkleFeedURL?.absoluteString ?? ""
    }

    func checkForUpdates() {
        state = .checking
    }
}
#endif
