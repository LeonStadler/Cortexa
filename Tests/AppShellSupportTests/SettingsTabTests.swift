#if canImport(XCTest)
import XCTest
@testable import AppShellSupport

final class SettingsTabTests: XCTestCase {
    func testTitlesStayStableForSearchAndNavigation() {
        XCTAssertEqual(SettingsTab.general.title(language: .german), "Allgemein")
        XCTAssertEqual(SettingsTab.history.title(language: .english), "History")
        XCTAssertEqual(SettingsTab.ai.title(language: .german), "KI")
        XCTAssertEqual(SettingsTab.dictionary.title(language: .english), "Dictionary")
        XCTAssertEqual(SettingsTab.snippets.title(language: .english), "Snippets")
    }

    func testDescriptionsExposeTheExpectedSearchKeywords() {
        XCTAssertTrue(SettingsTab.history.details(language: .english).contains("Search saved dictations"))
        XCTAssertTrue(SettingsTab.ai.details(language: .german).contains("KI-Anbieter"))
        XCTAssertTrue(SettingsTab.dictionary.details(language: .english).contains("personal terms"))
        XCTAssertTrue(SettingsTab.advanced.details(language: .english).contains("diagnostics"))
    }

    func testSidebarGroupsAreStableAndLocalized() {
        XCTAssertEqual(SettingsTab.tabs(in: .writing), [.ai, .dictionary, .snippets])
        XCTAssertEqual(SettingsTab.Group.general.title(language: .german), "App")
        XCTAssertEqual(SettingsTab.Group.system.title(language: .german), "Daten & System")
        XCTAssertEqual(SettingsTab(rawValue: SettingsTab.advanced.persistenceID), .advanced)
    }
}
#endif
