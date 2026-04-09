#if canImport(XCTest)
import Foundation
import XCTest
@testable import AppShellSupport

final class TranscriptHistoryStoreTests: XCTestCase {
    func testSaveAndLoadRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("app_shell_history_round_trip_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }

        let fileURL = directory.appendingPathComponent("history.json")
        let store = TranscriptHistoryStore(fileURL: fileURL)
        let entries = [
            TranscriptHistoryEntry(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                text: "Hello",
                languageCode: "en",
                mode: "streaming"
            ),
            TranscriptHistoryEntry(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                createdAt: Date(timeIntervalSince1970: 1_700_000_100),
                text: "World",
                languageCode: "de",
                mode: "finalize"
            ),
        ]

        try store.save(entries)
        let loaded = try store.load()

        XCTAssertEqual(loaded, entries)
    }

    func testLoadQuarantinesCorruptedStoreAndReturnsEmptyArray() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("app_shell_history_corrupt_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }

        let fileURL = directory.appendingPathComponent("history.json")
        let store = TranscriptHistoryStore(fileURL: fileURL)

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("broken".utf8).write(to: fileURL, options: [.atomic])

        let loaded = try store.load()

        XCTAssertEqual(loaded, [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))

        let quarantineFiles = try FileManager.default
            .contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("history.json.corrupt-") }
        XCTAssertEqual(quarantineFiles.count, 1)
    }

    func testExportTextUsesReverseChronologicalOrder() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("app_shell_history_export_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let fileURL = directory.appendingPathComponent("history.json")
        let exportURL = directory.appendingPathComponent("export.txt")
        let store = TranscriptHistoryStore(fileURL: fileURL)
        let older = TranscriptHistoryEntry(
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            text: "old",
            languageCode: "en",
            mode: "streaming"
        )
        let newer = TranscriptHistoryEntry(
            createdAt: Date(timeIntervalSince1970: 1_700_000_100),
            text: "new",
            languageCode: "de",
            mode: "finalize"
        )

        try store.exportText(entries: [older, newer], to: exportURL)
        let output = try String(contentsOf: exportURL, encoding: .utf8)
        let lines = output.split(separator: "\n")

        XCTAssertEqual(lines.count, 2)
        XCTAssertTrue(lines[0].contains("new"))
        XCTAssertTrue(lines[1].contains("old"))
    }
}
#endif
