import AIProcessingCore
import AppKit
import ApplicationServices
import AVFoundation
import Carbon
import Foundation
import TextTargetMac

private func runOnMainThread<T>(_ work: () throws -> T) rethrows -> T {
    if Thread.isMainThread {
        return try work()
    }

    return try DispatchQueue.main.sync(execute: work)
}

internal struct LockedTextTarget {
    let element: AXUIElement
    let insertionLocation: Int
    let originalSelectedLength: Int
    let fallbackBundleIdentifier: String?
    let prefersKeyboardInsertion: Bool
    var insertedLength: Int
}

internal struct FinalInsertionMetrics {
    let path: String
    let clipboardRestored: Bool
    let autoSent: Bool
}

internal struct RuntimePermissionService {
    func requestMicrophonePermission() async -> Bool {
        #if os(macOS)
            let status = AVCaptureDevice.authorizationStatus(for: .audio)
            if status == .authorized {
                return true
            }
        #endif

        return await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    func requestAccessibilityPermission(promptIfNeeded: Bool) -> Bool {
        let options: CFDictionary =
            promptIfNeeded
            ? [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            : [:] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}

internal struct FocusedTextTargetService {
    private let pendingInsertionTimeoutNanoseconds: UInt64 = 5_000_000_000
    private let pendingInsertionPollNanoseconds: UInt64 = 150_000_000

    func captureFocusedTextTarget() throws -> LockedTextTarget {
        do {
            let snapshot = try AXTextTargetResolver().snapshotFocusedTarget()
            return makeLockedTextTarget(from: snapshot)
        } catch let error as TextTargetError {
            let frontmostBundleIdentifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            switch error {
            case .accessibilityDenied:
                AgentSessionDebugLog.append(
                    hypothesisId: "H3",
                    location: "DictationRuntime.captureFocusedTextTarget",
                    message: "ax_api_disabled",
                    data: [
                        "frontmostBundle": frontmostBundleIdentifier ?? "nil"
                    ]
                )
                throw DictationRuntimeError.accessibilityPermissionDenied
            case .unsupportedFocusedElement:
                AgentSessionDebugLog.append(
                    hypothesisId: "H4",
                    location: "DictationRuntime.captureFocusedTextTarget",
                    message: "validate_editable_failed",
                    data: [
                        "frontmostBundle": frontmostBundleIdentifier ?? "nil"
                    ]
                )
                throw DictationRuntimeError.unsupportedTextTarget
            case .unableToReadValue, .focusedElementUnavailable:
                AgentSessionDebugLog.append(
                    hypothesisId: "H4",
                    location: "DictationRuntime.captureFocusedTextTarget",
                    message: "read_value_failed",
                    data: [
                        "frontmostBundle": frontmostBundleIdentifier ?? "nil"
                    ]
                )
                throw DictationRuntimeError.focusedElementUnavailable
            case .unableToWriteValue, .unsafeClipboardFallback:
                throw DictationRuntimeError.focusedElementUnavailable
            }
        } catch {
            let frontmostBundleIdentifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            AgentSessionDebugLog.append(
                hypothesisId: "H3",
                location: "DictationRuntime.captureFocusedTextTarget",
                message: "ax_probe_failed",
                data: [
                    "frontmostBundle": frontmostBundleIdentifier ?? "nil"
                ]
            )
            throw DictationRuntimeError.accessibilityPermissionDenied
        }
    }

    func refreshLockedTextTarget(_ target: LockedTextTarget) throws -> LockedTextTarget {
        try runOnMainThread {
            if let expectedBundleIdentifier = target.fallbackBundleIdentifier,
                NSWorkspace.shared.frontmostApplication?.bundleIdentifier
                    != expectedBundleIdentifier
            {
                throw DictationRuntimeError.focusedElementUnavailable
            }

            var isValueSettable = DarwinBoolean(false)
            let settableResult = AXUIElementIsAttributeSettable(
                target.element, kAXValueAttribute as CFString, &isValueSettable)
            guard settableResult == .success, isValueSettable.boolValue else {
                throw DictationRuntimeError.unsupportedTextTarget
            }

            var valueRef: CFTypeRef?
            let readResult = AXUIElementCopyAttributeValue(
                target.element, kAXValueAttribute as CFString, &valueRef)
            guard readResult == .success else {
                throw DictationRuntimeError.focusedElementUnavailable
            }

            let currentValue = (valueRef as? String) ?? ""
            let range = readSelectedRange(for: target.element, currentValueLength: currentValue.count)

            return LockedTextTarget(
                element: target.element,
                insertionLocation: range.location,
                originalSelectedLength: range.length,
                fallbackBundleIdentifier: target.fallbackBundleIdentifier,
                prefersKeyboardInsertion: target.prefersKeyboardInsertion,
                insertedLength: max(range.length, target.insertedLength)
            )
        }
    }

    func resolveAvailableTextTarget(
        currentTarget: LockedTextTarget?,
        captureFocusedTextTarget: () throws -> LockedTextTarget,
        captureFocusedTargetForPasteFallback: () -> LockedTextTarget?,
        refreshLockedTextTarget: (LockedTextTarget) throws -> LockedTextTarget
    ) -> LockedTextTarget? {
        if let currentTarget,
            let refreshed = try? refreshLockedTextTarget(currentTarget)
        {
            return refreshed
        }
        if let focused = try? captureFocusedTextTarget() {
            return focused
        }
        if let fallbackFocused = captureFocusedTargetForPasteFallback() {
            return fallbackFocused
        }
        return nil
    }

    func waitForAvailableTextTarget(
        timeoutNanoseconds: UInt64,
        pollNanoseconds: UInt64 = 150_000_000,
        resolveAvailableTextTarget: () -> LockedTextTarget?
    ) async -> LockedTextTarget? {
        let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
        while DispatchTime.now().uptimeNanoseconds < deadline {
            if let target = resolveAvailableTextTarget() {
                return target
            }
            try? await Task.sleep(nanoseconds: pollNanoseconds)
        }
        return nil
    }

    private func makeLockedTextTarget(from snapshot: TextTargetSnapshot) -> LockedTextTarget {
        LockedTextTarget(
            element: snapshot.element,
            insertionLocation: snapshot.insertionRange.location,
            originalSelectedLength: snapshot.insertionRange.length,
            fallbackBundleIdentifier: snapshot.fallbackBundleIdentifier,
            prefersKeyboardInsertion: false,
            insertedLength: snapshot.insertionRange.length
        )
    }

    /// Captures the current focused AX element even when it is not value-settable.
    /// This allows downstream Cmd+V fallback insertion for editors that reject AX value writes
    /// (e.g. some IDE/Electron text controls).
    func captureFocusedTargetForPasteFallback() -> LockedTextTarget? {
        runOnMainThread {
            let systemWide = AXUIElementCreateSystemWide()
            var focused: CFTypeRef?
            let focusedResult = AXUIElementCopyAttributeValue(
                systemWide,
                kAXFocusedUIElementAttribute as CFString,
                &focused
            )
            guard focusedResult == .success, let focused else {
                return nil
            }

            let focusedElement = unsafeBitCast(focused, to: AXUIElement.self)

            var valueRef: CFTypeRef?
            let readValueResult = AXUIElementCopyAttributeValue(
                focusedElement,
                kAXValueAttribute as CFString,
                &valueRef
            )
            let currentValueLength: Int
            if readValueResult == .success {
                currentValueLength = ((valueRef as? String) ?? "").count
            } else {
                currentValueLength = 0
            }

            let selectedRange = readSelectedRange(
                for: focusedElement,
                currentValueLength: currentValueLength
            )

            return LockedTextTarget(
                element: focusedElement,
                insertionLocation: selectedRange.location,
                originalSelectedLength: selectedRange.length,
                fallbackBundleIdentifier: NSWorkspace.shared.frontmostApplication?
                    .bundleIdentifier,
                prefersKeyboardInsertion: true,
                insertedLength: max(0, selectedRange.length)
            )
        }
    }

    private func readSelectedRange(for element: AXUIElement, currentValueLength: Int) -> CFRange {
        var selectedRangeRef: CFTypeRef?
        let rangeResult = AXUIElementCopyAttributeValue(
            element, kAXSelectedTextRangeAttribute as CFString, &selectedRangeRef)

        if rangeResult == .success,
            let selectedRangeRef,
            CFGetTypeID(selectedRangeRef) == AXValueGetTypeID()
        {
            let axValue = selectedRangeRef as! AXValue
            var range = CFRange()
            if AXValueGetType(axValue) == .cfRange, AXValueGetValue(axValue, .cfRange, &range) {
                return CFRange(location: max(0, range.location), length: max(0, range.length))
            }
        }

        return CFRange(location: currentValueLength, length: 0)
    }
}

internal struct StreamingTextInsertionService {
    func streamingPreservedPrefixLength(
        previousText: String, newText: String, maximumMutableCharacterCount: Int
    ) -> Int {
        guard !previousText.isEmpty, !newText.isEmpty else { return 0 }

        let commonPrefixLength = sharedPrefixLength(previousText, newText)
        let hardFloor = max(0, previousText.count - max(0, maximumMutableCharacterCount))
        return min(newText.count, max(commonPrefixLength, hardFloor))
    }

    func replaceInsertedText(
        _ text: String,
        in lockedTarget: LockedTextTarget,
        allowFallbackPaste: Bool,
        preservingPrefixLength: Int = 0,
        restoreClipboardAfterPaste: Bool,
        onTargetUpdated: (LockedTextTarget) -> Void
    ) throws -> (path: String, clipboardRestored: Bool) {
        try runOnMainThread {
            var valueRef: CFTypeRef?
            let readResult = AXUIElementCopyAttributeValue(
                lockedTarget.element, kAXValueAttribute as CFString, &valueRef)
            if readResult != .success {
                if allowFallbackPaste {
                    let replacementRange = CFRange(
                        location: max(0, lockedTarget.insertionLocation),
                        length: max(0, lockedTarget.insertedLength)
                    )
                    let clipboardRestored = try pasteIntoFallbackTarget(
                        lockedTarget,
                        text: text,
                        replacementRange: replacementRange,
                        restoreClipboard: restoreClipboardAfterPaste
                    )
                    var updated = lockedTarget
                    updated.insertedLength = text.count
                    onTargetUpdated(updated)
                    return ("clipboardPaste", clipboardRestored)
                }
                throw DictationRuntimeError.focusedElementUnavailable
            }

            let currentValue = (valueRef as? String) ?? ""
            let location = min(max(0, lockedTarget.insertionLocation), currentValue.count)
            let preservedLength = Swift.min(
                Swift.min(max(0, preservingPrefixLength), text.count),
                Swift.min(lockedTarget.insertedLength, max(0, currentValue.count - location))
            )
            let replacementStart = min(location + preservedLength, currentValue.count)
            let replacementEnd = min(
                location + max(0, lockedTarget.insertedLength), currentValue.count)

            let startIndex = currentValue.index(currentValue.startIndex, offsetBy: replacementStart)
            let endIndex = currentValue.index(currentValue.startIndex, offsetBy: replacementEnd)

            var updatedValue = currentValue
            updatedValue.replaceSubrange(
                startIndex..<endIndex, with: String(text.dropFirst(preservedLength)))

            let setResult = AXUIElementSetAttributeValue(
                lockedTarget.element, kAXValueAttribute as CFString, updatedValue as CFTypeRef)
            if setResult != .success {
                if allowFallbackPaste {
                    let replacementRange = CFRange(
                        location: replacementStart,
                        length: max(0, replacementEnd - replacementStart)
                    )
                    let clipboardRestored = try pasteIntoFallbackTarget(
                        lockedTarget,
                        text: String(text.dropFirst(preservedLength)),
                        replacementRange: replacementRange,
                        restoreClipboard: restoreClipboardAfterPaste
                    )
                    var updated = lockedTarget
                    updated.insertedLength = text.count
                    onTargetUpdated(updated)
                    return ("clipboardPaste", clipboardRestored)
                }
                throw DictationRuntimeError.focusedElementUnavailable
            }

            var updatedTarget = lockedTarget
            updatedTarget.insertedLength = text.count
            onTargetUpdated(updatedTarget)

            let newCursor = location + text.count
            var range = CFRange(location: newCursor, length: 0)
            if let axRange = AXValueCreate(.cfRange, &range) {
                _ = AXUIElementSetAttributeValue(
                    lockedTarget.element, kAXSelectedTextRangeAttribute as CFString, axRange)
            }
            return ("axValueSet", false)
        }
    }

    func pasteIntoFallbackTarget(
        _ target: LockedTextTarget, text: String, restoreClipboard: Bool
    ) throws -> Bool {
        try pasteIntoFallbackTarget(
            target,
            text: text,
            replacementRange: nil,
            restoreClipboard: restoreClipboard
        )
    }

    private func pasteIntoFallbackTarget(
        _ target: LockedTextTarget,
        text: String,
        replacementRange: CFRange?,
        restoreClipboard: Bool
    ) throws -> Bool {
        if let expectedBundleIdentifier = target.fallbackBundleIdentifier {
            let frontmostBundleIdentifier = NSWorkspace.shared.frontmostApplication?
                .bundleIdentifier
            guard frontmostBundleIdentifier == expectedBundleIdentifier else {
                throw DictationRuntimeError.unsafePasteFallback
            }
        }

        if let replacementRange {
            setSelectedRange(replacementRange, for: target.element)
        }

        let pasteboard = NSPasteboard.general
        let previousSnapshot = PasteboardSnapshot.capture(from: pasteboard)

        defer {
            if restoreClipboard {
                usleep(50_000)
                previousSnapshot.restore(to: pasteboard)
            }
        }

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        guard let source = CGEventSource(stateID: .combinedSessionState) else {
            throw DictationRuntimeError.focusedElementUnavailable
        }

        let keyV: CGKeyCode = 9
        let down = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: true)
        down?.flags = .maskCommand
        let up = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: false)
        up?.flags = .maskCommand

        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
        return restoreClipboard
    }

    private func setSelectedRange(_ range: CFRange, for element: AXUIElement) {
        var selectedRange = CFRange(location: max(0, range.location), length: max(0, range.length))
        guard let axRange = AXValueCreate(.cfRange, &selectedRange) else {
            return
        }
        _ = AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            axRange
        )
    }

    func insertFinalText(
        _ text: String,
        into lockedTarget: LockedTextTarget,
        options: DictationStartOptions,
        allowFallbackPaste: Bool,
        onTargetUpdated: (LockedTextTarget) -> Void
    ) throws -> FinalInsertionMetrics {
        let insertion: (path: String, clipboardRestored: Bool)
        if options.simulateKeypresses {
            do {
                try simulateKeyboardInsertion(text, into: lockedTarget)
                insertion = ("simulatedKeypresses", false)
            } catch {
                if allowFallbackPaste {
                    let clipboardRestored = try pasteIntoFallbackTarget(
                        lockedTarget,
                        text: text,
                        restoreClipboard: options.restoreClipboardAfterPaste
                    )
                    insertion = ("clipboardPaste", clipboardRestored)
                } else {
                    throw error
                }
            }
        } else {
            insertion = try replaceInsertedText(
                text,
                in: lockedTarget,
                allowFallbackPaste: allowFallbackPaste,
                restoreClipboardAfterPaste: options.restoreClipboardAfterPaste,
                onTargetUpdated: onTargetUpdated
            )
        }

        var autoSent = false
        if options.autoSendAfterPaste {
            try sendReturnKey()
            autoSent = true
        }
        return FinalInsertionMetrics(
            path: insertion.path,
            clipboardRestored: insertion.clipboardRestored,
            autoSent: autoSent
        )
    }

    func simulateKeyboardInsertion(_ text: String, into target: LockedTextTarget) throws {
        if let expectedBundleIdentifier = target.fallbackBundleIdentifier {
            let frontmostBundleIdentifier = NSWorkspace.shared.frontmostApplication?
                .bundleIdentifier
            guard frontmostBundleIdentifier == expectedBundleIdentifier else {
                throw DictationRuntimeError.unsafePasteFallback
            }
        }

        guard
            let source = CGEventSource(stateID: .hidSystemState)
                ?? CGEventSource(stateID: .combinedSessionState)
        else {
            throw DictationRuntimeError.focusedElementUnavailable
        }

        let unicodeValues = Array(text.utf16)
        guard !unicodeValues.isEmpty else { return }

        let chunkSize = 48
        for chunkStart in stride(from: 0, to: unicodeValues.count, by: chunkSize) {
            let chunkEnd = min(chunkStart + chunkSize, unicodeValues.count)
            let chunk = Array(unicodeValues[chunkStart..<chunkEnd])

            guard let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
            else {
                throw DictationRuntimeError.focusedElementUnavailable
            }
            chunk.withUnsafeBufferPointer { buffer in
                if let baseAddress = buffer.baseAddress {
                    down.keyboardSetUnicodeString(
                        stringLength: buffer.count, unicodeString: baseAddress)
                }
            }
            down.post(tap: .cghidEventTap)

            guard let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
            else {
                throw DictationRuntimeError.focusedElementUnavailable
            }
            up.post(tap: .cghidEventTap)
        }
    }

    func sendReturnKey() throws {
        guard
            let source = CGEventSource(stateID: .hidSystemState)
                ?? CGEventSource(stateID: .combinedSessionState)
        else {
            throw DictationRuntimeError.focusedElementUnavailable
        }

        let returnKey: CGKeyCode = CGKeyCode(kVK_Return)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: returnKey, keyDown: true),
            let up = CGEvent(keyboardEventSource: source, virtualKey: returnKey, keyDown: false)
        else {
            throw DictationRuntimeError.focusedElementUnavailable
        }

        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    func copyTranscriptToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func sharedPrefixLength(_ lhs: String, _ rhs: String) -> Int {
        var lhsIndex = lhs.startIndex
        var rhsIndex = rhs.startIndex
        var count = 0

        while lhsIndex < lhs.endIndex, rhsIndex < rhs.endIndex,
            lhs[lhsIndex] == rhs[rhsIndex]
        {
            count += 1
            lhs.formIndex(after: &lhsIndex)
            rhs.formIndex(after: &rhsIndex)
        }

        return count
    }
}

internal struct FinalTranscriptDeliveryService {
    func deliverFinalText(
        _ finalText: String,
        currentOptions: DictationStartOptions?,
        activeStreamingTarget: LockedTextTarget?,
        isAccessibilityTrusted: () -> Bool,
        resolveAvailableTextTarget: () -> LockedTextTarget?,
        waitForAvailableTextTarget: (UInt64) async -> LockedTextTarget?,
        setWaitingForInsertionTarget: (Bool) -> Void,
        copyTranscriptToClipboard: (String) -> Void,
        insertFinalText: (String, LockedTextTarget, DictationStartOptions, Bool) throws
            -> FinalInsertionMetrics,
        replaceLiveText: (String, LockedTextTarget, DictationStartOptions, Bool) throws
            -> FinalInsertionMetrics,
        publishDiagnostic: (String) -> Void,
        publishFinalDeliveryMetrics: (FinalInsertionMetrics) -> Void,
        pendingInsertionTimeoutNanoseconds: UInt64
    ) async -> FinalTranscriptDeliveryOutcome {
        guard let currentOptions else {
            return .failed("Fehlende Diktat-Optionen.")
        }

        if currentOptions.finalResultDeliveryMode == .clipboardOnly {
            copyTranscriptToClipboard(finalText)
            publishDiagnostic("Finales Transkript wurde in die Zwischenablage kopiert.")
            setWaitingForInsertionTarget(false)
            return .copiedToClipboard
        }

        if !isAccessibilityTrusted() {
            if currentOptions.clipboardFallbackWhenNoTarget {
                copyTranscriptToClipboard(finalText)
                publishDiagnostic(
                    "Bedienungshilfen fehlen. Das finale Transkript wurde in die Zwischenablage kopiert und in der History gespeichert."
                )
                return .copiedToClipboard
            }

            publishDiagnostic(
                "Bedienungshilfen fehlen. Das finale Transkript bleibt in der History verfügbar.")
            return .historyOnlyNoTarget
        }

        if let activeStreamingTarget {
            do {
                let metrics: FinalInsertionMetrics
                if currentOptions.mode == .streaming {
                    metrics = try replaceLiveText(
                        finalText, activeStreamingTarget, currentOptions, true)
                } else {
                    metrics = try insertFinalText(
                        finalText, activeStreamingTarget, currentOptions, true)
                }
                publishFinalDeliveryMetrics(metrics)
                setWaitingForInsertionTarget(false)
                return .inserted
            } catch {
                publishDiagnostic(
                    "Vorhandenes Live-Textziel konnte nicht aktualisiert werden. Versuche das aktuelle Fokusziel erneut."
                )
            }
        }

        if let resolvedTarget = resolveAvailableTextTarget() {
            do {
                let metrics = try insertFinalText(
                    finalText, resolvedTarget, currentOptions, true)
                publishFinalDeliveryMetrics(metrics)
                setWaitingForInsertionTarget(false)
                return .inserted
            } catch {
                if currentOptions.clipboardFallbackWhenNoTarget {
                    copyTranscriptToClipboard(finalText)
                    publishDiagnostic(
                        "Direktes Einfügen fehlgeschlagen. Das finale Transkript wurde in die Zwischenablage kopiert und in der History gespeichert."
                    )
                    setWaitingForInsertionTarget(false)
                    return .copiedToClipboard
                }
                return .failed(error.localizedDescription)
            }
        }

        setWaitingForInsertionTarget(true)
        publishDiagnostic(
            "Kein Textfeld aktiv. Warte bis zu 5 Sekunden auf ein Ziel für das finale Transkript.")

        if let delayedTarget = await waitForAvailableTextTarget(
            pendingInsertionTimeoutNanoseconds)
        {
            do {
                let metrics = try insertFinalText(
                    finalText, delayedTarget, currentOptions, true)
                publishFinalDeliveryMetrics(metrics)
                setWaitingForInsertionTarget(false)
                publishDiagnostic("Textziel erkannt. Finales Transkript wurde eingefügt.")
                return .inserted
            } catch {
                setWaitingForInsertionTarget(false)
                if currentOptions.clipboardFallbackWhenNoTarget {
                    copyTranscriptToClipboard(finalText)
                    publishDiagnostic(
                        "Einfügen ins Ziel ist fehlgeschlagen. Das finale Transkript wurde in die Zwischenablage kopiert und in der History gespeichert."
                    )
                    return .copiedToClipboard
                }
                return .failed(error.localizedDescription)
            }
        }

        setWaitingForInsertionTarget(false)
        if currentOptions.clipboardFallbackWhenNoTarget {
            copyTranscriptToClipboard(finalText)
            publishDiagnostic(
                "Kein Textfeld gewählt. Das finale Transkript wurde in die Zwischenablage kopiert und in der History gespeichert."
            )
            return .copiedToClipboard
        }

        publishDiagnostic(
            "Kein Textfeld gewählt. Das finale Transkript bleibt in der History verfügbar.")
        return .historyOnlyNoTarget
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

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        guard !items.isEmpty else { return }
        pasteboard.writeObjects(items)
    }
}
