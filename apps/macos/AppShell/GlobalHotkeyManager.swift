import AppKit
import Carbon
import Foundation

enum HotkeyAdvisorySeverity: String, Equatable {
    case critical
    case warning
}

struct HotkeyAdvisory: Equatable {
    let severity: HotkeyAdvisorySeverity
    let title: String
    let message: String
}

struct HotkeyBinding: Codable, Equatable, Hashable, Identifiable {
    let keyCode: UInt32
    let carbonModifiers: UInt32

    var id: String { rawValue }

    var rawValue: String {
        "\(keyCode):\(carbonModifiers)"
    }

    var displayName: String {
        let modifiers = modifierDisplayParts
        let key = keyDisplayName
        return (modifiers + [key]).joined(separator: " + ")
    }

    var menuBarHint: String {
        modifierMenuBarParts.joined() + keyMenuBarName
    }

    var isValidRecorderSelection: Bool {
        guard !Self.modifierOnlyKeyCodes.contains(keyCode) else { return false }
        return carbonModifiers & Self.supportedModifierMask != 0
    }

    static let optionSpace = HotkeyBinding(keyCode: UInt32(kVK_Space), carbonModifiers: UInt32(optionKey))
    static let optionShiftSpace = HotkeyBinding(keyCode: UInt32(kVK_Space), carbonModifiers: UInt32(optionKey | shiftKey))
    static let controlOptionEscape = HotkeyBinding(keyCode: UInt32(kVK_Escape), carbonModifiers: UInt32(controlKey | optionKey))

    static func from(rawValue: String) -> HotkeyBinding? {
        let parts = rawValue.split(separator: ":")
        guard parts.count == 2,
              let keyCode = UInt32(parts[0]),
              let modifiers = UInt32(parts[1]) else {
            return nil
        }
        return HotkeyBinding(keyCode: keyCode, carbonModifiers: modifiers)
    }

    static func from(event: NSEvent) -> HotkeyBinding? {
        let modifiers = carbonModifiers(from: event.modifierFlags)
        let binding = HotkeyBinding(keyCode: UInt32(event.keyCode), carbonModifiers: modifiers)
        return binding.isValidRecorderSelection ? binding : nil
    }

    private static let supportedModifierMask: UInt32 = UInt32(cmdKey | optionKey | controlKey | shiftKey)

    private static let modifierOnlyKeyCodes: Set<UInt32> = [
        UInt32(kVK_Command),
        UInt32(kVK_RightCommand),
        UInt32(kVK_Shift),
        UInt32(kVK_RightShift),
        UInt32(kVK_Option),
        UInt32(kVK_RightOption),
        UInt32(kVK_Control),
        UInt32(kVK_RightControl),
        UInt32(kVK_CapsLock),
        UInt32(kVK_Function)
    ]

    private var modifierDisplayParts: [String] {
        var parts: [String] = []
        if carbonModifiers & UInt32(controlKey) != 0 { parts.append("Control") }
        if carbonModifiers & UInt32(optionKey) != 0 { parts.append("Option") }
        if carbonModifiers & UInt32(shiftKey) != 0 { parts.append("Shift") }
        if carbonModifiers & UInt32(cmdKey) != 0 { parts.append("Command") }
        return parts
    }

    private var modifierMenuBarParts: [String] {
        var parts: [String] = []
        if carbonModifiers & UInt32(controlKey) != 0 { parts.append("^") }
        if carbonModifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if carbonModifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if carbonModifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        return parts
    }

    private var keyDisplayName: String {
        Self.keyName(for: keyCode)
    }

    private var keyMenuBarName: String {
        Self.keyMenuBarName(for: keyCode)
    }

    private static func keyName(for keyCode: UInt32) -> String {
        switch keyCode {
        case UInt32(kVK_Space): return "Space"
        case UInt32(kVK_Return): return "Return"
        case UInt32(kVK_Tab): return "Tab"
        case UInt32(kVK_Delete): return "Delete"
        case UInt32(kVK_ForwardDelete): return "Forward Delete"
        case UInt32(kVK_Escape): return "Escape"
        case UInt32(kVK_LeftArrow): return "Left Arrow"
        case UInt32(kVK_RightArrow): return "Right Arrow"
        case UInt32(kVK_UpArrow): return "Up Arrow"
        case UInt32(kVK_DownArrow): return "Down Arrow"
        default:
            return translatedKeyString(for: keyCode) ?? "Key \(keyCode)"
        }
    }

    private static func keyMenuBarName(for keyCode: UInt32) -> String {
        switch keyCode {
        case UInt32(kVK_Space): return "Space"
        case UInt32(kVK_Return): return "↩"
        case UInt32(kVK_Tab): return "⇥"
        case UInt32(kVK_Delete): return "⌫"
        case UInt32(kVK_ForwardDelete): return "⌦"
        case UInt32(kVK_Escape): return "Esc"
        case UInt32(kVK_LeftArrow): return "←"
        case UInt32(kVK_RightArrow): return "→"
        case UInt32(kVK_UpArrow): return "↑"
        case UInt32(kVK_DownArrow): return "↓"
        default:
            return translatedKeyString(for: keyCode) ?? "K\(keyCode)"
        }
    }

    private static func translatedKeyString(for keyCode: UInt32) -> String? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }

        let data = unsafeBitCast(layoutData, to: CFData.self) as Data
        return data.withUnsafeBytes { bytes in
            guard let baseAddress = bytes.baseAddress else { return nil }
            let keyboardLayout = baseAddress.assumingMemoryBound(to: UCKeyboardLayout.self)
            var deadKeyState: UInt32 = 0
            let maxLength: Int = 4
            var actualLength: Int = 0
            var chars = [UniChar](repeating: 0, count: maxLength)
            let result = UCKeyTranslate(
                keyboardLayout,
                UInt16(keyCode),
                UInt16(kUCKeyActionDisplay),
                0,
                UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                maxLength,
                &actualLength,
                &chars
            )
            guard result == noErr, actualLength > 0 else { return nil }
            return String(utf16CodeUnits: chars, count: actualLength).uppercased()
        }
    }

    private static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var modifiers: UInt32 = 0
        if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
        if flags.contains(.option) { modifiers |= UInt32(optionKey) }
        if flags.contains(.control) { modifiers |= UInt32(controlKey) }
        if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
        return modifiers
    }
}

enum HotkeyAdvisor {
    static func advisory(for binding: HotkeyBinding, emergencyBinding: HotkeyBinding = .controlOptionEscape) -> HotkeyAdvisory? {
        if binding == emergencyBinding {
            return HotkeyAdvisory(
                severity: .critical,
                title: "Konflikt mit Notfall-Shortcut",
                message: "Diese Tastenkombination ist bereits als Notfall-Stopp reserviert. Wähle für Start/Stop einen anderen Shortcut."
            )
        }

        if matches(binding, keyCode: UInt32(kVK_Space), modifiers: UInt32(cmdKey)) {
            return HotkeyAdvisory(
                severity: .critical,
                title: "Konflikt mit Spotlight",
                message: "Command + Space ist auf macOS typischerweise für Spotlight reserviert und wird den Diktier-Shortcut unzuverlässig machen."
            )
        }

        if matches(binding, keyCode: UInt32(kVK_Space), modifiers: UInt32(controlKey)) {
            return HotkeyAdvisory(
                severity: .critical,
                title: "Konflikt mit Eingabequelle",
                message: "Control + Space wird häufig für den Wechsel der Eingabequelle verwendet. Der Shortcut kollidiert daher oft mit Systemeinstellungen."
            )
        }

        if matches(binding, keyCode: UInt32(kVK_Tab), modifiers: UInt32(cmdKey)) {
            return HotkeyAdvisory(
                severity: .critical,
                title: "Konflikt mit App-Wechsel",
                message: "Command + Tab ist für den App-Switcher reserviert und sollte nicht für Diktiersteuerung verwendet werden."
            )
        }

        if matches(binding, keyCode: UInt32(kVK_ANSI_Q), modifiers: UInt32(cmdKey)) {
            return HotkeyAdvisory(
                severity: .critical,
                title: "Konflikt mit App-Beenden",
                message: "Command + Q beendet die aktive App. Ein Diktier-Shortcut auf dieser Kombination wäre destruktiv."
            )
        }

        if binding.carbonModifiers == UInt32(cmdKey),
           isEditingShortcutKey(binding.keyCode) {
            return HotkeyAdvisory(
                severity: .warning,
                title: "Konflikt mit Standard-App-Shortcut",
                message: "Dieser Shortcut überschneidet sich mit verbreiteten Bearbeitungs- oder Fensterbefehlen wie Kopieren, Einfügen, Sichern oder Fenster schließen."
            )
        }

        if binding.carbonModifiers == UInt32(cmdKey | shiftKey),
           matches(binding, keyCode: UInt32(kVK_Space), modifiers: UInt32(cmdKey | shiftKey)) {
            return HotkeyAdvisory(
                severity: .warning,
                title: "Möglicher Konflikt mit macOS-Suche",
                message: "Command + Shift + Space wird in manchen macOS-Konfigurationen oder Tools ebenfalls für Such- bzw. Spotlight-Funktionen verwendet."
            )
        }

        return nil
    }

    private static func isEditingShortcutKey(_ keyCode: UInt32) -> Bool {
        let commonKeys: Set<UInt32> = [
            UInt32(kVK_ANSI_A),
            UInt32(kVK_ANSI_C),
            UInt32(kVK_ANSI_H),
            UInt32(kVK_ANSI_M),
            UInt32(kVK_ANSI_N),
            UInt32(kVK_ANSI_O),
            UInt32(kVK_ANSI_P),
            UInt32(kVK_ANSI_S),
            UInt32(kVK_ANSI_T),
            UInt32(kVK_ANSI_V),
            UInt32(kVK_ANSI_W),
            UInt32(kVK_ANSI_X),
            UInt32(kVK_ANSI_Z),
            UInt32(kVK_ANSI_Comma)
        ]
        return commonKeys.contains(keyCode)
    }

    private static func matches(_ binding: HotkeyBinding, keyCode: UInt32, modifiers: UInt32) -> Bool {
        binding.keyCode == keyCode && binding.carbonModifiers == modifiers
    }
}

final class GlobalHotkeyManager {
    var onToggle: (() -> Void)?
    var onEmergencyAction: (() -> Void)?
    var onHoldPress: (() -> Void)?
    var onHoldRelease: (() -> Void)?

    private var toggleHotKeyRef: EventHotKeyRef?
    private var emergencyHotKeyRef: EventHotKeyRef?
    private var holdHotKeyRef: EventHotKeyRef?
    private var isRegistered = false
    private var isHandlerInstalled = false
    private(set) var currentShortcut: HotkeyBinding = .optionSpace
    private(set) var currentHoldShortcut: HotkeyBinding? = .optionShiftSpace
    private let toggleHotKeyIdentifier: UInt32 = 1
    private let emergencyHotKeyIdentifier: UInt32 = 2
    private let holdHotKeyIdentifier: UInt32 = 3

    var emergencyShortcutDisplayName: String {
        HotkeyBinding.controlOptionEscape.displayName
    }

    @discardableResult
    func registerDefaultShortcut(force: Bool = false) -> Bool {
        register(
            shortcut: .optionSpace,
            shortcutEnabled: true,
            holdShortcut: .optionShiftSpace,
            holdEnabled: false,
            force: force
        )
    }

    @discardableResult
    func register(
        shortcut: HotkeyBinding,
        shortcutEnabled: Bool,
        holdShortcut: HotkeyBinding?,
        holdEnabled: Bool,
        force: Bool = false
    ) -> Bool {
        if force {
            unregisterDefaultShortcut()
        }

        guard !isRegistered else { return true }

        let signature = OSType(0x57535052) // WSPR
        let toggleHotKeyID = EventHotKeyID(signature: signature, id: toggleHotKeyIdentifier)
        let emergencyHotKeyID = EventHotKeyID(signature: signature, id: emergencyHotKeyIdentifier)
        let holdHotKeyID = EventHotKeyID(signature: signature, id: holdHotKeyIdentifier)

        if shortcutEnabled {
            let toggleRegisterStatus = RegisterEventHotKey(
                shortcut.keyCode,
                shortcut.carbonModifiers,
                toggleHotKeyID,
                GetApplicationEventTarget(),
                0,
                &toggleHotKeyRef
            )
            guard toggleRegisterStatus == noErr else {
                toggleHotKeyRef = nil
                isRegistered = false
                return false
            }
            currentShortcut = shortcut
        }

        let emergencyBinding = HotkeyBinding.controlOptionEscape
        let emergencyRegisterStatus = RegisterEventHotKey(
            emergencyBinding.keyCode,
            emergencyBinding.carbonModifiers,
            emergencyHotKeyID,
            GetApplicationEventTarget(),
            0,
            &emergencyHotKeyRef
        )
        guard emergencyRegisterStatus == noErr else {
            unregisterDefaultShortcut()
            isRegistered = false
            return false
        }

        if holdEnabled, let holdShortcut {
            let holdRegisterStatus = RegisterEventHotKey(
                holdShortcut.keyCode,
                holdShortcut.carbonModifiers,
                holdHotKeyID,
                GetApplicationEventTarget(),
                0,
                &holdHotKeyRef
            )
            guard holdRegisterStatus == noErr else {
                unregisterDefaultShortcut()
                isRegistered = false
                return false
            }
            currentHoldShortcut = holdShortcut
        } else {
            currentHoldShortcut = holdShortcut
        }

        if !isHandlerInstalled {
            var eventSpecs = [
                EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
                EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
            ]

            InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
                guard let userData, let event else { return noErr }

                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                let eventKind = GetEventKind(event)

                switch hotKeyID.id {
                case manager.toggleHotKeyIdentifier where eventKind == UInt32(kEventHotKeyPressed):
                    manager.onToggle?()
                case manager.emergencyHotKeyIdentifier where eventKind == UInt32(kEventHotKeyPressed):
                    manager.onEmergencyAction?()
                case manager.holdHotKeyIdentifier where eventKind == UInt32(kEventHotKeyPressed):
                    manager.onHoldPress?()
                case manager.holdHotKeyIdentifier where eventKind == UInt32(kEventHotKeyReleased):
                    manager.onHoldRelease?()
                default:
                    break
                }
                return noErr
            }, UInt32(eventSpecs.count), &eventSpecs, Unmanaged.passUnretained(self).toOpaque(), nil)
            isHandlerInstalled = true
        }

        isRegistered = true
        return true
    }

    func unregisterDefaultShortcut() {
        if let toggleHotKeyRef {
            UnregisterEventHotKey(toggleHotKeyRef)
            self.toggleHotKeyRef = nil
        }
        if let emergencyHotKeyRef {
            UnregisterEventHotKey(emergencyHotKeyRef)
            self.emergencyHotKeyRef = nil
        }
        if let holdHotKeyRef {
            UnregisterEventHotKey(holdHotKeyRef)
            self.holdHotKeyRef = nil
        }
        isRegistered = false
    }

    deinit {
        unregisterDefaultShortcut()
    }
}
