import AVFoundation
import ApplicationServices
import Foundation

protocol PermissionControlling {
    func microphoneStatus() -> PermissionStatus
    func accessibilityStatus() -> PermissionStatus
}

struct PermissionController: PermissionControlling {
    func microphoneStatus() -> PermissionStatus {
        PermissionStatus.microphone(from: AVCaptureDevice.authorizationStatus(for: .audio))
    }

    func accessibilityStatus() -> PermissionStatus {
        PermissionStatus.accessibility(isTrusted: AXIsProcessTrusted())
    }
}
