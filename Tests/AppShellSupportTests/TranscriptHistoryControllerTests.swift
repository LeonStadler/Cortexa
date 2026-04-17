#if canImport(XCTest)
import AppKit
import Foundation
import XCTest
@testable import AppShellSupport

@MainActor
final class TranscriptHistoryControllerTests: XCTestCase {
    func testLoadHistoryPrunesExpiredEntriesAndPersistsTheRemainingSnapshot() {
        let oldEntry = TranscriptHistoryEntry(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            createdAt: Date().addingTimeInterval(-10 * 24 * 60 * 60),
            text: "old",
            languageCode: "de",
            mode: "finalize"
        )
        let freshEntry = TranscriptHistoryEntry(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            createdAt: Date(),
            text: "fresh",
            languageCode: "de",
            mode: "streaming"
        )

        let store = AppShellTestHistoryStore(loadResult: [oldEntry, freshEntry])
        var currentHistory: [TranscriptHistoryEntry] = []
        let retentionPolicy: HistoryRetentionPolicy = .sevenDays
        var diagnostics: [String] = []
        var audits: [String] = []
        let controller = makeController(
            historyStore: store,
            currentTranscriptHistory: { currentHistory },
            setTranscriptHistory: { currentHistory = $0 },
            currentHistoryRetentionPolicy: { retentionPolicy },
            appendDiagnostic: { diagnostics.append($0) },
            appendAudit: { audits.append($0) }
        )

        controller.loadHistory()

        XCTAssertEqual(currentHistory, [freshEntry])
        XCTAssertEqual(store.savedSnapshots.last, [freshEntry])
        XCTAssertTrue(diagnostics.contains("History geladen: 1"))
        XCTAssertTrue(audits.isEmpty)
    }

    func testLoadHistoryClearsStateWhenLoadingFails() {
        let store = AppShellTestHistoryStore(loadResult: [])
        store.loadError = AppShellTestHistoryStoreError.loadFailed

        var currentHistory: [TranscriptHistoryEntry] = [
            TranscriptHistoryEntry(text: "stale", languageCode: "de", mode: "finalize")
        ]
        var diagnostics: [String] = []
        let controller = makeController(
            historyStore: store,
            currentTranscriptHistory: { currentHistory },
            setTranscriptHistory: { currentHistory = $0 },
            appendDiagnostic: { diagnostics.append($0) }
        )

        controller.loadHistory()

        XCTAssertEqual(currentHistory, [])
        XCTAssertTrue(diagnostics.first?.hasPrefix("History-Load fehlgeschlagen:") == true)
    }

    func testHandleFinalTranscriptTrimsTextPersistsEntryAndLogsOutcome() {
        let store = AppShellTestHistoryStore(loadResult: [])
        var currentHistory: [TranscriptHistoryEntry] = []
        var diagnostics: [String] = []
        var audits: [String] = []
        let controller = makeController(
            historyStore: store,
            currentTranscriptHistory: { currentHistory },
            setTranscriptHistory: { currentHistory = $0 },
            currentHistoryRetentionPolicy: { .forever },
            appendDiagnostic: { diagnostics.append($0) },
            appendAudit: { audits.append($0) }
        )

        controller.handleFinalTranscript(
            FinalTranscriptEvent(
                text: "  Hallo Welt  ",
                languageCode: "de",
                mode: .streaming,
                deliveryOutcome: .historyOnlyNoTarget
            )
        )

        XCTAssertEqual(currentHistory.first?.text, "Hallo Welt")
        XCTAssertEqual(currentHistory.first?.mode, "streaming")
        XCTAssertEqual(store.savedSnapshots.last?.first?.text, "Hallo Welt")
        XCTAssertTrue(
            diagnostics.contains("Finales Transkript ohne Ziel nur in der History gespeichert.")
        )
        XCTAssertEqual(audits.last, "transcript.final language=de mode=streaming chars=10")
    }

    func testCopyHistoryEntryAndCopyAllHistoryToClipboard() throws {
        let olderEntry = TranscriptHistoryEntry(
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            text: "old",
            languageCode: "de",
            mode: "finalize"
        )
        let newerEntry = TranscriptHistoryEntry(
            createdAt: Date(timeIntervalSince1970: 1_700_000_100),
            text: "new",
            languageCode: "en",
            mode: "streaming"
        )
        var currentHistory = [olderEntry, newerEntry]
        var diagnostics: [String] = []
        let pasteboard = StubHistoryClipboard()
        let controller = makeController(
            clipboard: pasteboard,
            currentTranscriptHistory: { currentHistory },
            setTranscriptHistory: { currentHistory = $0 },
            appendDiagnostic: { diagnostics.append($0) }
        )

        controller.copyHistoryEntry(newerEntry)
        XCTAssertEqual(pasteboard.lastString, "new")

        let historyFormatter = DateFormatter()
        historyFormatter.dateStyle = .short
        historyFormatter.timeStyle = .medium
        historyFormatter.locale = .current
        historyFormatter.timeZone = .current
        let expectedHistory = [
            "[\(historyFormatter.string(from: newerEntry.createdAt))] [\(newerEntry.mode)] [\(newerEntry.languageCode)] \(newerEntry.text)",
            "[\(historyFormatter.string(from: olderEntry.createdAt))] [\(olderEntry.mode)] [\(olderEntry.languageCode)] \(olderEntry.text)",
        ].joined(separator: "\n")

        controller.copyAllHistoryToClipboard()
        XCTAssertEqual(pasteboard.lastString, expectedHistory)

        XCTAssertEqual(currentHistory, [olderEntry, newerEntry])
        XCTAssertTrue(
            diagnostics.contains("History-Eintrag kopiert: \(newerEntry.id.uuidString.prefix(8))")
        )
        XCTAssertTrue(diagnostics.contains("Gesamte History in Zwischenablage kopiert"))
    }

    func testRemoveHistoryEntryAndClearHistoryPersistSnapshots() {
        let firstEntry = TranscriptHistoryEntry(
            text: "first",
            languageCode: "de",
            mode: "streaming"
        )
        let secondEntry = TranscriptHistoryEntry(
            text: "second",
            languageCode: "en",
            mode: "finalize"
        )
        let store = AppShellTestHistoryStore(loadResult: [])
        var currentHistory = [firstEntry, secondEntry]
        var diagnostics: [String] = []
        var audits: [String] = []
        let controller = makeController(
            historyStore: store,
            currentTranscriptHistory: { currentHistory },
            setTranscriptHistory: { currentHistory = $0 },
            appendDiagnostic: { diagnostics.append($0) },
            appendAudit: { audits.append($0) }
        )

        controller.removeHistoryEntry(firstEntry.id)
        XCTAssertEqual(currentHistory, [secondEntry])
        XCTAssertEqual(store.savedSnapshots.last, [secondEntry])

        controller.clearHistory()
        XCTAssertEqual(currentHistory, [])
        XCTAssertEqual(store.savedSnapshots.last, [])
        XCTAssertTrue(diagnostics.contains("History geleert"))
        XCTAssertTrue(audits.contains("history.clear"))
    }

    private func makeController(
        historyStore: TranscriptHistoryStoring = AppShellTestHistoryStore(loadResult: []),
        clipboard: HistoryClipboardWriting = StubHistoryClipboard(),
        currentTranscriptHistory: @escaping () -> [TranscriptHistoryEntry],
        setTranscriptHistory: @escaping ([TranscriptHistoryEntry]) -> Void,
        currentHistoryRetentionPolicy: @escaping () -> HistoryRetentionPolicy = { .forever },
        appendDiagnostic: @escaping (String) -> Void = { _ in },
        appendAudit: @escaping (String) -> Void = { _ in }
    ) -> TranscriptHistoryController {
        TranscriptHistoryController(
            historyStore: historyStore,
            clipboard: clipboard,
            currentTranscriptHistory: currentTranscriptHistory,
            setTranscriptHistory: setTranscriptHistory,
            currentHistoryRetentionPolicy: currentHistoryRetentionPolicy,
            appendDiagnostic: appendDiagnostic,
            appendAudit: appendAudit
        )
    }

}

private final class StubHistoryClipboard: HistoryClipboardWriting {
    private(set) var clearContentsCallCount = 0
    private(set) var lastString: String?

    @discardableResult
    func clearContents() -> Int {
        clearContentsCallCount += 1
        lastString = nil
        return 1
    }

    @discardableResult
    func setString(_ string: String, forType type: NSPasteboard.PasteboardType) -> Bool {
        lastString = string
        return true
    }
}

#endif
