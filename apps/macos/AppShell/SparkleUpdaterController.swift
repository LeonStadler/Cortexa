#if canImport(Sparkle)
import Foundation
import Sparkle

@MainActor
final class SparkleUpdaterController: ObservableObject {
    @Published private(set) var statusText: String
    @Published private(set) var isConfigured: Bool
    @Published private(set) var feedURLDescription: String

    private let updaterController: SPUStandardUpdaterController?

    init(configuration: MacAppConfiguration = .load()) {
        self.isConfigured = configuration.isUpdaterConfigured
        self.feedURLDescription = configuration.sparkleFeedURL?.absoluteString ?? ""

        guard configuration.isUpdaterConfigured else {
            self.statusText = "Updater nicht konfiguriert"
            self.updaterController = nil
            return
        }

        self.statusText = "Updater konfiguriert"
        self.updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    func checkForUpdates() {
        guard let updaterController else {
            statusText = "Updater nicht konfiguriert"
            return
        }

        statusText = "Suche nach Updates gestartet"
        updaterController.checkForUpdates(nil)
    }
}
#else
import Foundation

@MainActor
final class SparkleUpdaterController: ObservableObject {
    @Published private(set) var statusText: String = "Sparkle-Framework nicht verfügbar"
    @Published private(set) var isConfigured: Bool = false
    @Published private(set) var feedURLDescription: String = ""

    init(configuration: MacAppConfiguration = .load()) {}

    func checkForUpdates() {}
}
#endif
