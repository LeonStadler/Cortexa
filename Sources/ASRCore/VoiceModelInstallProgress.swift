import Foundation

public struct VoiceModelInstallProgress: Sendable, Equatable {
    public enum Phase: String, Sendable, Equatable {
        case preparing
        case downloading
        case finalizing
    }

    public let phase: Phase
    public let fractionCompleted: Double
    public let receivedBytes: Int64?
    public let totalBytes: Int64?
    public let isIndeterminate: Bool

    public init(
        phase: Phase,
        fractionCompleted: Double,
        receivedBytes: Int64? = nil,
        totalBytes: Int64? = nil,
        isIndeterminate: Bool = false
    ) {
        self.phase = phase
        self.fractionCompleted = min(max(fractionCompleted, 0), 1)
        self.receivedBytes = receivedBytes
        self.totalBytes = totalBytes
        self.isIndeterminate = isIndeterminate
    }

    public var percentComplete: Int {
        Int((fractionCompleted * 100).rounded(.down))
    }
}

public enum VoiceModelOperationKind: Sendable, Equatable {
    case installing(VoiceModelInstallProgress)
    case removing
}
