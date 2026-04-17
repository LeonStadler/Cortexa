#if canImport(XCTest)
import AIProcessingCore
import Foundation
import XCTest
@testable import AppShellSupport

final class MacAppPreferencesStoreTests: XCTestCase {
    func testLoadInitialStateUsesPersistedValues() {
        let defaultsName = "MacAppPreferencesStoreTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: defaultsName)!
        defer { userDefaults.removePersistentDomain(forName: defaultsName) }

        userDefaults.set(false, forKey: "wispr.settings.streamingEnabled")
        userDefaults.set(DictationLanguage.english.rawValue, forKey: "wispr.settings.selectedLanguage")
        userDefaults.set(
            FinalResultDeliveryMode.clipboardOnly.rawValue,
            forKey: "wispr.settings.finalResultDeliveryMode"
        )
        userDefaults.set(true, forKey: "wispr.settings.aiProcessingEnabled")
        userDefaults.set(false, forKey: "wispr.settings.launchOnLoginEnabled")
        userDefaults.set(false, forKey: "wispr.settings.automaticallyCheckForUpdates")
        userDefaults.set("test-model", forKey: "wispr.settings.selectedAIModelID")
        userDefaults.set(85.0, forKey: "wispr.settings.soundEffectsVolume")
        userDefaults.set(
            try? JSONEncoder().encode([
                AIRemoteProviderConfiguration.template(for: .ollama)
            ]),
            forKey: "wispr.settings.ai.remoteProviders"
        )

        let snapshot = MacAppPreferencesStore(userDefaults: userDefaults).loadInitialState(
            currentLaunchOnLoginEnabled: true
        )

        XCTAssertFalse(snapshot.streamingEnabled)
        XCTAssertEqual(snapshot.selectedLanguage, .english)
        XCTAssertEqual(snapshot.finalResultDeliveryMode, .clipboardOnly)
        XCTAssertTrue(snapshot.aiProcessingEnabled)
        XCTAssertFalse(snapshot.launchOnLoginEnabled)
        XCTAssertFalse(snapshot.automaticallyCheckForUpdates)
        XCTAssertEqual(snapshot.selectedAIModelID, "test-model")
        XCTAssertEqual(snapshot.soundEffectsVolume, 85)
        XCTAssertEqual(snapshot.remoteProviders.count, 1)
        XCTAssertEqual(snapshot.selectedRemoteProviderID, snapshot.remoteProviders.first?.id)
    }

    func testLoadInitialStateFallsBackToCurrentLaunchOnLoginValueWhenUnset() {
        let defaultsName = "MacAppPreferencesStoreTests.launch.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: defaultsName)!
        defer { userDefaults.removePersistentDomain(forName: defaultsName) }

        let snapshot = MacAppPreferencesStore(userDefaults: userDefaults).loadInitialState(
            currentLaunchOnLoginEnabled: true
        )

        XCTAssertTrue(snapshot.launchOnLoginEnabled)
        XCTAssertTrue(snapshot.automaticallyCheckForUpdates)
        XCTAssertEqual(snapshot.selectedLanguage, .german)
        XCTAssertEqual(snapshot.translationOutputMode, .original)
    }
}
#endif
