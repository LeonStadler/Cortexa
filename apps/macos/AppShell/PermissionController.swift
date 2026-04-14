import AVFoundation
import ApplicationServices
import Foundation
import TextTargetMac

/// Gemeinsame AX-/TCC-Logik für Einstellungen und Laufzeit (z. B. `DictationRuntime`).
enum AccessibilityTrust {
    /// Effektiver Bedienungshilfen-Status für den laufenden Prozess (Main-Thread-Pflicht für AX).
    static func isClientProcessTrusted() -> Bool {
        AXIsProcessTrusted()
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
