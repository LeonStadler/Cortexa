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
                simulateKeypresses: false
            ),
            activeStreamingTarget: nil,
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
                simulateKeypresses: true
            ),
            activeStreamingTarget: target,
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
        simulateKeypresses: Bool
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
            clipboardFallbackWhenNoTarget: false,
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
}

private struct FocusUnavailableError: Error {}
#endif
