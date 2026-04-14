#if canImport(XCTest)
import Foundation
import SnippetCore
import XCTest
@testable import AppShellSupport

final class SettingsSearchPresentationTests: XCTestCase {
    func testEmptyQueryDoesNotFilterAnything() {
        let presentation = makePresentation(searchText: "   ")

        XCTAssertFalse(presentation.isSearching)
        XCTAssertTrue(presentation.matches(["anything"]))
        XCTAssertTrue(presentation.generalHasMatches)
        XCTAssertEqual(presentation.filteredHistory.count, 2)
        XCTAssertEqual(presentation.compactHistoryEntries(limit: 1).count, 1)
        XCTAssertEqual(presentation.filteredSnippets.count, 2)
    }

    func testQueryMatchesMetadataAndCategoryKeywords() {
        let presentation = makePresentation(searchText: "version")

        XCTAssertTrue(presentation.aboutAppMetadataMatchesSearch)
        XCTAssertTrue(presentation.advancedHasMatches)
        XCTAssertFalse(presentation.historyHasMatches)
        XCTAssertFalse(presentation.snippetsHasMatches)
    }

    func testQueryFiltersHistorySnippetsAndAdvancedFields() {
        let presentation = makePresentation(searchText: "fresh")

        XCTAssertEqual(presentation.filteredHistory.map(\.text), ["fresh note"])
        XCTAssertTrue(presentation.historyHasMatches)
        XCTAssertEqual(presentation.filteredSnippets.map(\.trigger), ["fresh"])
        XCTAssertTrue(presentation.snippetsHasMatches)
        XCTAssertFalse(presentation.advancedHasMatches)
        XCTAssertEqual(presentation.compactHistoryEntries(limit: 1).map(\.text), ["fresh note"])
    }

    func testQueryMatchesAdvancedFieldsWhenDiagnosticsContainsTheSearchTerm() {
        let presentation = makePresentation(searchText: "error")

        XCTAssertTrue(presentation.advancedHasMatches)
        XCTAssertFalse(presentation.historyHasMatches)
        XCTAssertFalse(presentation.snippetsHasMatches)
    }

    private func makePresentation(searchText: String) -> SettingsSearchPresentation {
        SettingsSearchPresentation(
            searchText: searchText,
            transcriptHistory: [
                TranscriptHistoryEntry(
                    text: "old note",
                    languageCode: "de",
                    mode: "finalize"
                ),
                TranscriptHistoryEntry(
                    text: "fresh note",
                    languageCode: "en",
                    mode: "streaming"
                ),
            ],
            dictionaryTerms: [
                DictionaryTerm(
                    term: "WisprLocal",
                    category: .companyJargon,
                    source: .manual
                )
            ],
            dictionaryReviewQueue: [
                DictionaryReviewCandidate(
                    proposedTerm: "Leon Stadler",
                    category: .personName
                )
            ],
            snippetRules: [
                SnippetRule(trigger: "old", replacement: "archive"),
                SnippetRule(trigger: "fresh", replacement: "current"),
            ],
            diagnosticsText: "latest error log",
            capabilitySummary: "speech capability ready",
            updaterStatusText: "build version 1.0"
        )
    }

    func testQueryMatchesDictionaryContent() {
        let presentation = makePresentation(searchText: "wispr")

        XCTAssertTrue(presentation.dictionaryHasMatches)
        XCTAssertEqual(presentation.filteredDictionaryTerms.map(\.term), ["WisprLocal"])
    }
}
#endif
