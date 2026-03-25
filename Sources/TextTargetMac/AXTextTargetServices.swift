import Foundation

#if os(macOS)
import AppKit
import ApplicationServices

private func runOnMainThread<T>(_ work: () throws -> T) throws -> T {
    if Thread.isMainThread {
        return try work()
    }

    return try DispatchQueue.main.sync(execute: work)
}

public enum TextTargetError: Error, LocalizedError {
    case accessibilityDenied
    case unsupportedFocusedElement
    case unableToReadValue
    case unableToWriteValue
    case unsafeClipboardFallback

    public var errorDescription: String? {
        switch self {
        case .accessibilityDenied:
            return "Accessibility permission is required."
        case .unsupportedFocusedElement:
            return "Focused element is not a supported text input target."
        case .unableToReadValue:
            return "Failed to read focused text value."
        case .unableToWriteValue:
            return "Failed to write text value to the target element."
        case .unsafeClipboardFallback:
            return "Clipboard fallback was blocked because the original target app is no longer frontmost."
        }
    }
}

public final class AXTextTargetResolver: TextTargetResolver {
    public init() {}

    public func snapshotFocusedTarget() throws -> TextTargetSnapshot {
        try runOnMainThread {
            guard AXIsProcessTrusted() else {
                throw TextTargetError.accessibilityDenied
            }

            let systemWide = AXUIElementCreateSystemWide()
            var focused: CFTypeRef?
            let focusedResult = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focused)
            guard focusedResult == .success, let focusedElement = focused else {
                throw TextTargetError.unsupportedFocusedElement
            }

            let element = focusedElement as! AXUIElement

            var valueRef: CFTypeRef?
            let valueResult = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef)
            let value = (valueResult == .success ? valueRef as? String : nil) ?? ""

            var selectedRangeRef: CFTypeRef?
            let rangeResult = AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &selectedRangeRef)

            let selection: NSRange
            if rangeResult == .success,
               let selectedRangeRef,
               CFGetTypeID(selectedRangeRef) == AXValueGetTypeID() {
                let axValue = selectedRangeRef as! AXValue
                var range = CFRange()
                if AXValueGetType(axValue) == .cfRange, AXValueGetValue(axValue, .cfRange, &range) {
                    selection = NSRange(location: max(0, range.location), length: max(0, range.length))
                } else {
                    selection = NSRange(location: value.count, length: 0)
                }
            } else {
                selection = NSRange(location: value.count, length: 0)
            }

            let app = NSWorkspace.shared.frontmostApplication

            return TextTargetSnapshot(
                bindingID: UUID(),
                capturedAt: Date(),
                insertionRange: selection,
                capturedValue: value,
                fallbackBundleIdentifier: app?.bundleIdentifier,
                element: element
            )
        }
    }
}

public final class AXTextInserter: TextInserter {
    private let useClipboardFallback: Bool
    private let allowUnsafeStreamingClipboardFallback: Bool
    private var insertedLengthByBinding: [UUID: Int] = [:]

    public init(useClipboardFallback: Bool = true, allowUnsafeStreamingClipboardFallback: Bool = false) {
        self.useClipboardFallback = useClipboardFallback
        self.allowUnsafeStreamingClipboardFallback = allowUnsafeStreamingClipboardFallback
    }

    public func insertFinalize(_ text: String, into target: TextTargetSnapshot) throws {
        if try replaceInValue(text: text, into: target, replaceLength: target.insertionRange.length) {
            insertedLengthByBinding[target.bindingID] = text.count
            return
        }

        if useClipboardFallback {
            try pasteWithClipboard(text, target: target)
            insertedLengthByBinding[target.bindingID] = text.count
            return
        }

        throw TextTargetError.unableToWriteValue
    }

    public func applyStreamingPatch(committed: String, tail: String, into target: TextTargetSnapshot) throws {
        let desired = committed + tail
        let previousLength = insertedLengthByBinding[target.bindingID] ?? target.insertionRange.length

        if try replaceInValue(text: desired, into: target, replaceLength: previousLength) {
            insertedLengthByBinding[target.bindingID] = desired.count
            return
        }

        if useClipboardFallback, allowUnsafeStreamingClipboardFallback {
            try pasteWithClipboard(desired, target: target)
            insertedLengthByBinding[target.bindingID] = desired.count
            return
        }

        throw TextTargetError.unableToWriteValue
    }

    private func replaceInValue(text: String, into target: TextTargetSnapshot, replaceLength: Int) throws -> Bool {
        try runOnMainThread {
            var valueRef: CFTypeRef?
            let readResult = AXUIElementCopyAttributeValue(target.element, kAXValueAttribute as CFString, &valueRef)
            guard readResult == .success else {
                throw TextTargetError.unableToReadValue
            }

            let currentValue = (valueRef as? String) ?? ""
            let location = min(max(0, target.insertionRange.location), currentValue.count)
            let upperBound = min(location + max(0, replaceLength), currentValue.count)

            let startIndex = currentValue.index(currentValue.startIndex, offsetBy: location)
            let endIndex = currentValue.index(currentValue.startIndex, offsetBy: upperBound)

            var updatedValue = currentValue
            updatedValue.replaceSubrange(startIndex..<endIndex, with: text)

            let setResult = AXUIElementSetAttributeValue(target.element, kAXValueAttribute as CFString, updatedValue as CFTypeRef)
            guard setResult == .success else {
                return false
            }

            let newCursor = location + text.count
            var range = CFRange(location: newCursor, length: 0)
            if let axRange = AXValueCreate(.cfRange, &range) {
                _ = AXUIElementSetAttributeValue(target.element, kAXSelectedTextRangeAttribute as CFString, axRange)
            }

            return true
        }
    }

    private func pasteWithClipboard(_ text: String, target: TextTargetSnapshot) throws {
        try runOnMainThread {
            if let expectedBundleIdentifier = target.fallbackBundleIdentifier {
                let frontmostBundleIdentifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
                guard frontmostBundleIdentifier == expectedBundleIdentifier else {
                    throw TextTargetError.unsafeClipboardFallback
                }
            }

            let pasteboard = NSPasteboard.general
            let previous = pasteboard.string(forType: .string)

            pasteboard.clearContents()

            defer {
                usleep(50_000)
                pasteboard.clearContents()
                if let previous {
                    pasteboard.setString(previous, forType: .string)
                }
            }

            pasteboard.setString(text, forType: .string)

            guard let source = CGEventSource(stateID: .hidSystemState) else {
                throw TextTargetError.unableToWriteValue
            }

            let vDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
            vDown?.flags = .maskCommand
            let vUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
            vUp?.flags = .maskCommand

            vDown?.post(tap: .cghidEventTap)
            vUp?.post(tap: .cghidEventTap)
        }
    }
}

#else

public enum TextTargetError: Error {
    case unsupportedPlatform
}

public final class AXTextTargetResolver: TextTargetResolver {
    public init() {}

    public func snapshotFocusedTarget() throws -> TextTargetSnapshot {
        throw TextTargetError.unsupportedPlatform
    }
}

public final class AXTextInserter: TextInserter {
    public init(useClipboardFallback: Bool = true, allowUnsafeStreamingClipboardFallback: Bool = false) {
        _ = useClipboardFallback
        _ = allowUnsafeStreamingClipboardFallback
    }

    public func insertFinalize(_ text: String, into target: TextTargetSnapshot) throws {
        _ = text
        _ = target
        throw TextTargetError.unsupportedPlatform
    }

    public func applyStreamingPatch(committed: String, tail: String, into target: TextTargetSnapshot) throws {
        _ = committed
        _ = tail
        _ = target
        throw TextTargetError.unsupportedPlatform
    }
}

#endif
