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
            currentOptions: makeOptions(deliveryMode: .clipboardOnly),
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

    private func makeOptions(deliveryMode: FinalResultDeliveryMode) -> DictationStartOptions {
        DictationStartOptions(
            mode: .finalize,
            language: .german,
            translationOutput: .original,
            performance: .auto,
            selectedVoiceProviderID: "test-provider",
            selectedVoiceModelID: "test-model",
            liveRewriteScope: .currentSentence,
            snippetRules: [],
            finalResultDeliveryMode: deliveryMode,
            clipboardFallbackWhenNoTarget: false,
            simulateKeypresses: false,
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
#endif
