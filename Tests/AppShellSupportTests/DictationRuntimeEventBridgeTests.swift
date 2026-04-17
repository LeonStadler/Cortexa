#if canImport(XCTest)
import AIProcessingCore
import Foundation
import XCTest
@testable import AppShellSupport

@MainActor
final class DictationRuntimeEventBridgeTests: XCTestCase {
    func testConnectDeliversStatusAndTranscriptOnMainActor() async {
        let runtime = BridgeTestRuntime()
        let bridge = DictationRuntimeEventBridge()
        var receivedStatuses: [String] = []
        var receivedTranscripts: [String] = []

        bridge.connect(
            runtime: runtime,
            handlers: DictationRuntimeEventHandlers(
                handleStatus: { status in
                    XCTAssertTrue(Thread.isMainThread)
                    receivedStatuses.append(status)
                },
                handleDiagnostic: { _ in XCTFail("Unexpected diagnostic callback") },
                handleDebugEvent: { _ in XCTFail("Unexpected debug callback") },
                handleTranscript: { transcript in
                    XCTAssertTrue(Thread.isMainThread)
                    receivedTranscripts.append(transcript)
                },
                handleFinalTranscript: { _ in XCTFail("Unexpected final transcript callback") },
                handleSessionActivityChanged: { _ in
                    XCTFail("Unexpected session activity callback")
                },
                handlePermissionInteractionFinished: {
                    XCTFail("Unexpected permission interaction callback")
                }
            )
        )

        runtime.onStatus?("Recording")
        runtime.onTranscript?("Zwischenstand")

        _ = await eventually {
            receivedStatuses == ["Recording"] && receivedTranscripts == ["Zwischenstand"]
        }
        XCTAssertEqual(receivedStatuses, ["Recording"])
        XCTAssertEqual(receivedTranscripts, ["Zwischenstand"])
    }

    func testConnectBridgesFinalTranscriptSessionActivityAndPermissionCallbacks() async {
        let runtime = BridgeTestRuntime()
        let bridge = DictationRuntimeEventBridge()
        var receivedEvents: [String] = []

        bridge.connect(
            runtime: runtime,
            handlers: DictationRuntimeEventHandlers(
                handleStatus: { _ in },
                handleDiagnostic: { _ in },
                handleDebugEvent: { _ in },
                handleTranscript: { _ in },
                handleFinalTranscript: { event in
                    receivedEvents.append("final:\(event.text)")
                },
                handleSessionActivityChanged: { isActive in
                    receivedEvents.append("active:\(isActive)")
                },
                handlePermissionInteractionFinished: {
                    receivedEvents.append("permissions")
                }
            )
        )

        runtime.onFinalTranscript?(
            FinalTranscriptEvent(
                text: "Bridge",
                languageCode: "de",
                mode: .finalize,
                deliveryOutcome: .inserted
            )
        )
        runtime.onSessionActivityChanged?(true)
        runtime.onPermissionInteractionFinished?()

        let delivered = await eventually {
            receivedEvents.count == 3
        }
        XCTAssertTrue(delivered)
        XCTAssertEqual(receivedEvents.count, 3)
        XCTAssertTrue(receivedEvents.contains("final:Bridge"))
        XCTAssertTrue(receivedEvents.contains("active:true"))
        XCTAssertTrue(receivedEvents.contains("permissions"))
    }

    func testConnectBridgesDiagnosticAndDebugCallbacks() async {
        let runtime = BridgeTestRuntime()
        let bridge = DictationRuntimeEventBridge()
        var diagnostics: [String] = []
        var debugEvents: [String] = []

        bridge.connect(
            runtime: runtime,
            handlers: DictationRuntimeEventHandlers(
                handleStatus: { _ in },
                handleDiagnostic: { diagnostics.append($0) },
                handleDebugEvent: { debugEvents.append($0) },
                handleTranscript: { _ in },
                handleFinalTranscript: { _ in },
                handleSessionActivityChanged: { _ in },
                handlePermissionInteractionFinished: {}
            )
        )

        runtime.onDiagnostic?("diag")
        runtime.onDebugEvent?("debug")

        _ = await eventually {
            diagnostics == ["diag"] && debugEvents == ["debug"]
        }
        XCTAssertEqual(diagnostics, ["diag"])
        XCTAssertEqual(debugEvents, ["debug"])
    }

    private func eventually(
        timeoutNanoseconds: UInt64 = 1_000_000_000,
        pollNanoseconds: UInt64 = 20_000_000,
        condition: () -> Bool
    ) async -> Bool {
        let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
        while DispatchTime.now().uptimeNanoseconds < deadline {
            if condition() {
                return true
            }
            try? await Task.sleep(nanoseconds: pollNanoseconds)
        }
        return condition()
    }
}

private final class BridgeTestRuntime: DictationRuntimeControlling {
    var onStatus: ((String) -> Void)?
    var onDiagnostic: ((String) -> Void)?
    var onDebugEvent: ((String) -> Void)?
    var onTranscript: ((String) -> Void)?
    var onFinalTranscript: ((FinalTranscriptEvent) -> Void)?
    var onSessionActivityChanged: ((Bool) -> Void)?
    var onPermissionInteractionFinished: (() -> Void)?

    func prepareRuntime() {}
    func setVoiceModelActiveDuration(_ duration: VoiceModelActiveDuration) {}
    func toggle(options: DictationStartOptions) {}
    func cancel() {}
    func start(options: DictationStartOptions) {}
    func openMicrophoneSettings() {}
    func openAccessibilitySettings() {}
    func promptAccessibilityTrustFromUser() {}
    func setAIProcessingService(_ service: AIProcessingService) {}
}
#endif
