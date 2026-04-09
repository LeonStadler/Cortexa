import AppKit
import Foundation

@MainActor
final class SessionEntryController {
    private let dictationRuntime: DictationRuntimeControlling
    private let currentStartOptions: () -> DictationStartOptions
    private let refreshPermissionStates: () -> Void
    private let dictationCapabilityAllowsDirectInsertion: () -> Bool
    private let lastExternalApplication: () -> NSRunningApplication?
    private let appendAudit: (String) -> Void
    private let appendDiagnostic: (String) -> Void
    private let currentRecordingStatus: () -> String
    private let currentSelectedLanguageRawValue: () -> String
    private let currentPerformanceProfileRawValue: () -> String
    private let currentDictationCapability: () -> DictationCapability
    private let isSessionActive: () -> Bool
    private let holdToDictateEnabled: () -> Bool
    private var holdSessionActive = false

    init(
        dictationRuntime: DictationRuntimeControlling,
        currentStartOptions: @escaping () -> DictationStartOptions,
        refreshPermissionStates: @escaping () -> Void,
        dictationCapabilityAllowsDirectInsertion: @escaping () -> Bool,
        lastExternalApplication: @escaping () -> NSRunningApplication?,
        appendAudit: @escaping (String) -> Void,
        appendDiagnostic: @escaping (String) -> Void,
        currentRecordingStatus: @escaping () -> String,
        currentSelectedLanguageRawValue: @escaping () -> String,
        currentPerformanceProfileRawValue: @escaping () -> String,
        currentDictationCapability: @escaping () -> DictationCapability,
        isSessionActive: @escaping () -> Bool,
        holdToDictateEnabled: @escaping () -> Bool
    ) {
        self.dictationRuntime = dictationRuntime
        self.currentStartOptions = currentStartOptions
        self.refreshPermissionStates = refreshPermissionStates
        self.dictationCapabilityAllowsDirectInsertion = dictationCapabilityAllowsDirectInsertion
        self.lastExternalApplication = lastExternalApplication
        self.appendAudit = appendAudit
        self.appendDiagnostic = appendDiagnostic
        self.currentRecordingStatus = currentRecordingStatus
        self.currentSelectedLanguageRawValue = currentSelectedLanguageRawValue
        self.currentPerformanceProfileRawValue = currentPerformanceProfileRawValue
        self.currentDictationCapability = currentDictationCapability
        self.isSessionActive = isSessionActive
        self.holdToDictateEnabled = holdToDictateEnabled
    }

    func resetHoldSessionActive() {
        holdSessionActive = false
    }

    func handleHoldShortcutPressed() {
        appendAudit("hotkey.hold.press recordingStatus=\(currentRecordingStatus())")
        guard holdToDictateEnabled() else { return }
        guard !holdSessionActive else { return }
        guard !isSessionActive() else { return }

        holdSessionActive = true
        startTranscriptionForShortcut()
    }

    func handleHoldShortcutReleased() {
        appendAudit("hotkey.hold.release recordingStatus=\(currentRecordingStatus())")
        guard holdSessionActive else { return }
        holdSessionActive = false
        guard isSessionActive() else { return }
        dictationRuntime.toggle(options: currentStartOptions())
    }

    func toggleTranscriptionFromUI() {
        if isSessionActive() {
            appendAudit("session.toggle stop")
            holdSessionActive = false
            dictationRuntime.toggle(options: currentStartOptions())
            return
        }

        startTranscriptionForShortcut()
    }

    func toggleTranscriptionFromMenuBar() {
        if isSessionActive() {
            toggleTranscriptionFromUI()
            return
        }

        refreshPermissionStates()

        let options = currentStartOptions()
        appendAudit(
            "session.toggle.menuBar start mode=\(options.mode) language=\(currentSelectedLanguageRawValue()) profile=\(currentPerformanceProfileRawValue())"
        )

        AgentSessionDebugLog.append(
            hypothesisId: "H5",
            location: "MacAppState.toggleTranscriptionFromMenuBar",
            message: "menu_bar_toggle_before_restore_guard",
            data: [
                "allowsDirectInsertion": "\(dictationCapabilityAllowsDirectInsertion())",
                "capability": "\(currentDictationCapability())",
                "lastExternalBundle": lastExternalApplication()?.bundleIdentifier ?? "nil",
                "frontmostBundle": NSWorkspace.shared.frontmostApplication?.bundleIdentifier
                    ?? "nil",
            ]
        )

        guard dictationCapabilityAllowsDirectInsertion() else {
            dictationRuntime.start(options: options)
            return
        }

        restorePreviousApplicationAndStart(options: options, source: "menuBar")
    }

    func startTranscriptionForShortcut() {
        refreshPermissionStates()

        let options = currentStartOptions()
        appendAudit(
            "session.toggle start mode=\(options.mode) language=\(currentSelectedLanguageRawValue()) profile=\(currentPerformanceProfileRawValue())"
        )

        if dictationCapabilityAllowsDirectInsertion(),
            shouldRestorePreviousApplicationBeforeStarting(),
            let previousApplication = lastExternalApplication()
        {
            appendDiagnostic(
                "Wechsle vor dem Start zurück zur letzten App, um das fokussierte Textfeld zu verwenden."
            )
            restorePreviousApplicationAndStart(
                options: options, source: "shortcut", preferredApplication: previousApplication)
            return
        }

        dictationRuntime.toggle(options: options)
    }

    private func restorePreviousApplicationAndStart(
        options: DictationStartOptions,
        source: String,
        preferredApplication: NSRunningApplication? = nil
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }

            let targetApplication = preferredApplication ?? self.lastExternalApplication()
            AgentSessionDebugLog.append(
                hypothesisId: "H1",
                location: "MacAppState.restorePreviousApplicationAndStart",
                message: "restore_begin",
                data: [
                    "source": source,
                    "preferredBundle": preferredApplication?.bundleIdentifier ?? "nil",
                    "lastExternalBundle": self.lastExternalApplication()?.bundleIdentifier ?? "nil",
                    "targetChosenBundle": targetApplication?.bundleIdentifier ?? "nil",
                ]
            )
            if let targetApplication, let bundleIdentifier = targetApplication.bundleIdentifier {
                self.appendDiagnostic(
                    "Aktiviere die letzte App erneut, damit das Ziel-Textfeld fokussiert bleibt.")
                targetApplication.activate(options: [.activateAllWindows])
                let waitOk = await self.waitForFrontmostApplication(bundleIdentifier: bundleIdentifier)
                AgentSessionDebugLog.append(
                    hypothesisId: "H2",
                    location: "MacAppState.restorePreviousApplicationAndStart",
                    message: "after_activate_target_app",
                    data: [
                        "expectedBundle": bundleIdentifier,
                        "waitOk": "\(waitOk)",
                        "frontmostBundle": NSWorkspace.shared.frontmostApplication?.bundleIdentifier
                            ?? "nil",
                    ]
                )
            } else {
                _ = await self.waitForMenuBarToClose()
                AgentSessionDebugLog.append(
                    hypothesisId: "H1",
                    location: "MacAppState.restorePreviousApplicationAndStart",
                    message: "no_target_app_short_delay_only",
                    data: [
                        "frontmostBundle": NSWorkspace.shared.frontmostApplication?.bundleIdentifier
                            ?? "nil"
                    ]
                )
            }

            AgentSessionDebugLog.append(
                hypothesisId: "H4",
                location: "MacAppState.restorePreviousApplicationAndStart",
                message: "about_to_start_dictation",
                data: [
                    "frontmostBundle": NSWorkspace.shared.frontmostApplication?.bundleIdentifier
                        ?? "nil"
                ]
            )

            self.appendAudit("session.restore_start source=\(source)")
            self.dictationRuntime.start(options: options)
        }
    }

    private func waitForMenuBarToClose() async -> Bool {
        try? await Task.sleep(nanoseconds: 150_000_000)
        return true
    }

    private func waitForFrontmostApplication(
        bundleIdentifier: String, timeoutNanoseconds: UInt64 = 1_500_000_000
    ) async -> Bool {
        let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds

        while DispatchTime.now().uptimeNanoseconds < deadline {
            if NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bundleIdentifier {
                return true
            }

            try? await Task.sleep(nanoseconds: 50_000_000)
        }

        return false
    }

    private func shouldRestorePreviousApplicationBeforeStarting() -> Bool {
        let ownBundleIdentifier = Bundle.main.bundleIdentifier
        let frontmostBundleIdentifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        return frontmostBundleIdentifier == ownBundleIdentifier
    }

}
