#if canImport(XCTest)
import AIProcessingCore
import ASRCore
import AudioCore
import AppKit
import Foundation
import SnippetCore
import XCTest
@testable import AppShellSupport

@MainActor
final class SessionEntryControllerTests: XCTestCase {
    func testHoldShortcutStartsAndStopsWhenHoldModeIsEnabled() {
        let runtime = AppShellTestDictationRuntime()
        var refreshCount = 0
        var sessionActive = false
        var audits: [String] = []
        let controller = makeController(
            dictationRuntime: runtime,
            refreshPermissionStates: { refreshCount += 1 },
            dictationCapabilityAllowsDirectInsertion: { false },
            appendAudit: { audits.append($0) },
            appendDiagnostic: { _ in },
            isSessionActive: { sessionActive },
            holdToDictateEnabled: { true }
        )

        controller.handleHoldShortcutPressed()
        sessionActive = true
        controller.handleHoldShortcutReleased()

        XCTAssertEqual(refreshCount, 1)
        XCTAssertEqual(runtime.toggleCalls.count, 2)
        XCTAssertEqual(runtime.startCalls.count, 0)
        XCTAssertEqual(audits.first, "hotkey.hold.press recordingStatus=idle")
        XCTAssertEqual(audits.last, "hotkey.hold.release recordingStatus=idle")
    }

    func testResetHoldSessionActivePreventsReleaseToggle() {
        let runtime = AppShellTestDictationRuntime()
        var sessionActive = false
        let controller = makeController(
            dictationRuntime: runtime,
            dictationCapabilityAllowsDirectInsertion: { false },
            isSessionActive: { sessionActive },
            holdToDictateEnabled: { true }
        )

        controller.handleHoldShortcutPressed()
        controller.resetHoldSessionActive()
        sessionActive = true
        controller.handleHoldShortcutReleased()

        XCTAssertEqual(runtime.toggleCalls.count, 1)
    }

    func testToggleTranscriptionFromUIStopsAnActiveSession() {
        let runtime = AppShellTestDictationRuntime()
        let sessionActive = true
        var audits: [String] = []
        let controller = makeController(
            dictationRuntime: runtime,
            appendAudit: { audits.append($0) },
            isSessionActive: { sessionActive },
            holdToDictateEnabled: { false }
        )

        controller.toggleTranscriptionFromUI()

        XCTAssertEqual(runtime.toggleCalls.count, 1)
        XCTAssertEqual(runtime.startCalls.count, 0)
        XCTAssertEqual(audits, ["session.toggle stop"])
    }

    func testToggleTranscriptionFromMenuBarStartsRuntimeWhenDirectInsertionIsUnavailable() {
        let runtime = AppShellTestDictationRuntime()
        var refreshCount = 0
        var audits: [String] = []
        let controller = makeController(
            dictationRuntime: runtime,
            refreshPermissionStates: { refreshCount += 1 },
            dictationCapabilityAllowsDirectInsertion: { false },
            appendAudit: { audits.append($0) }
        )

        controller.toggleTranscriptionFromMenuBar()

        XCTAssertEqual(refreshCount, 1)
        XCTAssertEqual(runtime.startCalls.count, 1)
        XCTAssertEqual(runtime.toggleCalls.count, 0)
        XCTAssertTrue(audits.first?.hasPrefix("session.toggle.menuBar start mode=") == true)
    }

    func testToggleTranscriptionFromMenuBarStopsAnActiveSession() {
        let runtime = AppShellTestDictationRuntime()
        let sessionActive = true
        var refreshCount = 0
        let controller = makeController(
            dictationRuntime: runtime,
            refreshPermissionStates: { refreshCount += 1 },
            dictationCapabilityAllowsDirectInsertion: { false },
            isSessionActive: { sessionActive }
        )

        controller.toggleTranscriptionFromMenuBar()

        XCTAssertEqual(refreshCount, 0)
        XCTAssertEqual(runtime.toggleCalls.count, 1)
        XCTAssertEqual(runtime.startCalls.count, 0)
    }

    func testToggleTranscriptionFromMenuBarRestoresAndStartsWhenDirectInsertionIsAvailable()
        async throws
    {
        let runtime = AppShellTestDictationRuntime()
        var refreshCount = 0
        let controller = makeController(
            dictationRuntime: runtime,
            refreshPermissionStates: { refreshCount += 1 },
            dictationCapabilityAllowsDirectInsertion: { true },
            waitForMenuBarToCloseOperation: { true }
        )

        controller.toggleTranscriptionFromMenuBar()

        XCTAssertEqual(refreshCount, 1)
        XCTAssertEqual(runtime.toggleCalls.count, 0)
        let started = await eventually { runtime.startCalls.count == 1 }
        XCTAssertTrue(started)
        XCTAssertEqual(runtime.startCalls.count, 1)
        XCTAssertEqual(runtime.toggleCalls.count, 0)
    }

    func testStartTranscriptionForShortcutRestoresAndStartsWhenDirectInsertionAndRestoreAreEnabled()
        async
    {
        let runtime = AppShellTestDictationRuntime()
        var audits: [String] = []
        var diagnostics: [String] = []
        let controller = makeController(
            dictationRuntime: runtime,
            dictationCapabilityAllowsDirectInsertion: { true },
            lastExternalApplication: { NSRunningApplication.current },
            appendAudit: { audits.append($0) },
            appendDiagnostic: { diagnostics.append($0) },
            shouldRestorePreviousApplicationBeforeStarting: { true },
            waitForFrontmostApplicationOperation: { _, _ in true }
        )

        controller.startTranscriptionForShortcut()

        let started = await eventually { runtime.startCalls.count == 1 }
        XCTAssertTrue(started)
        XCTAssertEqual(runtime.startCalls.count, 1)
        XCTAssertEqual(runtime.toggleCalls.count, 0)
        XCTAssertTrue(audits.contains("session.restore_start source=shortcut"))
        XCTAssertTrue(
            diagnostics.contains(where: {
                $0.contains("Wechsle vor dem Start zurück zur letzten App")
            }))
    }

    func testStartTranscriptionForShortcutFallsBackToToggleWhenRestoreDecisionIsFalse() {
        let runtime = AppShellTestDictationRuntime()
        let controller = makeController(
            dictationRuntime: runtime,
            dictationCapabilityAllowsDirectInsertion: { true },
            shouldRestorePreviousApplicationBeforeStarting: { false }
        )

        controller.startTranscriptionForShortcut()

        XCTAssertEqual(runtime.toggleCalls.count, 1)
        XCTAssertEqual(runtime.startCalls.count, 0)
    }

    func testStartTranscriptionForShortcutFallsBackToToggleWhenRestoreIsEnabledButNoPreviousApp()
    {
        let runtime = AppShellTestDictationRuntime()
        let controller = makeController(
            dictationRuntime: runtime,
            dictationCapabilityAllowsDirectInsertion: { true },
            lastExternalApplication: { nil },
            shouldRestorePreviousApplicationBeforeStarting: { true }
        )

        controller.startTranscriptionForShortcut()

        XCTAssertEqual(runtime.toggleCalls.count, 1)
        XCTAssertEqual(runtime.startCalls.count, 0)
    }

    func testStartTranscriptionForShortcutAbortsWhenRestoreTargetDoesNotBecomeFrontmost() async {
        let runtime = AppShellTestDictationRuntime()
        var audits: [String] = []
        var diagnostics: [String] = []
        let targetApplication =
            NSWorkspace.shared.frontmostApplication
            ?? NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier != nil })
            ?? NSRunningApplication.current
        let controller = makeController(
            dictationRuntime: runtime,
            dictationCapabilityAllowsDirectInsertion: { true },
            lastExternalApplication: { targetApplication },
            appendAudit: { audits.append($0) },
            appendDiagnostic: { diagnostics.append($0) },
            shouldRestorePreviousApplicationBeforeStarting: { true },
            waitForFrontmostApplicationOperation: { _, _ in false }
        )

        controller.startTranscriptionForShortcut()

        let aborted = await eventually {
            audits.contains(where: { $0.contains("session.restore_abort") })
        }
        XCTAssertTrue(aborted)
        XCTAssertEqual(runtime.startCalls.count, 0)
        XCTAssertEqual(runtime.toggleCalls.count, 0)
        XCTAssertTrue(
            diagnostics.contains(where: {
                $0.contains("Konnte die Ziel-App nicht zuverlässig fokussieren")
            }))
    }

    func testCancelPendingRestoreStartPreventsLateStart() async {
        let runtime = AppShellTestDictationRuntime()
        let controller = makeController(
            dictationRuntime: runtime,
            dictationCapabilityAllowsDirectInsertion: { true },
            lastExternalApplication: { NSRunningApplication.current },
            shouldRestorePreviousApplicationBeforeStarting: { true },
            waitForFrontmostApplicationOperation: { _, _ in
                try? await Task.sleep(nanoseconds: 120_000_000)
                return true
            }
        )

        controller.startTranscriptionForShortcut()
        controller.cancelPendingRestoreStart()

        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(runtime.startCalls.count, 0)
    }

    private func makeController(
        dictationRuntime: DictationRuntimeControlling = AppShellTestDictationRuntime(),
        currentStartOptions: @escaping () -> DictationStartOptions = makeStartOptions,
        refreshPermissionStates: @escaping () -> Void = {},
        dictationCapabilityAllowsDirectInsertion: @escaping () -> Bool = { false },
        lastExternalApplication: @escaping () -> NSRunningApplication? = { nil },
        appendAudit: @escaping (String) -> Void = { _ in },
        appendDiagnostic: @escaping (String) -> Void = { _ in },
        currentRecordingStatus: @escaping () -> String = { "idle" },
        currentSelectedLanguageRawValue: @escaping () -> String = { "de" },
        currentPerformanceProfileRawValue: @escaping () -> String = { "auto" },
        currentDictationCapability: @escaping () -> DictationCapability = { .limitedTranscription },
        isSessionActive: @escaping () -> Bool = { false },
        holdToDictateEnabled: @escaping () -> Bool = { true },
        shouldRestorePreviousApplicationBeforeStarting: (() -> Bool)? = nil,
        waitForMenuBarToCloseOperation: @escaping () async -> Bool = {
            await SessionEntryController.defaultWaitForMenuBarToClose()
        },
        waitForFrontmostApplicationOperation: @escaping (String, UInt64) async -> Bool = {
            bundleIdentifier,
            timeoutNanoseconds in
            await SessionEntryController.defaultWaitForFrontmostApplication(
                bundleIdentifier: bundleIdentifier,
                timeoutNanoseconds: timeoutNanoseconds
            )
        }
    ) -> SessionEntryController {
        SessionEntryController(
            dictationRuntime: dictationRuntime,
            currentStartOptions: currentStartOptions,
            refreshPermissionStates: refreshPermissionStates,
            dictationCapabilityAllowsDirectInsertion: dictationCapabilityAllowsDirectInsertion,
            lastExternalApplication: lastExternalApplication,
            appendAudit: appendAudit,
            appendDiagnostic: appendDiagnostic,
            currentRecordingStatus: currentRecordingStatus,
            currentSelectedLanguageRawValue: currentSelectedLanguageRawValue,
            currentPerformanceProfileRawValue: currentPerformanceProfileRawValue,
            currentDictationCapability: currentDictationCapability,
            isSessionActive: isSessionActive,
            holdToDictateEnabled: holdToDictateEnabled,
            shouldRestorePreviousApplicationBeforeStarting:
                shouldRestorePreviousApplicationBeforeStarting,
            waitForMenuBarToCloseOperation: waitForMenuBarToCloseOperation,
            waitForFrontmostApplicationOperation: waitForFrontmostApplicationOperation
        )
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

    private nonisolated static func makeStartOptions() -> DictationStartOptions {
        DictationStartOptions(
            mode: .streaming,
            language: .german,
            translationOutput: .original,
            performance: .auto,
            selectedVoiceProviderID: "provider",
            selectedVoiceModelID: "model",
            liveRewriteScope: .currentSentence,
            snippetRules: [],
            finalResultDeliveryMode: .insert,
            clipboardFallbackWhenNoTarget: false,
            simulateKeypresses: false,
            restoreClipboardAfterPaste: false,
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
