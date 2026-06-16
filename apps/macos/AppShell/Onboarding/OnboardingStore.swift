import ASRCore
import Foundation

final class OnboardingStore {
    static let completedVersionKey = "wispr.onboarding.completedVersion"

    private let userDefaults: UserDefaults
    private let appVersion: String
    private let fileManager: FileManager

    init(
        userDefaults: UserDefaults = .standard,
        appVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            ?? "0",
        fileManager: FileManager = .default
    ) {
        self.userDefaults = userDefaults
        self.appVersion = appVersion
        self.fileManager = fileManager
    }

    var isComplete: Bool {
        userDefaults.string(forKey: Self.completedVersionKey) == appVersion
    }

    func markComplete() {
        userDefaults.set(appVersion, forKey: Self.completedVersionKey)
    }

    /// Existing installs with the standard model skip onboarding on first launch after upgrade.
    func migrateIfStandardModelAlreadyInstalled(appName: String = "WisprLocal") {
        guard !isComplete else { return }

        do {
            let runtimeDirectory = try BundledWhisperRuntimeInstaller.defaultInstallDirectory(
                appName: appName,
                fileManager: fileManager
            )
            let modelURL = runtimeDirectory
                .appendingPathComponent("models", isDirectory: true)
                .appendingPathComponent(LocalVoiceModelCatalog.defaultModelFileName)
            if fileManager.fileExists(atPath: modelURL.path) {
                markComplete()
            }
        } catch {
            // Migration is best-effort; fresh installs continue into onboarding.
        }
    }
}
