#if canImport(XCTest)
import ASRCore
import Foundation
import XCTest
@testable import AppShellSupport

@MainActor
final class OnboardingStoreTests: XCTestCase {
    func testMigrationMarksCompleteWhenStandardModelExists() throws {
        let suiteName = "OnboardingStoreTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let fileManager = FileManager.default
        let appName = "WisprLocalOnboardingTest"
        let appSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let runtimeRoot = appSupport.appendingPathComponent(appName, isDirectory: true)
        let runtimeModels = runtimeRoot.appendingPathComponent("runtime/models", isDirectory: true)
        defer { try? fileManager.removeItem(at: runtimeRoot) }

        try fileManager.createDirectory(at: runtimeModels, withIntermediateDirectories: true)
        try Data([0x01]).write(to: runtimeModels.appendingPathComponent("ggml-base.bin"))

        let store = OnboardingStore(
            userDefaults: userDefaults,
            appVersion: "0.26.0",
            fileManager: fileManager
        )
        XCTAssertFalse(store.isComplete)

        store.migrateIfStandardModelAlreadyInstalled(appName: appName)
        XCTAssertTrue(store.isComplete)
    }

    func testMarkCompletePersistsAppVersion() {
        let suiteName = "OnboardingStoreTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let store = OnboardingStore(userDefaults: userDefaults, appVersion: "0.26.0")
        XCTAssertFalse(store.isComplete)

        store.markComplete()
        XCTAssertTrue(store.isComplete)
        XCTAssertEqual(
            userDefaults.string(forKey: OnboardingStore.completedVersionKey),
            "0.26.0"
        )
    }
}
#endif
