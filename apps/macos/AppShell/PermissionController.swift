import AVFoundation
import ApplicationServices
import Foundation
import TextTargetMac

/// Gemeinsame AX-/TCC-Logik für Einstellungen und Laufzeit (z. B. `DictationRuntime`).
enum AccessibilityTrust {
    /// Effektiver Bedienungshilfen-Status für den laufenden Prozess (Main-Thread-Pflicht für AX).
    static func isClientProcessTrusted() -> Bool {
        AXTextAccess.permissionSnapshot().permissionState == .granted
    }
}

struct AccessibilityPermissionSnapshot {
    let permissionState: TextTargetPermissionState
    let probeResult: FocusedTextTargetProbeResult
    let frontmostBundleIdentifier: String?
    let currentBundleIdentifier: String?
    let currentBundlePath: String

    var status: PermissionStatus {
        if permissionState == .granted {
            switch probeResult {
            case .apiDisabled:
                return .denied
            case .probeFailed:
                return .stale
            default:
                return .granted
            }
        }

        switch probeResult {
        case .target:
            return .granted
        case .probeFailed:
            return .stale
        case .apiDisabled:
            return .denied
        case .noFocusedElement, .unsupportedTarget, .unableToReadValue:
            return .denied
        }
    }

    var diagnosticsDescription: String {
        "permissions.accessibility trust=\(permissionState.debugLabel) probe=\(probeResult.debugLabel) frontmostBundle=\(frontmostBundleIdentifier ?? "nil") bundleIdentifier=\(currentBundleIdentifier ?? "nil") bundlePath=\(currentBundlePath)"
    }
}

protocol PermissionControlling {
    func microphoneStatus() -> PermissionStatus
    func accessibilityStatus() -> PermissionStatus
    func accessibilitySnapshot() -> AccessibilityPermissionSnapshot
}

struct PermissionController: PermissionControlling {
    func microphoneStatus() -> PermissionStatus {
        PermissionStatus.microphone(from: AVCaptureDevice.authorizationStatus(for: .audio))
    }

    func accessibilityStatus() -> PermissionStatus {
        accessibilitySnapshot().status
    }

    func accessibilitySnapshot() -> AccessibilityPermissionSnapshot {
        let snapshot = AXTextAccess.permissionSnapshot()
        return AccessibilityPermissionSnapshot(
            permissionState: snapshot.permissionState,
            probeResult: snapshot.probeResult,
            frontmostBundleIdentifier: snapshot.frontmostBundleIdentifier,
            currentBundleIdentifier: Bundle.main.bundleIdentifier,
            currentBundlePath: Bundle.main.bundleURL.path
        )
    }
}

private extension TextTargetPermissionState {
    var debugLabel: String {
        switch self {
        case .granted:
            return "granted"
        case .denied:
            return "denied"
        }
    }
}

private extension FocusedTextTargetProbeResult {
    var debugLabel: String {
        switch self {
        case .target:
            return "target"
        case .noFocusedElement:
            return "noFocusedElement"
        case .unsupportedTarget(_, let role, let valueSettable):
            return "unsupportedTarget(role=\(role ?? "nil"),valueSettable=\(valueSettable))"
        case .apiDisabled:
            return "apiDisabled"
        case .unableToReadValue:
            return "unableToReadValue"
        case .probeFailed(_, let reason):
            return "probeFailed(\(reason.rawValue))"
        }
    }
}
