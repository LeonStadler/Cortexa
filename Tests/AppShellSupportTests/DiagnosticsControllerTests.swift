#if canImport(XCTest)
import Foundation
import XCTest
@testable import AppShellSupport

@MainActor
final class DiagnosticsControllerTests: XCTestCase {
    func testAppendDiagnosticUpdatesVisibleTextAndAuditLog() {
        let auditLogger = AppShellTestAuditLogger()
        let debugLogger = AppShellTestAuditLogger()
        let state = DiagnosticsControllerState()
        let controller = makeController(state: state, auditLogger: auditLogger, debugLogger: debugLogger)

        controller.appendDiagnostic("permission.changed")

        XCTAssertTrue(state.diagnosticsText.contains("permission.changed"))
        XCTAssertEqual(auditLogger.appendedLines.last, "diag permission.changed")
    }

    func testAppendDebugOnlyWritesWhenDebugModeIsEnabled() {
        let auditLogger = AppShellTestAuditLogger()
        let debugLogger = AppShellTestAuditLogger()
        let state = DiagnosticsControllerState()
        let controller = makeController(state: state, auditLogger: auditLogger, debugLogger: debugLogger)

        controller.appendDebug("hidden")
        XCTAssertEqual(state.debugLogText, "")
        XCTAssertTrue(debugLogger.appendedLines.isEmpty)

        state.debugModeEnabled = true
        controller.appendDebug("visible")

        XCTAssertTrue(state.debugLogText.contains("visible"))
        XCTAssertEqual(debugLogger.appendedLines.last, "visible")
        XCTAssertEqual(auditLogger.appendedLines.last, "debug visible")
    }

    func testDiagnosticsAndDebugCombinedForClipboardUsesCurrentTextSnapshots() {
        let controller = makeController(
            state: DiagnosticsControllerState(
                diagnosticsText: "diag body",
                debugLogText: "debug body"
            ),
            auditLogger: AppShellTestAuditLogger(),
            debugLogger: AppShellTestAuditLogger()
        )

        let combined = controller.diagnosticsAndDebugCombinedForClipboard()

        XCTAssertTrue(combined.contains("=== Diagnostics ==="))
        XCTAssertTrue(combined.contains("diag body"))
        XCTAssertTrue(combined.contains("=== Technical log ==="))
        XCTAssertTrue(combined.contains("debug body"))
    }

    private func makeController(
        state: DiagnosticsControllerState,
        auditLogger: AppShellTestAuditLogger,
        debugLogger: AppShellTestAuditLogger
    ) -> DiagnosticsController {
        DiagnosticsController(
            auditLogger: auditLogger,
            debugLogger: debugLogger,
            currentRecordingStatus: { state.recordingStatus },
            currentPermissionSummary: { state.permissionSummary },
            currentCapabilitySummary: { state.capabilitySummary },
            currentUpdaterStatusText: { state.updaterStatusText },
            currentDebugModeEnabled: { state.debugModeEnabled },
            currentDiagnosticsText: { state.diagnosticsText },
            currentDebugLogText: { state.debugLogText },
            setDiagnosticsText: { state.diagnosticsText = $0 },
            setDebugLogText: { state.debugLogText = $0 }
        )
    }
}

private final class DiagnosticsControllerState {
    var recordingStatus: String
    var permissionSummary: String
    var capabilitySummary: String
    var updaterStatusText: String
    var debugModeEnabled: Bool
    var diagnosticsText: String
    var debugLogText: String

    init(
        recordingStatus: String = "Idle",
        permissionSummary: String = "Mic: granted",
        capabilitySummary: String = "Ready",
        updaterStatusText: String = "Idle",
        debugModeEnabled: Bool = false,
        diagnosticsText: String = "",
        debugLogText: String = ""
    ) {
        self.recordingStatus = recordingStatus
        self.permissionSummary = permissionSummary
        self.capabilitySummary = capabilitySummary
        self.updaterStatusText = updaterStatusText
        self.debugModeEnabled = debugModeEnabled
        self.diagnosticsText = diagnosticsText
        self.debugLogText = debugLogText
    }
}
#endif
