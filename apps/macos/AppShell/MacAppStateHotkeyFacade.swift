import Foundation

struct HotkeyRegistrationState {
    let selectedHotkey: HotkeyBinding
    let toggleShortcutEnabled: Bool
    let holdToDictateEnabled: Bool
    let holdShortcut: HotkeyBinding
    let cancelShortcutEnabled: Bool
    let cancelShortcut: HotkeyBinding
    let modeSwitchShortcutEnabled: Bool
    let modeSwitchShortcut: HotkeyBinding
    let hotkeyAdvisory: HotkeyAdvisory?
    let holdShortcutAdvisory: HotkeyAdvisory?
    let cancelShortcutAdvisory: HotkeyAdvisory?
    let modeSwitchShortcutAdvisory: HotkeyAdvisory?
}

@MainActor
final class MacAppStateHotkeyFacade {
    private let hotkeyManager: GlobalHotkeyRegistering

    init(hotkeyManager: GlobalHotkeyRegistering) {
        self.hotkeyManager = hotkeyManager
    }

    func register(
        force: Bool,
        state: HotkeyRegistrationState,
        appendDiagnostic: (String) -> Void,
        appendAudit: (String) -> Void
    ) {
        let effectiveCancelShortcutEnabled =
            state.cancelShortcutEnabled
            && !(state.toggleShortcutEnabled && state.cancelShortcut == state.selectedHotkey)
            && !(state.holdToDictateEnabled && state.cancelShortcut == state.holdShortcut)
        let effectiveModeSwitchShortcutEnabled =
            state.modeSwitchShortcutEnabled
            && !(state.toggleShortcutEnabled && state.modeSwitchShortcut == state.selectedHotkey)
            && !(state.holdToDictateEnabled && state.modeSwitchShortcut == state.holdShortcut)
            && !(effectiveCancelShortcutEnabled && state.modeSwitchShortcut == state.cancelShortcut)

        let didRegister = hotkeyManager.register(
            shortcut: state.selectedHotkey,
            shortcutEnabled: state.toggleShortcutEnabled,
            holdShortcut: state.holdShortcut,
            holdEnabled: state.holdToDictateEnabled,
            cancelShortcut: state.cancelShortcut,
            cancelEnabled: effectiveCancelShortcutEnabled,
            modeShortcut: state.modeSwitchShortcut,
            modeEnabled: effectiveModeSwitchShortcutEnabled,
            force: force
        )

        if didRegister {
            appendDiagnostic(
                state.toggleShortcutEnabled
                    ? "Globaler Shortcut aktiv: \(state.selectedHotkey.displayName)"
                    : "Globaler Shortcut deaktiviert."
            )
            appendDiagnostic(
                state.holdToDictateEnabled
                    ? "Hold-to-dictate aktiv: \(state.holdShortcut.displayName)"
                    : "Hold-to-dictate deaktiviert."
            )
            appendDiagnostic(
                effectiveCancelShortcutEnabled
                    ? "Abbrechen-Shortcut aktiv: \(state.cancelShortcut.displayName)"
                    : state.cancelShortcutEnabled
                        ? "Abbrechen-Shortcut wegen Konflikt nicht registriert."
                        : "Abbrechen-Shortcut deaktiviert."
            )
            appendDiagnostic(
                effectiveModeSwitchShortcutEnabled
                    ? "Moduswechsel-Shortcut aktiv: \(state.modeSwitchShortcut.displayName)"
                    : state.modeSwitchShortcutEnabled
                        ? "Moduswechsel-Shortcut wegen Konflikt nicht registriert."
                        : "Moduswechsel-Shortcut deaktiviert."
            )
            if let hotkeyAdvisory = state.hotkeyAdvisory {
                appendDiagnostic(
                    "Shortcut-Hinweis: \(hotkeyAdvisory.title) – \(hotkeyAdvisory.message)"
                )
            }
            if state.holdToDictateEnabled, let holdShortcutAdvisory = state.holdShortcutAdvisory {
                appendDiagnostic(
                    "Hold-Hinweis: \(holdShortcutAdvisory.title) – \(holdShortcutAdvisory.message)"
                )
            }
            if state.cancelShortcutEnabled, let cancelShortcutAdvisory = state.cancelShortcutAdvisory
            {
                appendDiagnostic(
                    "Abbrechen-Hinweis: \(cancelShortcutAdvisory.title) – \(cancelShortcutAdvisory.message)"
                )
            }
            if state.modeSwitchShortcutEnabled,
                let modeSwitchShortcutAdvisory = state.modeSwitchShortcutAdvisory
            {
                appendDiagnostic(
                    "Modus-Hinweis: \(modeSwitchShortcutAdvisory.title) – \(modeSwitchShortcutAdvisory.message)"
                )
            }
            appendAudit(
                "hotkey.register value=\(state.selectedHotkey.rawValue) enabled=\(state.toggleShortcutEnabled) hold=\(state.holdShortcut.rawValue) holdEnabled=\(state.holdToDictateEnabled) cancel=\(state.cancelShortcut.rawValue) cancelEnabled=\(state.cancelShortcutEnabled) cancelEffective=\(effectiveCancelShortcutEnabled) mode=\(state.modeSwitchShortcut.rawValue) modeEnabled=\(state.modeSwitchShortcutEnabled) modeEffective=\(effectiveModeSwitchShortcutEnabled)"
            )
        } else {
            appendDiagnostic(
                "Globaler Shortcut konnte nicht registriert werden: \(state.selectedHotkey.displayName)"
            )
            appendAudit("hotkey.register_failed value=\(state.selectedHotkey.rawValue)")
        }
    }
}

extension MacAppState {
    func registerSelectedHotkey(force: Bool) {
        hotkeyRegistrationFacade.register(
            force: force,
            state: hotkeyRegistrationState(),
            appendDiagnostic: { [weak self] line in
                self?.appendDiagnostic(line)
            },
            appendAudit: { [weak self] line in
                self?.appendAudit(line)
            }
        )
    }

    private func hotkeyRegistrationState() -> HotkeyRegistrationState {
        HotkeyRegistrationState(
            selectedHotkey: selectedHotkey,
            toggleShortcutEnabled: toggleShortcutEnabled,
            holdToDictateEnabled: holdToDictateEnabled,
            holdShortcut: holdShortcut,
            cancelShortcutEnabled: cancelShortcutEnabled,
            cancelShortcut: cancelShortcut,
            modeSwitchShortcutEnabled: modeSwitchShortcutEnabled,
            modeSwitchShortcut: modeSwitchShortcut,
            hotkeyAdvisory: hotkeyAdvisory,
            holdShortcutAdvisory: holdShortcutAdvisory,
            cancelShortcutAdvisory: cancelShortcutAdvisory,
            modeSwitchShortcutAdvisory: modeSwitchShortcutAdvisory
        )
    }
}
