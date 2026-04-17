#if canImport(XCTest)
import AppKit
import Carbon
import XCTest
@testable import AppShellSupport

@MainActor
final class MacAppStateHotkeyFacadeTests: XCTestCase {
    func testRegisterSuppressesConflictingCancelAndModeShortcuts() {
        let hotkeyManager = HotkeyManagerSpy()
        let facade = MacAppStateHotkeyFacade(hotkeyManager: hotkeyManager)
        var diagnostics: [String] = []
        var audits: [String] = []

        facade.register(
            force: true,
            state: HotkeyRegistrationState(
                selectedHotkey: .optionSpace,
                toggleShortcutEnabled: true,
                holdToDictateEnabled: true,
                holdShortcut: .optionShiftSpace,
                cancelShortcutEnabled: true,
                cancelShortcut: .optionSpace,
                modeSwitchShortcutEnabled: true,
                modeSwitchShortcut: .optionSpace,
                hotkeyAdvisory: nil,
                holdShortcutAdvisory: nil,
                cancelShortcutAdvisory: nil,
                modeSwitchShortcutAdvisory: nil
            ),
            appendDiagnostic: { diagnostics.append($0) },
            appendAudit: { audits.append($0) }
        )

        XCTAssertEqual(hotkeyManager.registerCalls.count, 1)
        XCTAssertEqual(hotkeyManager.registerCalls.first?.shortcut, .optionSpace)
        XCTAssertEqual(hotkeyManager.registerCalls.first?.holdShortcut, .optionShiftSpace)
        XCTAssertFalse(hotkeyManager.registerCalls.first?.cancelEnabled ?? true)
        XCTAssertFalse(hotkeyManager.registerCalls.first?.modeEnabled ?? true)
        XCTAssertTrue(diagnostics.contains("Abbrechen-Shortcut wegen Konflikt nicht registriert."))
        XCTAssertTrue(diagnostics.contains("Moduswechsel-Shortcut wegen Konflikt nicht registriert."))
        XCTAssertEqual(
            audits.last,
            "hotkey.register value=\(HotkeyBinding.optionSpace.rawValue) enabled=true hold=\(HotkeyBinding.optionShiftSpace.rawValue) holdEnabled=true cancel=\(HotkeyBinding.optionSpace.rawValue) cancelEnabled=true cancelEffective=false mode=\(HotkeyBinding.optionSpace.rawValue) modeEnabled=true modeEffective=false"
        )
    }

    func testRegisterFailureEmitsFailureDiagnostics() {
        let hotkeyManager = HotkeyManagerSpy()
        hotkeyManager.nextRegisterResult = false
        let facade = MacAppStateHotkeyFacade(hotkeyManager: hotkeyManager)
        var diagnostics: [String] = []
        var audits: [String] = []
        let customBinding = HotkeyBinding(
            keyCode: UInt32(kVK_ANSI_D),
            carbonModifiers: UInt32(optionKey)
        )

        facade.register(
            force: false,
            state: HotkeyRegistrationState(
                selectedHotkey: customBinding,
                toggleShortcutEnabled: true,
                holdToDictateEnabled: false,
                holdShortcut: .optionShiftSpace,
                cancelShortcutEnabled: false,
                cancelShortcut: .optionShiftSpace,
                modeSwitchShortcutEnabled: false,
                modeSwitchShortcut: .optionShiftSpace,
                hotkeyAdvisory: nil,
                holdShortcutAdvisory: nil,
                cancelShortcutAdvisory: nil,
                modeSwitchShortcutAdvisory: nil
            ),
            appendDiagnostic: { diagnostics.append($0) },
            appendAudit: { audits.append($0) }
        )

        XCTAssertEqual(
            diagnostics,
            ["Globaler Shortcut konnte nicht registriert werden: \(customBinding.displayName)"]
        )
        XCTAssertEqual(audits, ["hotkey.register_failed value=\(customBinding.rawValue)"])
    }
}

private final class HotkeyManagerSpy: GlobalHotkeyRegistering {
    struct RegisterCall {
        let shortcut: HotkeyBinding
        let shortcutEnabled: Bool
        let holdShortcut: HotkeyBinding?
        let holdEnabled: Bool
        let cancelShortcut: HotkeyBinding?
        let cancelEnabled: Bool
        let modeShortcut: HotkeyBinding?
        let modeEnabled: Bool
        let force: Bool
    }

    var onToggle: (() -> Void)?
    var onHoldPress: (() -> Void)?
    var onHoldRelease: (() -> Void)?
    var onCancel: (() -> Void)?
    var onModeSwitch: (() -> Void)?

    var nextRegisterResult = true
    private(set) var registerCalls: [RegisterCall] = []

    @discardableResult
    func register(
        shortcut: HotkeyBinding,
        shortcutEnabled: Bool,
        holdShortcut: HotkeyBinding?,
        holdEnabled: Bool,
        cancelShortcut: HotkeyBinding?,
        cancelEnabled: Bool,
        modeShortcut: HotkeyBinding?,
        modeEnabled: Bool,
        force: Bool
    ) -> Bool {
        registerCalls.append(
            RegisterCall(
                shortcut: shortcut,
                shortcutEnabled: shortcutEnabled,
                holdShortcut: holdShortcut,
                holdEnabled: holdEnabled,
                cancelShortcut: cancelShortcut,
                cancelEnabled: cancelEnabled,
                modeShortcut: modeShortcut,
                modeEnabled: modeEnabled,
                force: force
            )
        )
        return nextRegisterResult
    }
}
#endif
