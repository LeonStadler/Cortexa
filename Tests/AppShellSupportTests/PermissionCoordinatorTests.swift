#if canImport(XCTest)
import AVFoundation
import XCTest
@testable import AppShellSupport

@MainActor
final class PermissionCoordinatorTests: XCTestCase {
    func testRefreshPermissionStatesMapsStatusesAndLogsDebugOutput() {
        let permissions = AppShellTestPermissionController()
        permissions.microphoneStatusValue = .restricted
        permissions.accessibilityStatusValue = .denied

        var microphoneStatus: PermissionStatus = .granted
        var accessibilityStatus: PermissionStatus = .granted
        var diagnostics: [String] = []
        var debugMessages: [String] = []
        var hotkeyRegistrations: [Bool] = []

        let coordinator = makeCoordinator(
            permissionController: permissions,
            currentMicrophoneStatus: { microphoneStatus },
            setMicrophoneStatus: { microphoneStatus = $0 },
            currentAccessibilityStatus: { accessibilityStatus },
            setAccessibilityStatus: { accessibilityStatus = $0 },
            registerSelectedHotkey: { hotkeyRegistrations.append($0) },
            appendDiagnostic: { diagnostics.append($0) },
            appendDebug: { debugMessages.append($0) },
            isDebugModeEnabled: { true }
        )

        coordinator.refreshPermissionStates()

        XCTAssertEqual(microphoneStatus, .restricted)
        XCTAssertEqual(accessibilityStatus, .denied)
        XCTAssertTrue(hotkeyRegistrations.isEmpty)
        XCTAssertTrue(debugMessages.contains { $0.contains("permissions.microphone") })
        XCTAssertTrue(diagnostics.isEmpty)
    }

    func testRefreshPermissionsAfterExternalEventRegistersHotkeyWhenStatusChanges() {
        let permissions = AppShellTestPermissionController()
        permissions.microphoneStatusValue = .denied
        permissions.accessibilityStatusValue = .granted

        var microphoneStatus: PermissionStatus = .granted
        var accessibilityStatus: PermissionStatus = .granted
        var diagnostics: [String] = []
        var debugMessages: [String] = []
        var hotkeyRegistrations: [Bool] = []

        let coordinator = makeCoordinator(
            permissionController: permissions,
            currentMicrophoneStatus: { microphoneStatus },
            setMicrophoneStatus: { microphoneStatus = $0 },
            currentAccessibilityStatus: { accessibilityStatus },
            setAccessibilityStatus: { accessibilityStatus = $0 },
            registerSelectedHotkey: { hotkeyRegistrations.append($0) },
            appendDiagnostic: { diagnostics.append($0) },
            appendDebug: { debugMessages.append($0) },
            isDebugModeEnabled: { false }
        )

        coordinator.refreshPermissionsAfterExternalEvent(reason: "permission-poll")

        XCTAssertEqual(microphoneStatus, .denied)
        XCTAssertEqual(accessibilityStatus, .granted)
        XCTAssertEqual(hotkeyRegistrations, [true])
        XCTAssertEqual(diagnostics, ["Berechtigungen geändert (permission-poll)"])
        XCTAssertTrue(debugMessages.isEmpty)
    }

    func testRequestAccessibilityAccessFromSettingsPromptsRuntimeWhenDenied() async {
        let permissions = AppShellTestPermissionController()
        permissions.accessibilityStatusValue = .denied

        let runtime = AppShellTestDictationRuntime()
        let coordinator = makeCoordinator(
            permissionController: permissions,
            dictationRuntime: runtime,
            currentMicrophoneStatus: { .granted },
            setMicrophoneStatus: { _ in },
            currentAccessibilityStatus: { .denied },
            setAccessibilityStatus: { _ in },
            registerSelectedHotkey: { _ in },
            appendDiagnostic: { _ in },
            appendDebug: { _ in },
            isDebugModeEnabled: { false }
        )

        coordinator.requestAccessibilityAccessFromSettings()

        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(runtime.promptAccessibilityTrustCallCount, 1)
    }

    func testOpenAccessibilitySettingsDelegatesToRuntime() {
        let runtime = AppShellTestDictationRuntime()
        let coordinator = makeCoordinator(
            dictationRuntime: runtime,
            currentMicrophoneStatus: { .granted },
            setMicrophoneStatus: { _ in },
            currentAccessibilityStatus: { .granted },
            setAccessibilityStatus: { _ in },
            registerSelectedHotkey: { _ in },
            appendDiagnostic: { _ in },
            appendDebug: { _ in },
            isDebugModeEnabled: { false }
        )

        coordinator.openAccessibilitySettings()

        XCTAssertEqual(runtime.openAccessibilitySettingsCallCount, 1)
    }

    func testOpenMicrophoneSettingsDelegatesToRuntime() {
        let runtime = AppShellTestDictationRuntime()
        let coordinator = makeCoordinator(
            dictationRuntime: runtime,
            currentMicrophoneStatus: { .granted },
            setMicrophoneStatus: { _ in },
            currentAccessibilityStatus: { .granted },
            setAccessibilityStatus: { _ in },
            registerSelectedHotkey: { _ in },
            appendDiagnostic: { _ in },
            appendDebug: { _ in },
            isDebugModeEnabled: { false }
        )

        coordinator.openMicrophoneSettings()

        XCTAssertEqual(runtime.openMicrophoneSettingsCallCount, 1)
    }

    private func makeCoordinator(
        permissionController: PermissionControlling = AppShellTestPermissionController(),
        dictationRuntime: DictationRuntimeControlling = AppShellTestDictationRuntime(),
        currentMicrophoneStatus: @escaping () -> PermissionStatus,
        setMicrophoneStatus: @escaping (PermissionStatus) -> Void,
        currentAccessibilityStatus: @escaping () -> PermissionStatus,
        setAccessibilityStatus: @escaping (PermissionStatus) -> Void,
        registerSelectedHotkey: @escaping (Bool) -> Void,
        appendDiagnostic: @escaping (String) -> Void,
        appendDebug: @escaping (String) -> Void,
        isDebugModeEnabled: @escaping () -> Bool
    ) -> PermissionCoordinator {
        PermissionCoordinator(
            permissionController: permissionController,
            dictationRuntime: dictationRuntime,
            currentMicrophonePermissionStatus: currentMicrophoneStatus,
            setMicrophonePermissionStatus: setMicrophoneStatus,
            currentAccessibilityPermissionStatus: currentAccessibilityStatus,
            setAccessibilityPermissionStatus: setAccessibilityStatus,
            registerSelectedHotkey: registerSelectedHotkey,
            appendDiagnostic: appendDiagnostic,
            appendDebug: appendDebug,
            isDebugModeEnabled: isDebugModeEnabled
        )
    }
}
#endif
