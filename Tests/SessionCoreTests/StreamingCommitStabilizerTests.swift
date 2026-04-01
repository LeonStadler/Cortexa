#if canImport(XCTest)
import Foundation
import XCTest
@testable import SessionCore

final class StreamingCommitStabilizerTests: XCTestCase {
    func testStableCommitRequiresRepeatedPartialBeforeCommitting() {
        let stabilizer = StreamingCommitStabilizer(stabilityThreshold: 2, rewriteScope: .currentParagraph)

        let first = stabilizer.ingestPartial("ready")
        XCTAssertEqual(first.committedPrefix, "")
        XCTAssertEqual(first.tail, "ready")

        let second = stabilizer.ingestPartial("ready")
        XCTAssertEqual(second.committedPrefix, "")
        XCTAssertEqual(second.tail, "ready")
    }

    func testTailReflectsPartialExtensionBeforeStableCommit() {
        let stabilizer = StreamingCommitStabilizer(stabilityThreshold: 2, rewriteScope: .currentParagraph)
        _ = stabilizer.ingestPartial("hello")
        _ = stabilizer.ingestPartial("hello")

        let firstExpansion = stabilizer.ingestPartial("hello world")
        XCTAssertEqual(firstExpansion.committedPrefix, "")
        XCTAssertEqual(firstExpansion.tail, "hello world")

        let secondExpansion = stabilizer.ingestPartial("hello world")
        XCTAssertEqual(secondExpansion.committedPrefix, "hello ")
        XCTAssertEqual(secondExpansion.tail, "world")
    }

    func testResetClearsHistory() {
        let stabilizer = StreamingCommitStabilizer(stabilityThreshold: 2, rewriteScope: .currentParagraph)
        _ = stabilizer.ingestPartial("alpha")
        _ = stabilizer.ingestPartial("alpha")

        stabilizer.reset()

        let afterReset = stabilizer.ingestPartial("beta")
        XCTAssertEqual(afterReset.committedPrefix, "")
        XCTAssertEqual(afterReset.tail, "beta")
    }

    func testRepeatedPartialCommitsOnlyStableWordBoundary() {
        let stabilizer = StreamingCommitStabilizer(stabilityThreshold: 2, rewriteScope: .currentParagraph)

        let first = stabilizer.ingestPartial("hello wor")
        let second = stabilizer.ingestPartial("hello wor")

        XCTAssertEqual(first.committedPrefix, "")
        XCTAssertEqual(first.tail, "hello wor")
        XCTAssertEqual(second.committedPrefix, "hello ")
        XCTAssertEqual(second.tail, "wor")
    }

    func testRepeatedPartialCommitsTrailingPunctuation() {
        let stabilizer = StreamingCommitStabilizer(stabilityThreshold: 2, rewriteScope: .currentParagraph)

        _ = stabilizer.ingestPartial("hello world.")
        let committed = stabilizer.ingestPartial("hello world.")

        XCTAssertEqual(committed.committedPrefix, "hello world.")
        XCTAssertEqual(committed.tail, "")
    }

    func testMinimumCommitExtensionLengthDelaysShortStableExtension() {
        let stabilizer = StreamingCommitStabilizer(
            stabilityThreshold: 2,
            minimumCommitExtensionLength: 5,
            rewriteScope: .currentParagraph
        )

        _ = stabilizer.ingestPartial("hello ")
        let committed = stabilizer.ingestPartial("hello ")

        XCTAssertEqual(committed.committedPrefix, "hello ")
        XCTAssertEqual(committed.tail, "")

        let shortExpansion = stabilizer.ingestPartial("hello wo")
        let repeatedShortExpansion = stabilizer.ingestPartial("hello wo")

        XCTAssertEqual(shortExpansion.committedPrefix, "hello ")
        XCTAssertEqual(repeatedShortExpansion.committedPrefix, "hello ")
        XCTAssertEqual(repeatedShortExpansion.tail, "wo")
    }

    func testCurrentSentenceScopeCommitsOlderSentenceOnceNewSentenceStarts() {
        let stabilizer = StreamingCommitStabilizer(
            stabilityThreshold: 2,
            minimumCommitExtensionLength: 1,
            rewriteScope: .currentSentence
        )

        _ = stabilizer.ingestPartial("Erster Satz. Zweiter")
        let committed = stabilizer.ingestPartial("Erster Satz. Zweiter")

        XCTAssertEqual(committed.committedPrefix, "Erster Satz. ")
        XCTAssertEqual(committed.tail, "Zweiter")
    }

    func testRecentContextScopeKeepsLastTwoSentencesMutable() {
        let stabilizer = StreamingCommitStabilizer(
            stabilityThreshold: 2,
            minimumCommitExtensionLength: 1,
            rewriteScope: .recentContext
        )

        _ = stabilizer.ingestPartial("Eins. Zwei. Drei")
        let committed = stabilizer.ingestPartial("Eins. Zwei. Drei")

        XCTAssertEqual(committed.committedPrefix, "Eins. ")
        XCTAssertEqual(committed.tail, "Zwei. Drei")
    }

    func testWideContextFallsBackToCharacterBudgetWithoutSentenceBoundary() {
        let stabilizer = StreamingCommitStabilizer(
            stabilityThreshold: 2,
            minimumCommitExtensionLength: 1,
            rewriteScope: .wideContext
        )
        let longTail = String(repeating: "a", count: 340)

        _ = stabilizer.ingestPartial(longTail)
        let committed = stabilizer.ingestPartial(longTail)

        XCTAssertEqual(committed.committedPrefix.count, 20)
        XCTAssertEqual(committed.tail.count, 320)
    }
}
#endif
