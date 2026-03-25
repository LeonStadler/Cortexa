import Foundation

public enum SessionMode: String, Sendable {
    case finalizeInsert
    case streamingInsert
}

public enum SessionState: Equatable, Sendable {
    case idle
    case armingTarget
    case recording
    case transcribingStreaming
    case finalizing
    case inserting
    case completed
    case error(recoverable: Bool, message: String)
}

public enum SessionEvent: Sendable {
    case startRequested(mode: SessionMode)
    case targetCaptured(bindingID: UUID)
    case audioChunk
    case partialSegment(text: String)
    case stableCommit(committedPrefix: String, tail: String)
    case stopRequested
    case finalSegment(text: String)
    case insertSucceeded(operationID: UUID)
    case insertFailed(operationID: UUID, reason: String)
    case permissionChanged(granted: Bool)
    case audioInterrupted(reason: String)
}

public struct SessionSnapshot: Sendable {
    public let state: SessionState
    public let mode: SessionMode?
    public let targetBindingID: UUID?
    public let committedText: String
    public let uncommittedTail: String

    public init(state: SessionState, mode: SessionMode?, targetBindingID: UUID?, committedText: String, uncommittedTail: String) {
        self.state = state
        self.mode = mode
        self.targetBindingID = targetBindingID
        self.committedText = committedText
        self.uncommittedTail = uncommittedTail
    }
}

public final class TranscriptionSessionStateMachine {
    public private(set) var state: SessionState = .idle
    public private(set) var mode: SessionMode?
    public private(set) var targetBindingID: UUID?
    public private(set) var committedText: String = ""
    public private(set) var uncommittedTail: String = ""

    private var insertedOperationIDs: Set<UUID> = []

    public init() {}

    public func handle(_ event: SessionEvent) {
        switch event {
        case let .startRequested(mode):
            guard case .idle = state else { return }
            self.mode = mode
            committedText = ""
            uncommittedTail = ""
            targetBindingID = nil
            insertedOperationIDs.removeAll()
            state = .armingTarget

        case let .targetCaptured(bindingID):
            guard case .armingTarget = state else { return }
            // Target binding becomes immutable for this session.
            targetBindingID = targetBindingID ?? bindingID
            state = .recording

        case .audioChunk:
            if case .recording = state {
                if mode == .streamingInsert {
                    state = .transcribingStreaming
                }
            }

        case let .partialSegment(text):
            guard case .transcribingStreaming = state else { return }
            uncommittedTail = text

        case let .stableCommit(committedPrefix, tail):
            guard case .transcribingStreaming = state else { return }
            if committedPrefix.count >= committedText.count,
               committedPrefix.hasPrefix(committedText) {
                committedText = committedPrefix
            }
            uncommittedTail = tail

        case .stopRequested:
            switch state {
            case .recording, .transcribingStreaming:
                state = .finalizing
            default:
                break
            }

        case let .finalSegment(text):
            guard case .finalizing = state else { return }
            if mode == .streamingInsert {
                uncommittedTail = text
            } else {
                committedText = text
                uncommittedTail = ""
            }
            state = .inserting

        case let .insertSucceeded(operationID):
            guard case .inserting = state else { return }
            guard !insertedOperationIDs.contains(operationID) else {
                return
            }
            insertedOperationIDs.insert(operationID)
            state = .completed

        case let .insertFailed(operationID, reason):
            guard case .inserting = state else { return }
            guard !insertedOperationIDs.contains(operationID) else {
                return
            }
            state = .error(recoverable: true, message: reason)

        case let .permissionChanged(granted):
            if !granted {
                state = .error(recoverable: true, message: "Required permission was revoked")
            }

        case let .audioInterrupted(reason):
            if state == .recording || state == .transcribingStreaming {
                state = .error(recoverable: true, message: "Audio interruption: \(reason)")
            }
        }
    }

    public func reset() {
        state = .idle
        mode = nil
        targetBindingID = nil
        committedText = ""
        uncommittedTail = ""
        insertedOperationIDs.removeAll()
    }

    public func snapshot() -> SessionSnapshot {
        SessionSnapshot(
            state: state,
            mode: mode,
            targetBindingID: targetBindingID,
            committedText: committedText,
            uncommittedTail: uncommittedTail
        )
    }
}
