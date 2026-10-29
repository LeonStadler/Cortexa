import ASRCore
import AppKit
import SwiftUI

extension MacAppState {
    var activeVoiceModel: VoiceModelDescriptor? {
        VoiceModelCapabilityPolicy().effectiveModel(
            for: selectedLanguage,
            selectedModelID: selectedVoiceModelID,
            overrides: voiceLanguageOverrides,
            catalog: voiceModels,
            installedFiles: installedVoiceModelFileNames
        )
    }

    func supportsCapability(_ choice: VoiceModelCapabilityChoice) -> Bool {
        if case .language(let language) = choice {
            if language != .auto,
                let override = voiceLanguageOverrides.first(where: {
                    $0.languageCode == language.rawValue
                }),
                let model = voiceModels.first(where: { $0.id == override.modelID }),
                isVoiceModelInstalled(model),
                voiceProviders.contains(where: { $0.id == model.providerID && $0.isAvailable }),
                VoiceModelCapabilityPolicy().supports(language: language, model: model) {
                return true
            }
            guard let selectedVoiceModel,
                isVoiceModelInstalled(selectedVoiceModel),
                voiceProviders.contains(where: {
                    $0.id == selectedVoiceModel.providerID && $0.isAvailable
                }) else { return false }
            return VoiceModelCapabilityPolicy().supports(language: language, model: selectedVoiceModel)
        }
        guard let activeVoiceModel else { return false }
        return VoiceModelCapabilityPolicy().supports(
            choice, model: activeVoiceModel, currentLanguage: selectedLanguage)
    }

    var effectiveStreamingEnabled: Bool {
        streamingEnabled && supportsCapability(.liveText)
    }

    var effectiveTranslationOutputMode: TranslationOutputMode {
        supportsCapability(.translation(translationOutputMode)) ? translationOutputMode : .original
    }

    var effectivePerformanceProfile: DictationPerformance {
        supportsCapability(.quality(performanceProfile)) ? performanceProfile : .auto
    }

    var capabilityLanguageBinding: Binding<DictationLanguage> {
        Binding(get: { self.selectedLanguage }, set: { self.requestVoiceCapability(.language($0)) })
    }

    var capabilityTranslationBinding: Binding<TranslationOutputMode> {
        Binding(get: { self.effectiveTranslationOutputMode },
            set: { self.requestVoiceCapability(.translation($0)) })
    }

    var capabilityQualityBinding: Binding<DictationPerformance> {
        Binding(get: { self.effectivePerformanceProfile },
            set: { self.requestVoiceCapability(.quality($0)) })
    }

    var capabilityLiveTextBinding: Binding<Bool> {
        Binding(get: { self.effectiveStreamingEnabled }, set: { value in
            if value { self.requestVoiceCapability(.liveText) }
            else { self.streamingEnabled = false }
        })
    }

    func selectActiveVoiceModel(_ model: VoiceModelDescriptor) {
        requestVoiceModelSelection(model)
    }

    func requestVoiceModelSelection(_ model: VoiceModelDescriptor) {
        guard model.installState != .unavailable,
            !isVoiceModelInstalled(model)
                || voiceProviders.contains(where: { $0.id == model.providerID && $0.isAvailable })
        else {
            showCapabilityModelManagementAlert()
            return
        }
        let policy = VoiceModelCapabilityPolicy()
        let languages = policy.supportedLanguages(for: model)
        guard let suggestedLanguage = policy.suggestedLanguage(
            for: model, currentLanguage: selectedLanguage
        ) else {
            showCapabilityModelManagementAlert()
            return
        }

        let conflicts = incompatibleActiveCapabilities(model: model, language: suggestedLanguage)
        let isInstalled = isVoiceModelInstalled(model)
        guard !conflicts.isEmpty || !isInstalled else {
            applyVoiceModelSelection(model, language: suggestedLanguage)
            return
        }

        let revision = voiceSelectionRevision
        if autoResolveVoiceModelConflicts, isInstalled {
            applyVoiceModelSelection(model, language: suggestedLanguage)
            return
        }

        let alert = NSAlert()
        alert.messageText = capabilityText("Modell und Einstellungen anpassen", "Adjust model settings")
        alert.informativeText = modelSelectionMessage(
            model: model,
            originalLanguage: selectedLanguage,
            language: suggestedLanguage
        )
        let languagePopup: NSPopUpButton?
        if languages.contains(selectedLanguage) {
            languagePopup = nil
        } else {
            languagePopup = languageSelectionPopup(
                languages: languages,
                selected: suggestedLanguage
            )
        }
        let alternatives = languagePopup == nil
            ? suggestedModelsPreservingCurrentCapabilities(from: model, language: suggestedLanguage)
            : []
        let alternativePopup = alternatives.isEmpty ? nil : modelSelectionPopup(alternatives, for: nil)
        if !conflicts.isEmpty || languagePopup != nil || alternativePopup != nil {
            alert.accessoryView = modelSelectionAccessory(
                conflicts: conflicts,
                languagePopup: languagePopup,
                alternativePopup: alternativePopup,
                alternativeModelsAreInstalled: alternatives.first.map(isVoiceModelInstalled) ?? false
            )
        }
        configureAutoResolveSuppression(on: alert)
        if alternativePopup != nil {
            let alternativesInstalled = alternatives.first.map(isVoiceModelInstalled) ?? false
            alert.addButton(withTitle: capabilityText(
                isInstalled ? "Auswahl übernehmen" : "Herunterladen und übernehmen",
                isInstalled ? "Use selected model" : "Download and use selected model"
            ))
            alert.addButton(withTitle: capabilityText(
                alternativesInstalled ? "Kompatibles Modell übernehmen" : "Kompatibles Modell herunterladen",
                alternativesInstalled ? "Use compatible model" : "Download compatible model"
            ))
        } else {
            alert.addButton(withTitle: capabilityText(
                isInstalled ? "Auswahl übernehmen" : "Herunterladen und übernehmen",
                isInstalled ? "Use selected model" : "Download and use selected model"
            ))
        }
        alert.addButton(withTitle: capabilityText("Abbrechen", "Cancel"))
        NSApplication.shared.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        guard voiceSelectionRevision == revision else { return }
        let shouldAutoResolve = alert.suppressionButton?.state == .on
        let chosenModel: VoiceModelDescriptor?
        if let alternativePopup, response == .alertSecondButtonReturn {
            chosenModel = selectedModel(from: alternativePopup, options: alternatives)
        } else if response == .alertFirstButtonReturn {
            chosenModel = model
        } else {
            chosenModel = nil
        }
        guard let chosenModel else { return }
        let language: DictationLanguage
        if chosenModel.id == model.id {
            guard let selected = selectedLanguage(
                from: languagePopup, options: languages, fallback: suggestedLanguage
            ) else { return }
            language = selected
        } else {
            language = suggestedLanguage
        }
        applyOrInstallVoiceModelSelection(
            chosenModel,
            language: language,
            revision: revision,
            shouldAutoResolve: shouldAutoResolve
        )
    }

    private func applyOrInstallVoiceModelSelection(
        _ model: VoiceModelDescriptor,
        language: DictationLanguage,
        revision: UInt64,
        shouldAutoResolve: Bool
    ) {
        guard isVoiceModelInstalled(model) else {
            speechModelController.installVoiceModelForCapability(model) { [weak self] in
                guard let self, self.voiceSelectionRevision == revision else { return }
                self.saveAutoResolveChoice(shouldAutoResolve)
                self.applyVoiceModelSelection(model, language: language)
            }
            return
        }
        saveAutoResolveChoice(shouldAutoResolve)
        applyVoiceModelSelection(model, language: language)
    }

    func requestVoiceCapability(_ choice: VoiceModelCapabilityChoice) {
        guard let source = activeVoiceModel ?? selectedVoiceModel else {
            applyVoiceCapability(choice, model: nil)
            return
        }
        if supportsCapability(choice) {
            applyVoiceCapability(choice, model: nil)
            return
        }

        let policy = VoiceModelCapabilityPolicy()
        let revision = voiceSelectionRevision
        let usableCatalog = voiceModels.filter { model in
            let installed = policy.isInstalled(model, files: installedVoiceModelFileNames)
            return !installed || voiceProviders.contains {
                $0.id == model.providerID && $0.isAvailable
            }
        }
        let suggestions = policy.suggestedModels(
            for: choice,
            currentModel: source,
            currentLanguage: choice.requiredLanguage(current: selectedLanguage),
            catalog: usableCatalog,
            installedFiles: installedVoiceModelFileNames
        )
        guard !suggestions.isEmpty else {
            showCapabilityModelManagementAlert()
            return
        }
        if autoResolveVoiceModelConflicts,
            let installedSuggestion = policy.bestInstalledSuggestion(
                for: choice,
                currentModel: source,
                currentLanguage: choice.requiredLanguage(current: selectedLanguage),
                catalog: usableCatalog,
                installedFiles: installedVoiceModelFileNames
            ) {
            applyVoiceCapability(choice, model: installedSuggestion)
            return
        }

        let installedSuggestions = suggestions.filter(isVoiceModelInstalled)
        let modelOptions = installedSuggestions.isEmpty ? suggestions : installedSuggestions
        let alert = NSAlert()
        alert.messageText = capabilityText("Modellwechsel erforderlich", "Change speech model")
        alert.informativeText = capabilityText(
            isVoiceModelInstalled(modelOptions[0])
                ? "Vorschlag: Wähle ein installiertes Modell, das diese Auswahl unterstützt."
                : "Kein installiertes Modell passt. Die aufgeführten Modelle müssen nach deiner Bestätigung heruntergeladen werden.",
            isVoiceModelInstalled(modelOptions[0])
                ? "Suggested: choose an installed model that supports this option."
                : "No installed model matches. The listed models will download only after you confirm."
        )
        let modelPopup = modelSelectionPopup(modelOptions, for: choice)
        alert.accessoryView = accessoryStack(
            label: capabilityText(
                isVoiceModelInstalled(modelOptions[0]) ? "Installiertes Modell" : "Modell zum Herunterladen",
                isVoiceModelInstalled(modelOptions[0]) ? "Installed model" : "Model to download"
            ),
            control: modelPopup
        )
        configureAutoResolveSuppression(on: alert)
        alert.addButton(withTitle: capabilityText(
            isVoiceModelInstalled(modelOptions[0]) ? "Modell übernehmen" : "Herunterladen und übernehmen",
            isVoiceModelInstalled(modelOptions[0]) ? "Use model" : "Download and use model"
        ))
        alert.addButton(withTitle: capabilityText("Abbrechen", "Cancel"))
        NSApplication.shared.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn,
            voiceSelectionRevision == revision,
            let selectedModel = selectedModel(from: modelPopup, options: modelOptions)
        else { return }
        let shouldAutoResolve = alert.suppressionButton?.state == .on
        applyOrInstallCapabilityChoice(
            choice,
            model: selectedModel,
            revision: revision,
            sourceID: source.id,
            shouldAutoResolve: shouldAutoResolve
        )
    }

    func resetVoiceModelCapabilityHints() {
        autoResolveVoiceModelConflicts = false
    }

    private func applyOrInstallCapabilityChoice(
        _ choice: VoiceModelCapabilityChoice,
        model: VoiceModelDescriptor,
        revision: UInt64,
        sourceID: String,
        shouldAutoResolve: Bool
    ) {
        guard isVoiceModelInstalled(model) else {
            speechModelController.installVoiceModelForCapability(model) { [weak self] in
                guard let self,
                    self.voiceSelectionRevision == revision,
                    self.activeVoiceModel?.id == sourceID else { return }
                self.saveAutoResolveChoice(shouldAutoResolve)
                self.applyVoiceCapability(choice, model: model)
            }
            return
        }
        saveAutoResolveChoice(shouldAutoResolve)
        applyVoiceCapability(choice, model: model)
    }

    private func applyVoiceModelSelection(
        _ model: VoiceModelDescriptor,
        language: DictationLanguage
    ) {
        let previousLanguage = selectedLanguage
        let hadOverride = selectedLanguageVoiceOverride != nil
        setSelectedVoiceModel(model)
        guard selectedVoiceModelID == model.id else { return }
        if selectedLanguage != language { selectedLanguage = language }
        if shouldUpdateVoiceModelLanguageOverride(
            previousLanguage: previousLanguage,
            selectedLanguage: selectedLanguage,
            hadOverride: hadOverride
        ) {
            voiceLanguageOverrides.removeAll { $0.languageCode == previousLanguage.rawValue }
            if VoiceModelCapabilityPolicy().supports(language: selectedLanguage, model: model) {
                voiceLanguageOverrides.append(VoiceLanguageOverride(
                    languageCode: selectedLanguage.rawValue, modelID: model.id))
            }
            speechModelController.sanitizeSpeechModelSelections()
        }
    }

    private func incompatibleActiveCapabilities(
        model: VoiceModelDescriptor,
        language: DictationLanguage
    ) -> [String] {
        let policy = VoiceModelCapabilityPolicy()
        var conflicts: [String] = []
        if !policy.supports(language: language, model: model) {
            conflicts.append(capabilityText("Eingabesprache", "Input language"))
        }
        if translationOutputMode == .english,
            !policy.supports(.translation(.english), model: model, currentLanguage: language) {
            conflicts.append(capabilityText("Übersetzung", "Translation"))
        }
        if streamingEnabled && !policy.supports(.liveText, model: model, currentLanguage: language) {
            conflicts.append(capabilityText("Live-Text", "Live text"))
        }
        if performanceProfile != .auto,
            !policy.supports(.quality(performanceProfile), model: model, currentLanguage: language) {
            conflicts.append(capabilityText("Qualitätsprofil", "Quality profile"))
        }
        return conflicts
    }

    private func suggestedModelsPreservingCurrentCapabilities(
        from selectedModel: VoiceModelDescriptor,
        language: DictationLanguage
    ) -> [VoiceModelDescriptor] {
        var choices: [VoiceModelCapabilityChoice] = []
        if translationOutputMode == .english { choices.append(.translation(.english)) }
        if streamingEnabled { choices.append(.liveText) }
        if performanceProfile != .auto { choices.append(.quality(performanceProfile)) }

        let policy = VoiceModelCapabilityPolicy()
        let catalog = voiceModels.filter { model in
            !isVoiceModelInstalled(model)
                || voiceProviders.contains { $0.id == model.providerID && $0.isAvailable }
        }
        let suggestions = policy.suggestedModels(
            preserving: choices,
            currentModel: selectedModel,
            currentLanguage: language,
            catalog: catalog,
            installedFiles: installedVoiceModelFileNames
        )
        let installed = suggestions.filter(isVoiceModelInstalled)
        return installed.isEmpty ? suggestions : installed
    }

    private func modelSelectionMessage(
        model: VoiceModelDescriptor,
        originalLanguage: DictationLanguage,
        language: DictationLanguage
    ) -> String {
        let languageName = language.localizedDisplayName(
            interfaceLanguageCode: capabilityAppLanguage.embeddedInterfaceCode
        )
        let languageChange = originalLanguage == language
            ? ""
            : capabilityText(
                "\nDie Eingabesprache wechselt von \(originalLanguage.localizedDisplayName(interfaceLanguageCode: capabilityAppLanguage.embeddedInterfaceCode)) zu \(languageName).",
                "\nThe input language changes from \(originalLanguage.localizedDisplayName(interfaceLanguageCode: capabilityAppLanguage.embeddedInterfaceCode)) to \(languageName)."
            )
        return capabilityText(
            "\(model.displayName) unterstützt \(languageName).\(languageChange)",
            "\(model.displayName) supports \(languageName).\(languageChange)"
        )
    }

    private func modelSelectionPopup(
        _ models: [VoiceModelDescriptor],
        for choice: VoiceModelCapabilityChoice?
    ) -> NSPopUpButton {
        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 360, height: 26))
        popup.setAccessibilityLabel(capabilityText("Kompatibles Sprachmodell", "Compatible speech model"))
        for model in models {
            let state = isVoiceModelInstalled(model)
                ? capabilityText("installiert", "installed")
                : capabilityText("Download", "download")
            let language = choice?.requiredLanguage(current: selectedLanguage) ?? selectedLanguage
            let paused = incompatibleActiveCapabilities(model: model, language: language)
            let pauseDescription = paused.isEmpty
                ? ""
                : capabilityText(" · pausiert: \(paused.joined(separator: ", "))", " · pauses: \(paused.joined(separator: ", "))")
            popup.addItem(withTitle: "\(model.displayName) · \(state)\(pauseDescription)")
            popup.lastItem?.representedObject = model.id
        }
        return popup
    }

    private func modelSelectionAccessory(
        conflicts: [String],
        languagePopup: NSPopUpButton?,
        alternativePopup: NSPopUpButton?,
        alternativeModelsAreInstalled: Bool
    ) -> NSView {
        var views: [NSView] = []
        if !conflicts.isEmpty {
            let title = NSTextField(labelWithString: capabilityText(
                "Wird pausiert (Einstellung bleibt gespeichert)",
                "Paused (preference stays saved)"
            ))
            title.font = .systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold)
            views.append(title)
            views.append(contentsOf: conflicts.map {
                NSTextField(wrappingLabelWithString: "• \($0)")
            })
        }
        if let languagePopup {
            views.append(accessoryStack(
                label: capabilityText("Diktatsprache", "Dictation language"),
                control: languagePopup
            ))
        }
        if let alternativePopup {
            views.append(accessoryStack(
                label: capabilityText(
                    alternativeModelsAreInstalled
                        ? "Vorschlag: kompatibles installiertes Modell"
                        : "Vorschlag: kompatibles Modell zum Download",
                    alternativeModelsAreInstalled
                        ? "Suggestion: compatible installed model"
                        : "Suggestion: compatible model to download"
                ),
                control: alternativePopup
            ))
        }
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        let contentHeight = views.reduce(CGFloat(0)) { $0 + max($1.frame.height, 20) }
        let spacingHeight = CGFloat(max(views.count - 1, 0)) * stack.spacing
        stack.frame = NSRect(x: 0, y: 0, width: 380, height: contentHeight + spacingHeight)
        return stack
    }

    private func languageSelectionPopup(
        languages: [DictationLanguage],
        selected: DictationLanguage
    ) -> NSPopUpButton {
        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 360, height: 26))
        popup.setAccessibilityLabel(capabilityText("Diktatsprache", "Dictation language"))
        for language in languages {
            popup.addItem(withTitle: language.localizedDisplayName(
                interfaceLanguageCode: capabilityAppLanguage.embeddedInterfaceCode
            ))
            popup.lastItem?.representedObject = language.rawValue
        }
        if let index = languages.firstIndex(of: selected) { popup.selectItem(at: index) }
        return popup
    }

    private func accessoryStack(label: String, control: NSView) -> NSView {
        let title = NSTextField(labelWithString: label)
        title.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        let stack = NSStackView(views: [title, control])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.frame = NSRect(x: 0, y: 0, width: 380, height: 54)
        return stack
    }

    private func configureAutoResolveSuppression(on alert: NSAlert) {
        alert.showsSuppressionButton = true
        alert.suppressionButton?.title = capabilityText(
            "Nicht mehr fragen (Auswahl automatisch anpassen)",
            "Don't ask again (automatically adjust selection)"
        )
    }

    private func saveAutoResolveChoice(_ shouldAutoResolve: Bool) {
        if shouldAutoResolve { autoResolveVoiceModelConflicts = true }
    }

    private func selectedModel(
        from popup: NSPopUpButton,
        options: [VoiceModelDescriptor]
    ) -> VoiceModelDescriptor? {
        guard let id = popup.selectedItem?.representedObject as? String else { return nil }
        return options.first { $0.id == id }
    }

    private func selectedLanguage(
        from popup: NSPopUpButton?,
        options: [DictationLanguage],
        fallback: DictationLanguage
    ) -> DictationLanguage? {
        guard let popup else { return fallback }
        guard let rawValue = popup.selectedItem?.representedObject as? String else { return nil }
        return options.first { $0.rawValue == rawValue }
    }

    private func applyVoiceCapability(
        _ choice: VoiceModelCapabilityChoice,
        model: VoiceModelDescriptor?
    ) {
        let currentLanguage = selectedLanguage
        if let model {
            let affectedLanguage = choice.requiredLanguage(current: currentLanguage)
            let hadOverride = affectedLanguage != .auto && voiceLanguageOverrides.contains {
                $0.languageCode == affectedLanguage.rawValue
            }
            setSelectedVoiceModel(model)
            guard selectedVoiceModelID == model.id else { return }
            if affectedLanguage != .auto {
                voiceLanguageOverrides.removeAll { $0.languageCode == affectedLanguage.rawValue }
                switch choice {
                case .language:
                    break
                default:
                    if hadOverride {
                        voiceLanguageOverrides.append(VoiceLanguageOverride(
                            languageCode: affectedLanguage.rawValue, modelID: model.id))
                    }
                }
            }
        }
        switch choice {
        case .language(let language):
            selectedLanguage = language
        case .translation(let mode):
            translationOutputMode = mode
        case .liveText:
            streamingEnabled = true
            appendAudit("mode.toggle streamingEnabled=true")
            appendDiagnostic("Live-Einfügen aktiviert. Der Wechsel gilt ab dem nächsten Diktat.")
        case .quality(let profile):
            performanceProfile = profile
        }
    }

    private func showCapabilityModelManagementAlert() {
        let alert = NSAlert()
        alert.messageText = capabilityText("Kein passendes Modell", "No compatible model")
        alert.informativeText = capabilityText(
            "Für diese Auswahl ist derzeit kein kompatibles Sprachmodell verfügbar.",
            "No compatible speech model is currently available for this option.")
        alert.addButton(withTitle: capabilityText("Modellverwaltung öffnen", "Open model management"))
        alert.addButton(withTitle: capabilityText("Abbrechen", "Cancel"))
        NSApplication.shared.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            selectedSettingsTab = .speech
            openSettingsWindow()
        }
    }

    private func capabilityText(_ german: String, _ english: String) -> String {
        capabilityAppLanguage.text(german, english)
    }

    private var capabilityAppLanguage: AppLanguage {
        let raw = UserDefaults.standard.string(forKey: "wispr.uiLanguage") ?? AppLanguage.system.rawValue
        return AppLanguage(rawValue: raw) ?? .system
    }
}

func shouldUpdateVoiceModelLanguageOverride(
    previousLanguage: DictationLanguage,
    selectedLanguage: DictationLanguage,
    hadOverride: Bool
) -> Bool {
    hadOverride && previousLanguage != .auto && previousLanguage == selectedLanguage
}
