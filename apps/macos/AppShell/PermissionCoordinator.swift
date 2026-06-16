import AVFoundation
import Foundation

@MainActor
final class PermissionCoordinator {
    private let permissionController: PermissionControlling
    private let dictationRuntime: DictationRuntimeControlling
    private let buildFingerprintStore: BuildPermissionFingerprintStore
    private let currentMicrophonePermissionStatus: () -> PermissionStatus
    private let setMicrophonePermissionStatus: (PermissionStatus) -> Void
    private let currentAccessibilityPermissionStatus: () -> PermissionStatus
    private let setAccessibilityPermissionStatus: (PermissionStatus) -> Void
    private let setAccessibilityPermissionStaleAfterRebuild: (Bool) -> Void
    private let setMicrophonePermissionStaleAfterRebuild: (Bool) -> Void
    private let registerSelectedHotkey: (Bool) -> Void
    private let appendDiagnostic: (String) -> Void
    private let appendDebug: (String) -> Void
    private let isDebugModeEnabled: () -> Bool
    private var permissionPollTask: Task<Void, Never>?
    private var stabilizationTask: Task<Void, Never>?

    init(
        permissionController: PermissionControlling,
        dictationRuntime: DictationRuntimeControlling,
        buildFingerprintStore: BuildPermissionFingerprintStore = .shared,
        currentMicrophonePermissionStatus: @escaping () -> PermissionStatus,
        setMicrophonePermissionStatus: @escaping (PermissionStatus) -> Void,
        currentAccessibilityPermissionStatus: @escaping () -> PermissionStatus,
        setAccessibilityPermissionStatus: @escaping (PermissionStatus) -> Void,
        setAccessibilityPermissionStaleAfterRebuild: @escaping (Bool) -> Void,
        setMicrophonePermissionStaleAfterRebuild: @escaping (Bool) -> Void,
        registerSelectedHotkey: @escaping (Bool) -> Void,
        appendDiagnostic: @escaping (String) -> Void,
        appendDebug: @escaping (String) -> Void,
        isDebugModeEnabled: @escaping () -> Bool
    ) {
        self.permissionController = permissionController
        self.dictationRuntime = dictationRuntime
        self.buildFingerprintStore = buildFingerprintStore
        self.currentMicrophonePermissionStatus = currentMicrophonePermissionStatus
        self.setMicrophonePermissionStatus = setMicrophonePermissionStatus
        self.currentAccessibilityPermissionStatus = currentAccessibilityPermissionStatus
        self.setAccessibilityPermissionStatus = setAccessibilityPermissionStatus
        self.setAccessibilityPermissionStaleAfterRebuild =
            setAccessibilityPermissionStaleAfterRebuild
        self.setMicrophonePermissionStaleAfterRebuild = setMicrophonePermissionStaleAfterRebuild
        self.registerSelectedHotkey = registerSelectedHotkey
        self.appendDiagnostic = appendDiagnostic
        self.appendDebug = appendDebug
        self.isDebugModeEnabled = isDebugModeEnabled
    }

    func stop() {
        permissionPollTask?.cancel()
        permissionPollTask = nil
        stabilizationTask?.cancel()
        stabilizationTask = nil
    }

    func beginLaunchPermissionStabilization() {
        refreshPermissionStates()
        scheduleStabilizedRefreshes(
            reason: "launch",
            delaysNanoseconds: [200_000_000, 800_000_000, 2_000_000_000, 4_000_000_000]
        )
    }

    func refreshPermissionStates() {
        let rawMic = AVCaptureDevice.authorizationStatus(for: .audio)
        let microphoneStatus = permissionController.microphoneStatus()
        setMicrophonePermissionStatus(microphoneStatus)

        let accessibilityStatus = permissionController.accessibilityStatus()
        setAccessibilityPermissionStatus(accessibilityStatus)

        updateTrustedBuildRecords(
            microphoneStatus: microphoneStatus,
            accessibilityStatus: accessibilityStatus
        )

        if isDebugModeEnabled() {
            appendDebug(
                "permissions.microphone raw=\(String(describing: rawMic)) mapped=\(microphoneStatus) staleAfterRebuild=\(buildFingerprintStore.isMicrophoneStale(currentlyTrusted: microphoneStatus == .granted))"
            )
            appendDebug(
                "permissions.accessibility mapped=\(accessibilityStatus) trusted=\(accessibilityStatus == .granted) staleAfterRebuild=\(buildFingerprintStore.isAccessibilityStale(currentlyTrusted: accessibilityStatus == .granted))"
            )
        }
    }

    func refreshPermissionStatesAfterUserFacingPermissionStep() {
        refreshPermissionStates()
        scheduleStabilizedRefreshes(
            reason: "user-facing",
            delaysNanoseconds: [350_000_000, 900_000_000, 1_800_000_000]
        )
    }

    func requestMicrophoneAccessFromSettings() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let status = AVCaptureDevice.authorizationStatus(for: .audio)
            switch status {
            case .authorized:
                self.refreshPermissionStatesAfterUserFacingPermissionStep()
            case .notDetermined:
                let granted = await withCheckedContinuation {
                    (continuation: CheckedContinuation<Bool, Never>) in
                    AVCaptureDevice.requestAccess(for: .audio) { ok in
                        DispatchQueue.main.async {
                            continuation.resume(returning: ok)
                        }
                    }
                }
                self.refreshPermissionStatesAfterUserFacingPermissionStep()
                if !granted {
                    self.appendDiagnostic("Mikrofonzugriff wurde nicht erteilt.")
                }
            case .denied, .restricted:
                if self.buildFingerprintStore.isMicrophoneStale(currentlyTrusted: false) {
                    self.appendMicrophoneRebuildRecoveryHint()
                }
                self.openMicrophoneSettings()
                self.schedulePermissionRefresh()
            @unknown default:
                self.refreshPermissionStatesAfterUserFacingPermissionStep()
            }
        }
    }

    func requestAccessibilityAccessFromSettings() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if self.permissionController.accessibilityStatus() == .granted {
                self.refreshPermissionStatesAfterUserFacingPermissionStep()
                return
            }
            if self.buildFingerprintStore.isAccessibilityStale(currentlyTrusted: false) {
                self.appendAccessibilityRebuildRecoveryHint()
            }
            self.dictationRuntime.promptAccessibilityTrustFromUser()
            self.refreshPermissionStatesAfterUserFacingPermissionStep()
            self.schedulePermissionRefresh()
        }
    }

    func rebindAccessibilityPermissions() {
        appendAccessibilityRebuildRecoveryHint()
        buildFingerprintStore.clearTrustedAccessibility()
        dictationRuntime.openAccessibilitySettings()
        schedulePermissionRefresh(extended: true)
    }

    func rebindMicrophonePermissions() {
        appendMicrophoneRebuildRecoveryHint()
        buildFingerprintStore.clearTrustedMicrophone()
        dictationRuntime.openMicrophoneSettings()
        schedulePermissionRefresh(extended: true)
    }

    func openMicrophoneSettings() {
        dictationRuntime.openMicrophoneSettings()
        schedulePermissionRefresh()
    }

    func openAccessibilitySettings() {
        dictationRuntime.openAccessibilitySettings()
        schedulePermissionRefresh()
    }

    func schedulePermissionRefresh(extended: Bool = false) {
        permissionPollTask?.cancel()
        permissionPollTask = Task { @MainActor [weak self] in
            let delaysNanoseconds: [UInt64] =
                extended
                ? [400_000_000, 1_200_000_000, 2_500_000_000, 5_000_000_000, 8_000_000_000]
                : [400_000_000, 1_200_000_000, 2_500_000_000, 5_000_000_000]
            for delay in delaysNanoseconds {
                try? await Task.sleep(nanoseconds: delay)
                guard !Task.isCancelled else { return }
                self?.refreshPermissionsAfterExternalEvent(reason: "permission-poll")
            }
        }
    }

    func refreshPermissionsAfterExternalEvent(reason: String) {
        let beforeMic = currentMicrophonePermissionStatus()
        let rawAXBefore = permissionController.accessibilityStatus()
        refreshPermissionStates()
        let afterMic = currentMicrophonePermissionStatus()
        let rawAXAfter = permissionController.accessibilityStatus()
        if beforeMic != afterMic || rawAXBefore != rawAXAfter {
            registerSelectedHotkey(true)
            appendDiagnostic("Berechtigungen geändert (\(reason))")
        }
    }

    private func updateTrustedBuildRecords(
        microphoneStatus: PermissionStatus,
        accessibilityStatus: PermissionStatus
    ) {
        if microphoneStatus == .granted {
            buildFingerprintStore.recordTrustedMicrophone()
            setMicrophonePermissionStaleAfterRebuild(false)
        } else {
            setMicrophonePermissionStaleAfterRebuild(
                buildFingerprintStore.isMicrophoneStale(currentlyTrusted: false)
            )
        }

        if accessibilityStatus == .granted {
            buildFingerprintStore.recordTrustedAccessibility()
            setAccessibilityPermissionStaleAfterRebuild(false)
        } else {
            setAccessibilityPermissionStaleAfterRebuild(
                buildFingerprintStore.isAccessibilityStale(currentlyTrusted: false)
            )
        }
    }

    private func scheduleStabilizedRefreshes(reason: String, delaysNanoseconds: [UInt64]) {
        stabilizationTask?.cancel()
        stabilizationTask = Task { @MainActor [weak self] in
            for delay in delaysNanoseconds {
                try? await Task.sleep(nanoseconds: delay)
                guard !Task.isCancelled, let self else { return }
                self.refreshPermissionsAfterExternalEvent(reason: "stabilize-\(reason)")
            }
        }
    }

    private func appendAccessibilityRebuildRecoveryHint() {
        appendDiagnostic(
            """
            Bedienungshilfen: Systemeinstellungen zeigen WisprLocalMac evtl. noch als aktiv, \
            dieser Build ist aber nicht verknüpft (typisch nach Rebuild). \
            1) WisprLocalMac in Bedienungshilfen entfernen (−), \
            2) hier „Freigabe anfragen“ oder Diktat starten, \
            3) WisprLocalMac neu aktivieren.
            """
        )
    }

    private func appendMicrophoneRebuildRecoveryHint() {
        appendDiagnostic(
            """
            Mikrofon: Freigabe bezieht sich vermutlich auf einen älteren Build. \
            WisprLocalMac in Datenschutz → Mikrofon entfernen, App neu starten und Freigabe erneut anfragen.
            """
        )
    }
}
