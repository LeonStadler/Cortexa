import Foundation
#if os(macOS)
import ApplicationServices
#endif

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
