#if canImport(XCTest)
import Foundation
import XCTest
@testable import SessionCore

final class SessionStateMachineTests: XCTestCase {
    func testTargetBindingImmutable() {
        let machine = TranscriptionSessionStateMachine()
        machine.handle(.startRequested(mode: .streamingInsert))

        let first = UUID()
        let second = UUID()

        machine.handle(.targetCaptured(bindingID: first))
        machine.handle(.targetCaptured(bindingID: second))

        XCTAssertEqual(machine.targetBindingID, first)
    }

    func testCommittedTextAppendOnly() {
        let machine = TranscriptionSessionStateMachine()
        machine.handle(.startRequested(mode: .streamingInsert))
        machine.handle(.targetCaptured(bindingID: UUID()))
        machine.handle(.audioChunk)

        machine.handle(.stableCommit(committedPrefix: "hello", tail: " wor"))
        machine.handle(.stableCommit(committedPrefix: "hel", tail: " x"))

        XCTAssertEqual(machine.committedText, "hello")
        XCTAssertEqual(machine.uncommittedTail, " x")
    }

    func testInsertIdempotent() {
        let machine = TranscriptionSessionStateMachine()
        machine.handle(.startRequested(mode: .finalizeInsert))
        machine.handle(.targetCaptured(bindingID: UUID()))
        machine.handle(.stopRequested)
        machine.handle(.finalSegment(text: "done"))

        let operationID = UUID()
        machine.handle(.insertSucceeded(operationID: operationID))
        machine.handle(.insertFailed(operationID: operationID, reason: "should be ignored"))

        XCTAssertEqual(machine.state, .completed)
    }

    func testFinalSegmentStreamingKeepsUncommittedTail() {
        let machine = TranscriptionSessionStateMachine()
        machine.handle(.startRequested(mode: .streamingInsert))
        machine.handle(.targetCaptured(bindingID: UUID()))
        machine.handle(.stopRequested)
        machine.handle(.finalSegment(text: "tail"))

        XCTAssertEqual(machine.state, .inserting)
        XCTAssertEqual(machine.committedText, "")
        XCTAssertEqual(machine.uncommittedTail, "tail")
    }

    func testFinalSegmentFinalizeModeStoresCommittedText() {
        let machine = TranscriptionSessionStateMachine()
        machine.handle(.startRequested(mode: .finalizeInsert))
        machine.handle(.targetCaptured(bindingID: UUID()))
        machine.handle(.stopRequested)
        machine.handle(.finalSegment(text: "payload"))

        XCTAssertEqual(machine.state, .inserting)
        XCTAssertEqual(machine.committedText, "payload")
        XCTAssertEqual(machine.uncommittedTail, "")
    }

    func testPermissionRevocationCreatesRecoverableError() {
        let machine = TranscriptionSessionStateMachine()
        machine.handle(.startRequested(mode: .streamingInsert))
        machine.handle(.permissionChanged(granted: false))

        XCTAssertEqual(machine.state, .error(recoverable: true, message: "Required permission was revoked"))
    }

    func testAudioInterruptionDuringTranscribingSetsErrorState() {
        let machine = TranscriptionSessionStateMachine()
        machine.handle(.startRequested(mode: .streamingInsert))
        machine.handle(.targetCaptured(bindingID: UUID()))
        machine.handle(.audioChunk)

        machine.handle(.audioInterrupted(reason: "noise"))

        XCTAssertEqual(machine.state, .error(recoverable: true, message: "Audio interruption: noise"))
    }

    func testResetClearsInsertedOperationIDsForNextSession() {
        let machine = TranscriptionSessionStateMachine()
        let operationID = UUID()

        machine.handle(.startRequested(mode: .finalizeInsert))
        machine.handle(.targetCaptured(bindingID: UUID()))
        machine.handle(.stopRequested)
        machine.handle(.finalSegment(text: "done"))
        machine.handle(.insertSucceeded(operationID: operationID))

        machine.reset()

        machine.handle(.startRequested(mode: .finalizeInsert))
        machine.handle(.targetCaptured(bindingID: UUID()))
        machine.handle(.stopRequested)
        machine.handle(.finalSegment(text: "done again"))
        machine.handle(.insertSucceeded(operationID: operationID))

        XCTAssertEqual(machine.state, .completed)
    }
}
#endif
