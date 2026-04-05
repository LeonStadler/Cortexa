import AVFoundation
import ApplicationServices
import Foundation

/// Gemeinsame AX-/TCC-Logik für Einstellungen und Laufzeit (z. B. `DictationRuntime`).
enum AccessibilityTrust {
    /// Effektiver Bedienungshilfen-Status für den laufenden Prozess (Main-Thread-Pflicht für AX).
    static func isClientProcessTrusted() -> Bool {
        if Thread.isMainThread {
            return queryTrustedOnMain()
        }
        var trusted = false
        DispatchQueue.main.sync {
            trusted = queryTrustedOnMain()
        }
        return trusted
    }

    private static func queryTrustedOnMain() -> Bool {
        if AXIsProcessTrusted() {
            return true
        }
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: false] as CFDictionary
        if AXIsProcessTrustedWithOptions(options) {
            return true
        }
        // Menüleisten-Apps (`LSUIElement`) und manche Debug-Builds: TCC-Schalter ist an, aber
        // `AXIsProcessTrusted` bleibt fälschlich false. Ohne `apiDisabled` antwortet die AX-API.
        return accessibilityAPIIndicatesProcessAllowed()
    }

    /// Fokus-unabhängig: `kAXFocusedUIElementAttribute` wechselt mit dem aktiven Fenster und erzeugt falsche
    /// „Verweigert“-Zustände in den Einstellungen. Die Rolle der eigenen App-AX-Instanz kippt nur bei echtem API-Lock.
    private static func accessibilityAPIIndicatesProcessAllowed() -> Bool {
        let pid = ProcessInfo.processInfo.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)
        var role: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(
            appElement,
            kAXRoleAttribute as CFString,
            &role
        )
        return status != .apiDisabled
    }
}

protocol PermissionControlling {
    func microphoneStatus() -> PermissionStatus
    func accessibilityStatus() -> PermissionStatus
}

struct PermissionController: PermissionControlling {
    func microphoneStatus() -> PermissionStatus {
        PermissionStatus.microphone(from: AVCaptureDevice.authorizationStatus(for: .audio))
    }

    func accessibilityStatus() -> PermissionStatus {
        PermissionStatus.accessibility(isTrusted: AccessibilityTrust.isClientProcessTrusted())
    }
}
