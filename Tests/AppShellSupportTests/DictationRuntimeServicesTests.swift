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

        let outcome = await service.deliverFinalText(
            "Hallo Welt",
            currentOptions: makeOptions(deliveryMode: .clipboardOnly),
            activeStreamingTarget: nil,
            resolveAvailableTextTarget: { nil },
            waitForAvailableTextTarget: { _ in nil },
            setWaitingForInsertionTarget: { waitingStates.append($0) },
            copyTranscriptToClipboard: { copiedText = $0 },
            insertFinalText: { _, _, _, _ in
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
            aiProcessing: AIProcessingConfiguration(enabled: false, selectedModelID: nil),
            audioProcessing: AudioProcessingConfiguration(),
            soundFeedback: SoundFeedbackConfiguration()
        )
    }
}
#endif
