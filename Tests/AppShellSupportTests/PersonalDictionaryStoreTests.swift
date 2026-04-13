#if canImport(XCTest)
import Foundation
import XCTest
@testable import AppShellSupport

final class PersonalDictionaryStoreTests: XCTestCase {
    func testSaveAndLoadDedupesTermsAndReviewQueue() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fileManager.removeItem(at: root) }

        let store = PersonalDictionaryStore(
            fileURL: root.appendingPathComponent("dictionary.json"),
            fileManager: fileManager
        )

        try store.save(
            terms: [
                DictionaryTerm(term: "WisprLocal", category: .companyJargon, source: .manual),
                DictionaryTerm(term: "wisprlocal", category: .custom, source: .manual),
            ],
            reviewQueue: [
                DictionaryReviewCandidate(proposedTerm: "WisprLocal", category: .companyJargon),
                DictionaryReviewCandidate(proposedTerm: "Leon Stadler", category: .personName),
                DictionaryReviewCandidate(proposedTerm: "Leon Stadler", category: .personName),
            ]
        )

        let snapshot = try store.load()

        XCTAssertEqual(snapshot.terms.count, 1)
        XCTAssertEqual(snapshot.terms.first?.term, "WisprLocal")
        XCTAssertEqual(snapshot.reviewQueue.count, 1)
        XCTAssertEqual(snapshot.reviewQueue.first?.proposedTerm, "Leon Stadler")
    }
}
#endif
