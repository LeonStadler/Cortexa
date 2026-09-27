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
        if case .language(let language) = choice,
            language != .auto,
            let override = voiceLanguageOverrides.first(where: {
                $0.languageCode == language.rawValue
            }),
            let model = voiceModels.first(where: { $0.id == override.modelID }),
            isVoiceModelInstalled(model),
            voiceProviders.contains(where: { $0.id == model.providerID && $0.isAvailable }),
            VoiceModelCapabilityPolicy().supports(language: language, model: model) {
            return true
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
        let language = selectedLanguage
        let hadOverride = selectedLanguageVoiceOverride != nil
        setSelectedVoiceModel(model)
        if hadOverride, language != .auto {
            voiceLanguageOverrides.removeAll { $0.languageCode == language.rawValue }
            if VoiceModelCapabilityPolicy().supports(language: language, model: model) {
                voiceLanguageOverrides.append(VoiceLanguageOverride(
                    languageCode: language.rawValue, modelID: model.id))
            }
            speechModelController.sanitizeSpeechModelSelections()
        }
    }

    func requestVoiceCapability(_ choice: VoiceModelCapabilityChoice) {
        guard let source = activeVoiceModel else {
            Task { @MainActor [weak self] in
                await Task.yield()
                self?.showCapabilityModelManagementAlert()
            }
            return
        }
        if supportsCapability(choice) {
            applyVoiceCapability(choice, model: nil)
            return
        }

        let policy = VoiceModelCapabilityPolicy()
        let selectionRevision = voiceSelectionRevision
        let usableCatalog = voiceModels.filter { model in
            let installed = policy.isInstalled(model, files: installedVoiceModelFileNames)
            return !installed || voiceProviders.contains {
                $0.id == model.providerID && $0.isAvailable
            }
        }
        let suggestion = policy.suggestedModel(
            for: choice,
            currentModel: source,
            currentLanguage: selectedLanguage,
            catalog: usableCatalog,
            installedFiles: installedVoiceModelFileNames
        )
        Task { @MainActor [weak self] in
            await Task.yield()
            guard let self else { return }
            guard let suggestion else {
                self.showCapabilityModelManagementAlert()
                return
            }
            let installed = self.isVoiceModelInstalled(suggestion)
            let alert = NSAlert()
            alert.messageText = self.capabilityText(
                "Modellwechsel erforderlich", "Change speech model")
            alert.informativeText = self.capabilityText(
                "\(source.displayName) unterstützt diese Auswahl nicht. Zu \(suggestion.displayName) wechseln?",
                "\(source.displayName) does not support this option. Switch to \(suggestion.displayName)?")
            alert.addButton(withTitle: installed
                ? self.capabilityText("Modell wechseln", "Switch model")
                : self.capabilityText("Herunterladen und wechseln", "Download and switch"))
            alert.addButton(withTitle: self.capabilityText("Abbrechen", "Cancel"))
            NSApplication.shared.activate(ignoringOtherApps: true)
            guard alert.runModal() == .alertFirstButtonReturn,
                self.voiceSelectionRevision == selectionRevision,
                self.activeVoiceModel?.id == source.id else { return }

            if installed {
                self.applyVoiceCapability(choice, model: suggestion)
            } else {
                self.speechModelController.installVoiceModelForCapability(suggestion) { [weak self] in
                    guard let self,
                        self.voiceSelectionRevision == selectionRevision,
                        self.activeVoiceModel?.id == source.id else { return }
                    self.applyVoiceCapability(choice, model: suggestion)
                }
            }
        }
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
        let raw = UserDefaults.standard.string(forKey: "wispr.uiLanguage") ?? AppLanguage.system.rawValue
        return (AppLanguage(rawValue: raw) ?? .system).text(german, english)
    }
}
