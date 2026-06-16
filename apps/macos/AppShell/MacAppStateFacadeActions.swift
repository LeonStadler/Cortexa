import AIProcessingCore
import ASRCore
import AppKit

extension MacAppState {
    func bindUpdater(_ updaterController: SparkleUpdaterController) {
        lifecyclePolicyFacade.bindUpdater(updaterController)
        updaterConfigured = updaterController.isConfigured
        updaterStatusText = updaterController.statusText
        updaterFeedURLText = updaterController.feedURLDescription
        syncAutomaticUpdateChecks()
        checkForUpdatesHandler = { [weak self, weak updaterController] in
            updaterController?.checkForUpdates()
            self?.updaterStatusText = updaterController?.statusText ?? "Updater nicht verfügbar"
        }
    }

    func bindOpenSettingsHandler(_ handler: @escaping () -> Void) {
        openSettingsHandler = handler
    }

    func openSettingsWindow() {
        if let openSettingsHandler {
            openSettingsHandler()
        } else {
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }

    func openHistorySettingsWindow() {
        selectedSettingsTab = .history
        openSettingsWindow()
    }

    func openAISettingsWindow() {
        selectedSettingsTab = .ai
        openSettingsWindow()
    }

    func toggleVisibleMenuBarLanguage(_ language: DictationLanguage) {
        guard language != .auto else { return }
        if visibleMenuBarLanguages.contains(language.rawValue) {
            visibleMenuBarLanguages.removeAll { $0 == language.rawValue }
        } else {
            visibleMenuBarLanguages.append(language.rawValue)
        }
        sanitizeVisibleMenuBarLanguages()
    }

    func cancelTranscriptionFromUI() {
        sessionEntryController.cancelPendingRestoreStart()
        appendAudit("session.cancel")
        dictationRuntime.cancel()
    }

    func toggleDictationModeFromShortcut() {
        streamingEnabled.toggle()
        appendAudit("mode.toggle streamingEnabled=\(streamingEnabled)")
        appendDiagnostic(
            streamingEnabled
                ? "Live-Einfügen aktiviert. Der Wechsel gilt ab dem nächsten Diktat."
                : "Live-Einfügen deaktiviert. Der Wechsel gilt ab dem nächsten Diktat.")
    }

    func revealAppDataFolder() {
        let folderURL = AppShellStoragePaths.appSupportDirectory()
        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        NSWorkspace.shared.activateFileViewerSelecting([folderURL])
        appendAudit("storage.reveal path=\(folderURL.path)")
    }

    func addRemoteProvider(preset: AIRemoteProviderPreset) {
        aiProviderController.addRemoteProvider(preset: preset)
    }

    func removeSelectedRemoteProvider() {
        aiProviderController.removeSelectedRemoteProvider()
    }

    func updateSelectedRemoteProvider(_ update: (inout AIRemoteProviderConfiguration) -> Void) {
        aiProviderController.updateSelectedRemoteProvider(update)
    }

    func saveSelectedRemoteProviderAPIKey() {
        aiProviderController.saveSelectedRemoteProviderAPIKey()
    }

    func saveSelectedRemoteProvider() {
        aiProviderController.saveSelectedRemoteProvider()
    }

    func refreshSelectedRemoteProviderModels() {
        aiProviderController.refreshSelectedRemoteProviderModels()
    }

    func handleHoldShortcutPressed() {
        sessionEntryController.handleHoldShortcutPressed()
    }

    func handleHoldShortcutReleased() {
        sessionEntryController.handleHoldShortcutReleased()
    }

    func toggleTranscriptionFromUI() {
        sessionEntryController.toggleTranscriptionFromUI()
    }

    func toggleTranscriptionFromMenuBar() {
        sessionEntryController.toggleTranscriptionFromMenuBar()
    }

    func refreshVoiceModelCatalog() {
        speechModelController.refreshVoiceModelCatalog()
    }

    func installVoiceModel(_ descriptor: VoiceModelDescriptor) {
        speechModelController.installVoiceModel(descriptor)
    }

    func removeVoiceModel(_ descriptor: VoiceModelDescriptor) {
        speechModelController.removeVoiceModel(descriptor)
    }

    func setSelectedVoiceModel(_ descriptor: VoiceModelDescriptor) {
        speechModelController.setSelectedVoiceModel(descriptor)
    }

    func assignSelectedVoiceModelToCurrentLanguage() {
        speechModelController.assignSelectedVoiceModelToCurrentLanguage()
    }

    func clearSelectedLanguageVoiceOverride() {
        speechModelController.clearSelectedLanguageVoiceOverride()
    }

    func isVoiceModelInstalled(_ descriptor: VoiceModelDescriptor) -> Bool {
        speechModelController.isVoiceModelInstalled(descriptor)
    }

    func isVoiceModelBusy(_ descriptor: VoiceModelDescriptor) -> Bool {
        speechModelController.isVoiceModelBusy(descriptor)
    }

    func voiceModelOperationState(for descriptor: VoiceModelDescriptor) -> VoiceModelOperationKind?
    {
        speechModelController.voiceModelOperationState(for: descriptor)
    }

    func canUseVoiceModel(_ descriptor: VoiceModelDescriptor, for language: DictationLanguage)
        -> Bool
    {
        speechModelController.canUseVoiceModel(descriptor, for: language)
    }

    func voiceLanguageOptions(for descriptor: VoiceModelDescriptor?) -> [DictationLanguage] {
        speechModelController.voiceLanguageOptions(for: descriptor)
    }

}
