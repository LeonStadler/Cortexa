#if canImport(XCTest)
import Foundation
import XCTest
@testable import SnippetCore

final class SnippetStoreTests: XCTestCase {
    func testSaveAndLoadRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("snippet_store_round_trip_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }

        let fileURL = directory.appendingPathComponent("snippets.json")
        let store = SnippetStore(fileURL: fileURL)
        let rules = [
            makeRule(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, trigger: "foo", replacement: "bar")
        ]

        try store.save(rules)
        let loaded = try store.load()

        XCTAssertEqual(loaded, rules)
    }

    func testImportAndExportRulesRetainPayload() throws {
        let baseDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("snippet_store_io_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: baseDirectory) }

        let storeURL = baseDirectory.appendingPathComponent("store/snippets.json")
        let sourceURL = baseDirectory.appendingPathComponent("source/snippets.json")
        let exportURL = baseDirectory.appendingPathComponent("exported/snippets.json")

        let store = SnippetStore(fileURL: storeURL)
        let expectedRules = [
            makeRule(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, trigger: "hello", replacement: "world", localeIdentifier: "de_AT"),
            makeRule(id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!, trigger: "swift", replacement: "🪐", caseSensitive: true)
        ]

        try FileManager.default.createDirectory(at: sourceURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encodedSource = try JSONEncoder().encode(expectedRules)
        try encodedSource.write(to: sourceURL)

        let imported = try store.importRules(from: sourceURL)
        XCTAssertEqual(imported, expectedRules)

        let loaded = try store.load()
        XCTAssertEqual(loaded, expectedRules)

        try store.exportRules(expectedRules, to: exportURL)
        let exported = try JSONDecoder().decode([SnippetRule].self, from: Data(contentsOf: exportURL))
        XCTAssertEqual(exported, expectedRules)
    }

    private func makeRule(
        id: UUID,
        trigger: String,
        replacement: String,
        caseSensitive: Bool = false,
        localeIdentifier: String? = nil
    ) -> SnippetRule {
        SnippetRule(id: id, trigger: trigger, replacement: replacement, caseSensitive: caseSensitive, localeIdentifier: localeIdentifier)
    }
}
#endif
