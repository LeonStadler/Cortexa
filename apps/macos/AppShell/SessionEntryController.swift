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
    private let canStartDictation: () -> Bool
    private let dictationBlockedReason: () -> String?
    private let isSessionActive: () -> Bool
    private let holdToDictateEnabled: () -> Bool
    private let shouldRestorePreviousApplicationBeforeStarting: () -> Bool
    private let waitForMenuBarToCloseOperation: () async -> Bool
    private let waitForFrontmostApplicationOperation: (String, UInt64) async -> Bool
    private var holdSessionActive = false
    private var pendingRestoreStartTask: Task<Void, Never>?

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
        canStartDictation: @escaping () -> Bool = { true },
        dictationBlockedReason: @escaping () -> String? = { nil },
        isSessionActive: @escaping () -> Bool,
        holdToDictateEnabled: @escaping () -> Bool,
        shouldRestorePreviousApplicationBeforeStarting: (() -> Bool)? = nil,
        waitForMenuBarToCloseOperation: @escaping () async -> Bool =
            SessionEntryController.defaultWaitForMenuBarToClose,
        waitForFrontmostApplicationOperation: @escaping (String, UInt64) async -> Bool =
            SessionEntryController.defaultWaitForFrontmostApplication
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
        self.canStartDictation = canStartDictation
        self.dictationBlockedReason = dictationBlockedReason
        self.isSessionActive = isSessionActive
        self.holdToDictateEnabled = holdToDictateEnabled
        self.shouldRestorePreviousApplicationBeforeStarting =
            shouldRestorePreviousApplicationBeforeStarting
            ?? {
                SessionEntryController.defaultShouldRestorePreviousApplicationBeforeStarting(
                    ownBundleIdentifier: Bundle.main.bundleIdentifier,
                    frontmostBundleIdentifier: NSWorkspace.shared.frontmostApplication?
                        .bundleIdentifier
                )
            }
        self.waitForMenuBarToCloseOperation = waitForMenuBarToCloseOperation
        self.waitForFrontmostApplicationOperation = waitForFrontmostApplicationOperation
    }

    func resetHoldSessionActive() {
        holdSessionActive = false
    }

    func cancelPendingRestoreStart() {
        pendingRestoreStartTask?.cancel()
        pendingRestoreStartTask = nil
    }

    func handleHoldShortcutPressed() {
        appendAudit("hotkey.hold.press recordingStatus=\(currentRecordingStatus())")
        guard holdToDictateEnabled() else { return }
        guard !holdSessionActive else { return }
        guard !isSessionActive() else { return }
        guard ensureDictationCanStart() else { return }

        cancelPendingRestoreStart()
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
        cancelPendingRestoreStart()
        if isSessionActive() {
            appendAudit("session.toggle stop")
            holdSessionActive = false
            dictationRuntime.toggle(options: currentStartOptions())
            return
        }

        guard ensureDictationCanStart() else { return }
        startTranscriptionForShortcut()
    }

    func toggleTranscriptionFromMenuBar() {
        cancelPendingRestoreStart()
        if isSessionActive() {
            toggleTranscriptionFromUI()
            return
        }

        refreshPermissionStates()

        let options = currentStartOptions()
        appendAudit(
            "session.toggle.menuBar start mode=\(options.mode) language=\(currentSelectedLanguageRawValue()) profile=\(currentPerformanceProfileRawValue())"
        )

        guard ensureDictationCanStart() else { return }

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

        if shouldRestorePreviousApplicationBeforeStarting() {
            restorePreviousApplicationAndStart(options: options, source: "menuBar")
            return
        }

        dictationRuntime.start(options: options)
    }

    func startTranscriptionForShortcut() {
        cancelPendingRestoreStart()
        refreshPermissionStates()

        guard ensureDictationCanStart() else { return }

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

    private func ensureDictationCanStart() -> Bool {
        guard canStartDictation() else {
            if let reason = dictationBlockedReason() {
                appendDiagnostic(reason)
            } else {
                appendDiagnostic("Diktat ist derzeit nicht verfügbar.")
            }
            return false
        }
        return true
    }

    private func restorePreviousApplicationAndStart(
        options: DictationStartOptions,
        source: String,
        preferredApplication: NSRunningApplication? = nil
    ) {
        pendingRestoreStartTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.pendingRestoreStartTask = nil }

            let ownBundleIdentifier = Bundle.main.bundleIdentifier
            let candidateApplication = preferredApplication ?? self.lastExternalApplication()
            let targetApplication: NSRunningApplication? = {
                guard let candidateApplication else { return nil }
                if let ownBundleIdentifier,
                    candidateApplication.bundleIdentifier == ownBundleIdentifier
                {
                    return nil
                }
                return candidateApplication
            }()
            AgentSessionDebugLog.append(
                hypothesisId: "H1",
                location: "MacAppState.restorePreviousApplicationAndStart",
                message: "restore_begin",
                data: [
                    "source": source,
                    "preferredBundle": preferredApplication?.bundleIdentifier ?? "nil",
                    "lastExternalBundle": self.lastExternalApplication()?.bundleIdentifier ?? "nil",
                    "candidateBundle": candidateApplication?.bundleIdentifier ?? "nil",
                    "targetChosenBundle": targetApplication?.bundleIdentifier ?? "nil",
                ]
            )
            if let targetApplication, let bundleIdentifier = targetApplication.bundleIdentifier {
                self.appendDiagnostic(
                    "Aktiviere die letzte App erneut, damit das Ziel-Textfeld fokussiert bleibt.")
                targetApplication.activate(options: [.activateAllWindows])
                let waitOk = await self.waitForFrontmostApplicationOperation(
                    bundleIdentifier, 1_500_000_000)
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
                guard waitOk else {
                    self.appendDiagnostic(
                        "Konnte die Ziel-App nicht zuverlässig fokussieren. Bitte erneut starten."
                    )
                    self.appendAudit("session.restore_abort source=\(source) reason=focus_timeout")
                    return
                }
            } else {
                _ = await self.waitForMenuBarToCloseOperation()
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

            guard !Task.isCancelled else { return }
            self.appendAudit("session.restore_start source=\(source)")
            self.dictationRuntime.start(options: options)
        }
    }

    static func defaultWaitForMenuBarToClose() async -> Bool {
        try? await Task.sleep(nanoseconds: 150_000_000)
        return true
    }

    static func defaultWaitForFrontmostApplication(
        bundleIdentifier: String,
        timeoutNanoseconds: UInt64
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

    static func defaultShouldRestorePreviousApplicationBeforeStarting(
        ownBundleIdentifier: String?,
        frontmostBundleIdentifier: String?
    ) -> Bool {
        return frontmostBundleIdentifier == ownBundleIdentifier
    }

}
