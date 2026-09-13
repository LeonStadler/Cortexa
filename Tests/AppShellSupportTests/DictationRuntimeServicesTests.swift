#if canImport(XCTest)
import AIProcessingCore
import ASRCore
import AudioCore
import Foundation
import SnippetCore
import XCTest
@testable import AppShellSupport

@MainActor
final class DictationRuntimeServicesTests: XCTestCase {
    func testStreamingPreservedPrefixLengthUsesCommonPrefixWithinMutableWindow() {
        let service = StreamingTextInsertionService()

        let preserved = service.streamingPreservedPrefixLength(
            previousText: "hello world",
            newText: "hello brave world",
            maximumMutableCharacterCount: 5
        )

        XCTAssertEqual(preserved, 6)
    }

    func testClipboardOnlyFinalDeliveryCopiesTextAndReturnsCopiedOutcome() async {
        let service = FinalTranscriptDeliveryService()
        var copiedText: String?
        var waitingStates: [Bool] = []
        var resolveCalls = 0
        var waitCalls = 0
        var insertCalls = 0

        let outcome = await service.deliverFinalText(
            "Hallo Welt",
            currentOptions: makeOptions(
                deliveryMode: .clipboardOnly,
                mode: .finalize,
                simulateKeypresses: false,
                clipboardFallbackWhenNoTarget: false
            ),
            activeStreamingTarget: nil,
            isAccessibilityTrusted: { true },
            resolveAvailableTextTarget: {
                resolveCalls += 1
                return nil
            },
            waitForAvailableTextTarget: { _ in
                waitCalls += 1
                return nil
            },
            setWaitingForInsertionTarget: { waitingStates.append($0) },
            copyTranscriptToClipboard: { copiedText = $0 },
            insertFinalText: { _, _, _, _ in
                insertCalls += 1
                XCTFail("insertFinalText should not be called for clipboard-only delivery")
                return FinalInsertionMetrics(path: "unused", clipboardRestored: false, autoSent: false)
            },
            replaceLiveText: { _, _, _, _ in
                XCTFail("replaceLiveText should not be called for clipboard-only delivery")
                return FinalInsertionMetrics(path: "unused", clipboardRestored: false, autoSent: false)
            },
            publishDiagnostic: { _ in },
            publishFinalDeliveryMetrics: { _ in },
            pendingInsertionTimeoutNanoseconds: 1
        )

        XCTAssertEqual(outcome, .copiedToClipboard)
        XCTAssertEqual(copiedText, "Hallo Welt")
        XCTAssertEqual(waitingStates, [false])
        XCTAssertEqual(resolveCalls, 0)
        XCTAssertEqual(waitCalls, 0)
        XCTAssertEqual(insertCalls, 0)
    }

    func testStreamingFinalDeliveryReplacesLiveTextInsteadOfSimulatingAnotherInsertion() async {
        let service = FinalTranscriptDeliveryService()
        let target = LockedTextTarget(
            element: AXUIElementCreateSystemWide(),
            insertionLocation: 12,
            originalSelectedLength: 0,
            fallbackBundleIdentifier: "com.example.editor",
            prefersKeyboardInsertion: true,
            insertedLength: 14
        )
        var insertCalls = 0
        var replaceCalls = 0

        let outcome = await service.deliverFinalText(
            "Test 1, 2, 3",
            currentOptions: makeOptions(
                deliveryMode: .insert,
                mode: .streaming,
                simulateKeypresses: true,
                clipboardFallbackWhenNoTarget: false
            ),
            activeStreamingTarget: target,
            isAccessibilityTrusted: { true },
            resolveAvailableTextTarget: { nil },
            waitForAvailableTextTarget: { _ in nil },
            setWaitingForInsertionTarget: { _ in },
            copyTranscriptToClipboard: { _ in },
            insertFinalText: { _, _, _, _ in
                insertCalls += 1
                return FinalInsertionMetrics(path: "simulatedKeypresses", clipboardRestored: false, autoSent: false)
            },
            replaceLiveText: { text, receivedTarget, options, allowFallbackPaste in
                replaceCalls += 1
                XCTAssertEqual(text, "Test 1, 2, 3")
                XCTAssertEqual(receivedTarget.insertedLength, 14)
                XCTAssertTrue(options.simulateKeypresses)
                XCTAssertTrue(allowFallbackPaste)
                return FinalInsertionMetrics(path: "axValueSet", clipboardRestored: false, autoSent: false)
            },
            publishDiagnostic: { _ in },
            publishFinalDeliveryMetrics: { _ in },
            pendingInsertionTimeoutNanoseconds: 1
        )

        XCTAssertEqual(outcome, .inserted)
        XCTAssertEqual(replaceCalls, 1)
        XCTAssertEqual(insertCalls, 0)
    }

    func testFinalDeliveryMatrixUsesReplacementOnlyForLiveSessions() async {
        let service = FinalTranscriptDeliveryService()
        let target = makeTarget()

        for mode in [DictationMode.streaming, .finalize] {
            for simulateKeypresses in [false, true] {
                var insertCalls = 0
                var replaceCalls = 0
                let outcome = await service.deliverFinalText(
                    "final text",
                    currentOptions: makeOptions(
                        deliveryMode: .insert,
                        mode: mode,
                        simulateKeypresses: simulateKeypresses,
                        clipboardFallbackWhenNoTarget: false
                    ),
                    activeStreamingTarget: target,
                    isAccessibilityTrusted: { true },
                    resolveAvailableTextTarget: { nil },
                    waitForAvailableTextTarget: { _ in nil },
                    setWaitingForInsertionTarget: { _ in },
                    copyTranscriptToClipboard: { _ in },
                    insertFinalText: { _, _, _, _ in
                        insertCalls += 1
                        return FinalInsertionMetrics(
                            path: "insert", clipboardRestored: false, autoSent: false)
                    },
                    replaceLiveText: { _, _, _, _ in
                        replaceCalls += 1
                        return FinalInsertionMetrics(
                            path: "replace", clipboardRestored: false, autoSent: false)
                    },
                    publishDiagnostic: { _ in },
                    publishFinalDeliveryMetrics: { _ in },
                    pendingInsertionTimeoutNanoseconds: 1
                )

                XCTAssertEqual(outcome, .inserted)
                XCTAssertEqual(replaceCalls, mode == .streaming ? 1 : 0)
                XCTAssertEqual(insertCalls, mode == .finalize ? 1 : 0)
            }
        }
    }

    func testFinalDeliveryUsesFocusedTargetAfterLiveTargetReplacementFails() async {
        let service = FinalTranscriptDeliveryService()
        let activeTarget = makeTarget()
        let focusedTarget = makeTarget()
        var insertCalls = 0
        var replaceCalls = 0

        let outcome = await service.deliverFinalText(
            "final text",
            currentOptions: makeOptions(
                deliveryMode: .insert,
                mode: .streaming,
                simulateKeypresses: false,
                clipboardFallbackWhenNoTarget: false
            ),
            activeStreamingTarget: activeTarget,
            isAccessibilityTrusted: { true },
            resolveAvailableTextTarget: { focusedTarget },
            waitForAvailableTextTarget: { _ in nil },
            setWaitingForInsertionTarget: { _ in },
            copyTranscriptToClipboard: { _ in },
            insertFinalText: { _, receivedTarget, _, _ in
                insertCalls += 1
                XCTAssertTrue(CFEqual(receivedTarget.element, focusedTarget.element))
                return FinalInsertionMetrics(path: "focused", clipboardRestored: false, autoSent: false)
            },
            replaceLiveText: { _, _, _, _ in
                replaceCalls += 1
                throw FocusUnavailableError()
            },
            publishDiagnostic: { _ in },
            publishFinalDeliveryMetrics: { _ in },
            pendingInsertionTimeoutNanoseconds: 1
        )

        XCTAssertEqual(outcome, .inserted)
        XCTAssertEqual(replaceCalls, 1)
        XCTAssertEqual(insertCalls, 1)
    }

    func testFinalDeliveryNoTargetMatrixKeepsTextSafeOrCopiesIt() async {
        let service = FinalTranscriptDeliveryService()

        for fallbackToClipboard in [false, true] {
            var copiedText: String?
            var waitingStates: [Bool] = []
            let outcome = await service.deliverFinalText(
                "final text",
                currentOptions: makeOptions(
                    deliveryMode: .insert,
                    mode: .finalize,
                    simulateKeypresses: false,
                    clipboardFallbackWhenNoTarget: fallbackToClipboard
                ),
                activeStreamingTarget: nil,
                isAccessibilityTrusted: { true },
                resolveAvailableTextTarget: { nil },
                waitForAvailableTextTarget: { _ in nil },
                setWaitingForInsertionTarget: { waitingStates.append($0) },
                copyTranscriptToClipboard: { copiedText = $0 },
                insertFinalText: { _, _, _, _ in
                    XCTFail("No insertion should be attempted without a target.")
                    return FinalInsertionMetrics(path: "unused", clipboardRestored: false, autoSent: false)
                },
                replaceLiveText: { _, _, _, _ in
                    XCTFail("No replacement should be attempted without a target.")
                    return FinalInsertionMetrics(path: "unused", clipboardRestored: false, autoSent: false)
                },
                publishDiagnostic: { _ in },
                publishFinalDeliveryMetrics: { _ in },
                pendingInsertionTimeoutNanoseconds: 1
            )

            XCTAssertEqual(
                outcome,
                fallbackToClipboard ? .copiedToClipboard : .historyOnlyNoTarget
            )
            XCTAssertEqual(copiedText, fallbackToClipboard ? "final text" : nil)
            XCTAssertEqual(waitingStates, [true, false])
        }
    }

    func testResolveAvailableTextTargetDoesNotReuseAnOldTargetWhenFocusIsUnavailable() {
        let service = FocusedTextTargetService()
        let staleTarget = LockedTextTarget(
            element: AXUIElementCreateSystemWide(),
            insertionLocation: 0,
            originalSelectedLength: 0,
            fallbackBundleIdentifier: "com.example.previous-editor",
            prefersKeyboardInsertion: false,
            insertedLength: 0
        )

        let target = service.resolveAvailableTextTarget(
            currentTarget: nil,
            captureFocusedTextTarget: { throw FocusUnavailableError() },
            captureFocusedTargetForPasteFallback: { nil },
            refreshLockedTextTarget: { _ in staleTarget }
        )

        XCTAssertNil(target)
    }

    private func makeOptions(
        deliveryMode: FinalResultDeliveryMode,
        mode: DictationMode,
        simulateKeypresses: Bool,
        clipboardFallbackWhenNoTarget: Bool
    ) -> DictationStartOptions {
        DictationStartOptions(
            mode: mode,
            language: .german,
            translationOutput: .original,
            performance: .auto,
            selectedVoiceProviderID: "test-provider",
            selectedVoiceModelID: "test-model",
            liveRewriteScope: .currentSentence,
            snippetRules: [],
            finalResultDeliveryMode: deliveryMode,
            clipboardFallbackWhenNoTarget: clipboardFallbackWhenNoTarget,
            simulateKeypresses: simulateKeypresses,
            restoreClipboardAfterPaste: true,
            autoSendAfterPaste: false,
            muteMusicWhileDictating: false,
            asrInitialPrompt: nil,
            dictionaryTerms: [],
            liveContextText: nil,
            finalContextText: nil,
            aiProcessing: AIProcessingConfiguration(enabled: false, selectedModelID: nil),
            audioProcessing: AudioProcessingConfiguration(),
            soundFeedback: SoundFeedbackConfiguration()
        )
    }

    private func makeTarget() -> LockedTextTarget {
        LockedTextTarget(
            element: AXUIElementCreateSystemWide(),
            insertionLocation: 12,
            originalSelectedLength: 0,
            fallbackBundleIdentifier: "com.example.editor",
            prefersKeyboardInsertion: true,
            insertedLength: 14
        )
    }
}

private struct FocusUnavailableError: Error {}
#endif
