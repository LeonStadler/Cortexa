import Foundation
#if os(macOS)
import ApplicationServices
#endif

public enum TextTargetPermissionState: Equatable, Sendable {
    case granted
    case denied
}

public struct AccessibilityTrustSnapshot: Equatable, Sendable {
    public let permissionState: TextTargetPermissionState
    public let probeResult: FocusedTextTargetProbeResult
    public let frontmostBundleIdentifier: String?

    public init(
        permissionState: TextTargetPermissionState,
        probeResult: FocusedTextTargetProbeResult,
        frontmostBundleIdentifier: String?
    ) {
        self.permissionState = permissionState
        self.probeResult = probeResult
        self.frontmostBundleIdentifier = frontmostBundleIdentifier
    }
}

public enum FocusedTextTargetProbeResult: Equatable, Sendable {
    case target
    case noFocusedElement(frontmostBundleIdentifier: String?)
    case unsupportedTarget(frontmostBundleIdentifier: String?, role: String?, valueSettable: Bool)
    case apiDisabled(frontmostBundleIdentifier: String?)
    case unableToReadValue(frontmostBundleIdentifier: String?)
    case probeFailed(frontmostBundleIdentifier: String?, reason: AXProbeFailureReason)
}

public enum AXProbeFailureReason: String, Equatable, Sendable {
    case cannotComplete
    case failure
    case unknown
}

public struct TextTargetSnapshot {
    public let bindingID: UUID
    public let capturedAt: Date
    public let insertionRange: NSRange
    public let capturedValue: String
    public let fallbackBundleIdentifier: String?

    #if os(macOS)
    public let element: AXUIElement
    #endif

    #if os(macOS)
    public init(
        bindingID: UUID,
        capturedAt: Date,
        insertionRange: NSRange,
        capturedValue: String,
        fallbackBundleIdentifier: String?,
        element: AXUIElement
    ) {
        self.bindingID = bindingID
        self.capturedAt = capturedAt
        self.insertionRange = insertionRange
        self.capturedValue = capturedValue
        self.fallbackBundleIdentifier = fallbackBundleIdentifier
        self.element = element
    }
    #else
    public init(
        bindingID: UUID,
        capturedAt: Date,
        insertionRange: NSRange,
        capturedValue: String,
        fallbackBundleIdentifier: String?
    ) {
        self.bindingID = bindingID
        self.capturedAt = capturedAt
        self.insertionRange = insertionRange
        self.capturedValue = capturedValue
        self.fallbackBundleIdentifier = fallbackBundleIdentifier
    }
    #endif
}

public protocol TextTargetResolver {
    func snapshotFocusedTarget() throws -> TextTargetSnapshot
}

public protocol TextInserter {
    func insertFinalize(_ text: String, into target: TextTargetSnapshot) throws
    func applyStreamingPatch(committed: String, tail: String, into target: TextTargetSnapshot) throws
}
