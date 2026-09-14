#if canImport(XCTest)
import XCTest
@testable import AppShellSupport

final class SettingsSearchPresentationTests: XCTestCase {
    func testSearchFindsSettingsDestination() {
        let presentation = SettingsSearchPresentation(searchText: "bedienungshilfen", language: .german)

        XCTAssertTrue(presentation.isSearching)
        XCTAssertEqual(presentation.results.map(\.id), ["general.access"])
    }

    func testSearchFindsTechnicalAPITermWithoutPersonalContent() {
        let presentation = SettingsSearchPresentation(searchText: "api", language: .german)

        XCTAssertEqual(presentation.results.map(\.tab), [.ai])
        XCTAssertEqual(presentation.results.first?.sectionID, "providers")
    }

    func testSearchDoesNotExposePersonalTextOrUnknownTerms() {
        let presentation = SettingsSearchPresentation(searchText: "private dictation text", language: .german)

        XCTAssertTrue(presentation.results.isEmpty)
    }

    func testEmptyQueryIsNotSearching() {
        let presentation = SettingsSearchPresentation(searchText: "   ", language: .english)

        XCTAssertFalse(presentation.isSearching)
        XCTAssertTrue(presentation.results.isEmpty)
    }
}
#endif
