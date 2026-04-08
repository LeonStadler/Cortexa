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

private enum AXFocusedElementProbe {
    case element(AXUIElement)
    case noFocusedElement(frontmostBundleIdentifier: String?)
    case apiDisabled(frontmostBundleIdentifier: String?)
}

private enum AXAccessEvaluator {
    static func permissionState(promptIfNeeded: Bool = false) -> TextTargetPermissionState {
        let granted = (try? runOnMainThread {
            if AXIsProcessTrusted() {
                return true
            }

            let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
            let options = [promptKey: promptIfNeeded] as CFDictionary
            if AXIsProcessTrustedWithOptions(options) {
                return true
            }

            let probe = focusedElementProbe()
            switch probe {
            case .element, .noFocusedElement:
                return true
            case .apiDisabled:
                return false
            }
        }) ?? false

        return granted ? .granted : .denied
    }

    static func probeFocusedTarget() -> (FocusedTextTargetProbeResult, TextTargetSnapshot?) {
        do {
            return try runOnMainThread {
                let probe = focusedElementProbe()
                switch probe {
                case .apiDisabled(let frontmostBundleIdentifier):
                    return (.apiDisabled(frontmostBundleIdentifier: frontmostBundleIdentifier), nil)
                case .noFocusedElement(let frontmostBundleIdentifier):
                    return (
                        .noFocusedElement(frontmostBundleIdentifier: frontmostBundleIdentifier), nil
                    )
                case .element(let element):
                    var roleRef: CFTypeRef?
                    let roleResult = AXUIElementCopyAttributeValue(
                        element,
                        kAXRoleAttribute as CFString,
                        &roleRef
                    )
                    let role = roleResult == .success ? roleRef as? String : nil

                    var isValueSettable = DarwinBoolean(false)
                    let settableResult = AXUIElementIsAttributeSettable(
                        element,
                        kAXValueAttribute as CFString,
                        &isValueSettable
                    )
                    guard settableResult == .success, isValueSettable.boolValue else {
                        return (
                            .unsupportedTarget(
                                frontmostBundleIdentifier: NSWorkspace.shared.frontmostApplication?
                                    .bundleIdentifier,
                                role: role,
                                valueSettable: isValueSettable.boolValue
                            ),
                            nil
                        )
                    }

                    var valueRef: CFTypeRef?
                    let valueResult = AXUIElementCopyAttributeValue(
                        element,
                        kAXValueAttribute as CFString,
                        &valueRef
                    )
                    guard valueResult == .success else {
                        return (
                            .unableToReadValue(
                                frontmostBundleIdentifier: NSWorkspace.shared.frontmostApplication?
                                    .bundleIdentifier),
                            nil
                        )
                    }

                    let value = (valueRef as? String) ?? ""
                    let selection = selectedRange(from: element, currentValueLength: value.count)

                    var owningPID: pid_t = 0
                    let owningPIDResult = AXUIElementGetPid(element, &owningPID)
                    let app =
                        owningPIDResult == .success
                        ? NSRunningApplication(processIdentifier: owningPID)
                        : NSWorkspace.shared.frontmostApplication

                    let snapshot = TextTargetSnapshot(
                        bindingID: UUID(),
                        capturedAt: Date(),
                        insertionRange: selection,
                        capturedValue: value,
                        fallbackBundleIdentifier: app?.bundleIdentifier,
                        element: element
                    )
                    return (.target, snapshot)
                }
            }
        } catch {
            return (
                .unableToReadValue(
                    frontmostBundleIdentifier: NSWorkspace.shared.frontmostApplication?
                        .bundleIdentifier),
                nil
            )
        }
    }

    private static func focusedElementProbe() -> AXFocusedElementProbe {
        let systemWide = AXUIElementCreateSystemWide()
        let frontmostBundleIdentifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier

        var focused: CFTypeRef?
        let focusedResult = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focused
        )

        switch focusedResult {
        case .success:
            if let focused {
                return .element(focused as! AXUIElement)
            }
            return .noFocusedElement(frontmostBundleIdentifier: frontmostBundleIdentifier)
        case .apiDisabled:
            return .apiDisabled(frontmostBundleIdentifier: frontmostBundleIdentifier)
        case .noValue, .cannotComplete, .failure:
            return .noFocusedElement(frontmostBundleIdentifier: frontmostBundleIdentifier)
        default:
            return .noFocusedElement(frontmostBundleIdentifier: frontmostBundleIdentifier)
        }
    }

    private static func selectedRange(from element: AXUIElement, currentValueLength: Int) -> NSRange {
        var selectedRangeRef: CFTypeRef?
        let rangeResult = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &selectedRangeRef
        )

        if rangeResult == .success,
            let selectedRangeRef,
            CFGetTypeID(selectedRangeRef) == AXValueGetTypeID()
        {
            let axValue = selectedRangeRef as! AXValue
            var range = CFRange()
            if AXValueGetType(axValue) == .cfRange, AXValueGetValue(axValue, .cfRange, &range) {
                return NSRange(location: max(0, range.location), length: max(0, range.length))
            }
        }

        return NSRange(location: currentValueLength, length: 0)
    }
}

public enum TextTargetError: Error, LocalizedError {
    case accessibilityDenied
    case unsupportedFocusedElement(role: String?)
    case focusedElementUnavailable
    case unableToReadValue
    case unableToWriteValue
    case unsafeClipboardFallback

    public var errorDescription: String? {
        switch self {
        case .accessibilityDenied:
            return "Accessibility permission is required."
        case .unsupportedFocusedElement(let role):
            if let role, !role.isEmpty {
                return "Focused element role \(role) is not a supported text input target."
            }
            return "Focused element is not a supported text input target."
        case .focusedElementUnavailable:
            return "No focused text input target is currently available."
        case .unableToReadValue:
            return "Failed to read focused text value."
        case .unableToWriteValue:
            return "Failed to write text value to the target element."
        case .unsafeClipboardFallback:
            return "Clipboard fallback was blocked because the original target app is no longer frontmost."
        }
    }
}

public enum AXTextAccess {
    public static func permissionState(promptIfNeeded: Bool = false) -> TextTargetPermissionState {
        AXAccessEvaluator.permissionState(promptIfNeeded: promptIfNeeded)
    }

    public static func probeFocusedTarget() -> FocusedTextTargetProbeResult {
        AXAccessEvaluator.probeFocusedTarget().0
    }
}

public final class AXTextTargetResolver: TextTargetResolver {
    public init() {}

    public func snapshotFocusedTarget() throws -> TextTargetSnapshot {
        let (probeResult, snapshot) = AXAccessEvaluator.probeFocusedTarget()
        switch probeResult {
        case .target:
            guard let snapshot else {
                throw TextTargetError.focusedElementUnavailable
            }
            return snapshot
        case .apiDisabled:
            throw TextTargetError.accessibilityDenied
        case .noFocusedElement:
            throw TextTargetError.focusedElementUnavailable
        case .unsupportedTarget(_, let role, _):
            throw TextTargetError.unsupportedFocusedElement(role: role)
        case .unableToReadValue:
            throw TextTargetError.unableToReadValue
        }
    }
}

private struct PasteboardSnapshot {
    let items: [NSPasteboardItem]

    static func capture(from pasteboard: NSPasteboard) -> PasteboardSnapshot {
        let copiedItems =
            pasteboard.pasteboardItems?.compactMap { item in
                item.copy() as? NSPasteboardItem
            } ?? []
        return PasteboardSnapshot(items: copiedItems)
    }

    var isEmpty: Bool {
        items.isEmpty
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        guard !items.isEmpty else { return }
        pasteboard.writeObjects(items)
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
            let previousSnapshot = PasteboardSnapshot.capture(from: pasteboard)

            pasteboard.clearContents()

            defer {
                usleep(50_000)
                previousSnapshot.restore(to: pasteboard)
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

public enum AXTextAccess {
    public static func permissionState(promptIfNeeded: Bool = false) -> TextTargetPermissionState {
        _ = promptIfNeeded
        return .denied
    }

    public static func probeFocusedTarget() -> FocusedTextTargetProbeResult {
        .apiDisabled(frontmostBundleIdentifier: nil)
    }
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
