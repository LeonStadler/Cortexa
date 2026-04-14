#if canImport(XCTest)
import Foundation
import SnippetCore
import XCTest
@testable import AppShellSupport

@MainActor
final class SnippetControllerTests: XCTestCase {
    func testAddSnippetTrimsValuesAndPersistsRules() {
        let store = SnippetStore(fileURL: uniqueStoreURL())
        let state = SnippetControllerState()
        let controller = makeController(state: state, store: store)

        controller.addSnippet(trigger: "  brb  ", replacement: "  be right back  ")

        XCTAssertEqual(state.snippetRules.count, 1)
        XCTAssertEqual(state.snippetRules.first?.trigger, "brb")
        XCTAssertEqual(state.snippetRules.first?.replacement, "be right back")
        XCTAssertTrue(state.diagnostics.contains(where: { $0.contains("Snippets gespeichert: 1") }))
        XCTAssertTrue(state.auditLines.contains(where: { $0.contains("snippets.save count=1") }))
    }

    func testAddSnippetRejectsDuplicateTriggerCaseInsensitive() {
        let store = SnippetStore(fileURL: uniqueStoreURL())
        let state = SnippetControllerState()
        state.snippetRules = [
            SnippetRule(
                trigger: "brb",
                replacement: "be right back",
                caseSensitive: false,
                localeIdentifier: "de_DE"
            )
        ]
        let controller = makeController(state: state, store: store)

        controller.addSnippet(trigger: "BRB", replacement: "duplicate")

        XCTAssertEqual(state.snippetRules.count, 1)
        XCTAssertTrue(state.diagnostics.contains(where: { $0.contains("Trigger existiert bereits") }))
    }

    func testLoadSnippetsReadsPersistedRulesIntoState() throws {
        let storeURL = uniqueStoreURL()
        let store = SnippetStore(fileURL: storeURL)
        let persisted = [
            SnippetRule(
                trigger: "mfg",
                replacement: "Mit freundlichen Grüßen",
                caseSensitive: false,
                localeIdentifier: "de_DE"
            )
        ]
        try store.save(persisted)
        let state = SnippetControllerState()
        let controller = makeController(state: state, store: store)

        controller.loadSnippets()

        XCTAssertEqual(state.snippetRules, persisted)
        XCTAssertTrue(state.diagnostics.contains(where: { $0.contains("Snippets geladen: 1") }))
    }

    private func makeController(state: SnippetControllerState, store: SnippetStore) -> SnippetController {
        SnippetController(
            snippetStore: store,
            currentSnippetRules: { state.snippetRules },
            setSnippetRules: { state.snippetRules = $0 },
            currentSelectedLanguageLocaleIdentifier: { state.selectedLanguageLocaleIdentifier },
            appendDiagnostic: { state.diagnostics.append($0) },
            appendAudit: { state.auditLines.append($0) }
        )
    }

    private func uniqueStoreURL() -> URL {
        let directory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(".build/snippet-controller-tests", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("\(UUID().uuidString).json")
    }
}

private final class SnippetControllerState {
    var snippetRules: [SnippetRule] = []
    var selectedLanguageLocaleIdentifier = "de_DE"
    var diagnostics: [String] = []
    var auditLines: [String] = []
}
#endif
