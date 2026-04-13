#if canImport(XCTest)
import XCTest
@testable import AppShellSupport

final class SettingsTabTests: XCTestCase {
    func testTitlesStayStableForSearchAndNavigation() {
        XCTAssertEqual(SettingsTab.general.title(language: .german), "Allgemein")
        XCTAssertEqual(SettingsTab.history.title(language: .english), "History")
        XCTAssertEqual(SettingsTab.ai.title(language: .german), "AI")
        XCTAssertEqual(SettingsTab.dictionary.title(language: .english), "Dictionary")
        XCTAssertEqual(SettingsTab.snippets.title(language: .english), "Snippets")
    }

    func testDescriptionsExposeTheExpectedSearchKeywords() {
        XCTAssertTrue(SettingsTab.history.details(language: .english).contains("Search saved dictations"))
        XCTAssertTrue(SettingsTab.ai.details(language: .german).contains("KI-Anbieter"))
        XCTAssertTrue(SettingsTab.dictionary.details(language: .english).contains("personal terms"))
        XCTAssertTrue(SettingsTab.advanced.details(language: .english).contains("diagnostics"))
    }
}
#endif
