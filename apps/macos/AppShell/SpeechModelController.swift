import ASRCore
import Foundation

@MainActor
final class SpeechModelController {
    private let voiceModelInstaller: VoiceModelInstaller
    private let currentSelectedLanguage: () -> DictationLanguage
    private let setSelectedLanguage: (DictationLanguage) -> Void
    private let currentTranslationOutputMode: () -> TranslationOutputMode
    private let setTranslationOutputMode: (TranslationOutputMode) -> Void
    private let currentSelectedVoiceProviderID: () -> String
    private let setSelectedVoiceProviderID: (String) -> Void
    private let currentSelectedVoiceModelID: () -> String
    private let setSelectedVoiceModelID: (String) -> Void
    private let currentVoiceLanguageOverrides: () -> [VoiceLanguageOverride]
    private let setVoiceLanguageOverrides: ([VoiceLanguageOverride]) -> Void
    private let currentVoiceProviders: () -> [VoiceProviderDescriptor]
    private let setVoiceProviders: ([VoiceProviderDescriptor]) -> Void
    private let currentVoiceModels: () -> [VoiceModelDescriptor]
    private let setVoiceModels: ([VoiceModelDescriptor]) -> Void
    private let currentInstalledVoiceModelFileNames: () -> Set<String>
    private let setInstalledVoiceModelFileNames: (Set<String>) -> Void
    private let currentVoiceModelOperationInFlightIDs: () -> Set<String>
    private let setVoiceModelOperationInFlightIDs: (Set<String>) -> Void
    private let appendDiagnostic: (String) -> Void

    init(
        voiceModelInstaller: VoiceModelInstaller,
        currentSelectedLanguage: @escaping () -> DictationLanguage,
        setSelectedLanguage: @escaping (DictationLanguage) -> Void,
        currentTranslationOutputMode: @escaping () -> TranslationOutputMode,
        setTranslationOutputMode: @escaping (TranslationOutputMode) -> Void,
        currentSelectedVoiceProviderID: @escaping () -> String,
        setSelectedVoiceProviderID: @escaping (String) -> Void,
        currentSelectedVoiceModelID: @escaping () -> String,
        setSelectedVoiceModelID: @escaping (String) -> Void,
        currentVoiceLanguageOverrides: @escaping () -> [VoiceLanguageOverride],
        setVoiceLanguageOverrides: @escaping ([VoiceLanguageOverride]) -> Void,
        currentVoiceProviders: @escaping () -> [VoiceProviderDescriptor],
        setVoiceProviders: @escaping ([VoiceProviderDescriptor]) -> Void,
        currentVoiceModels: @escaping () -> [VoiceModelDescriptor],
        setVoiceModels: @escaping ([VoiceModelDescriptor]) -> Void,
        currentInstalledVoiceModelFileNames: @escaping () -> Set<String>,
        setInstalledVoiceModelFileNames: @escaping (Set<String>) -> Void,
        currentVoiceModelOperationInFlightIDs: @escaping () -> Set<String>,
        setVoiceModelOperationInFlightIDs: @escaping (Set<String>) -> Void,
        appendDiagnostic: @escaping (String) -> Void
    ) {
        self.voiceModelInstaller = voiceModelInstaller
        self.currentSelectedLanguage = currentSelectedLanguage
        self.setSelectedLanguage = setSelectedLanguage
        self.currentTranslationOutputMode = currentTranslationOutputMode
        self.setTranslationOutputMode = setTranslationOutputMode
        self.currentSelectedVoiceProviderID = currentSelectedVoiceProviderID
        self.setSelectedVoiceProviderID = setSelectedVoiceProviderID
        self.currentSelectedVoiceModelID = currentSelectedVoiceModelID
        self.setSelectedVoiceModelID = setSelectedVoiceModelID
        self.currentVoiceLanguageOverrides = currentVoiceLanguageOverrides
        self.setVoiceLanguageOverrides = setVoiceLanguageOverrides
        self.currentVoiceProviders = currentVoiceProviders
        self.setVoiceProviders = setVoiceProviders
        self.currentVoiceModels = currentVoiceModels
        self.setVoiceModels = setVoiceModels
        self.currentInstalledVoiceModelFileNames = currentInstalledVoiceModelFileNames
        self.setInstalledVoiceModelFileNames = setInstalledVoiceModelFileNames
        self.currentVoiceModelOperationInFlightIDs = currentVoiceModelOperationInFlightIDs
        self.setVoiceModelOperationInFlightIDs = setVoiceModelOperationInFlightIDs
        self.appendDiagnostic = appendDiagnostic
    }

    func refreshVoiceModelCatalog() {
        let providers = LocalVoiceModelCatalog.availableProviders()
        setVoiceProviders(providers)
        setVoiceModels(
            LocalVoiceModelCatalog.availableModels(
                includeParakeet: providers.contains(where: {
                    $0.id == VoiceProviderID.nvidiaParakeet.rawValue
                })))

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let installedFiles = try await self.voiceModelInstaller
                    .installedWhisperModelFileNames()
                self.setInstalledVoiceModelFileNames(installedFiles)
            } catch {
                self.setInstalledVoiceModelFileNames([])
                self.appendDiagnostic(
                    "Speech-Model-Katalog konnte nicht vollständig geladen werden: \(error.localizedDescription)"
                )
            }

            self.sanitizeSpeechModelSelections()
        }
    }

    func installVoiceModel(_ descriptor: VoiceModelDescriptor) {
        guard descriptor.providerID == VoiceProviderID.whisperCpp.rawValue else {
            appendDiagnostic("Dieser Speech-Anbieter ist lokal aktuell nicht installierbar.")
            return
        }

        setVoiceModelOperationInFlightIDs(currentVoiceModelOperationInFlightIDs().union([descriptor.id]))
        appendDiagnostic("Installiere Speech-Modell \(descriptor.displayName)...")

        Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.setVoiceModelOperationInFlightIDs(
                    self.currentVoiceModelOperationInFlightIDs().subtracting([descriptor.id]))
            }

            do {
                let runtime = try await self.voiceModelInstaller.install(descriptor)
                self.setInstalledVoiceModelFileNames(Set(runtime.availableModelFileNames))
                self.sanitizeSpeechModelSelections()
                self.appendDiagnostic("Speech-Modell \(descriptor.displayName) wurde installiert.")
            } catch {
                self.appendDiagnostic(
                    "Speech-Modell \(descriptor.displayName) konnte nicht installiert werden: \(error.localizedDescription)"
                )
            }
        }
    }

    func removeVoiceModel(_ descriptor: VoiceModelDescriptor) {
        guard descriptor.providerID == VoiceProviderID.whisperCpp.rawValue else {
            appendDiagnostic("Dieser Speech-Anbieter ist lokal aktuell nicht entfernbar.")
            return
        }

        setVoiceModelOperationInFlightIDs(currentVoiceModelOperationInFlightIDs().union([descriptor.id]))
        appendDiagnostic("Entferne Speech-Modell \(descriptor.displayName)...")

        Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.setVoiceModelOperationInFlightIDs(
                    self.currentVoiceModelOperationInFlightIDs().subtracting([descriptor.id]))
            }

            do {
                let runtime = try await self.voiceModelInstaller.remove(descriptor)
                self.setInstalledVoiceModelFileNames(Set(runtime.availableModelFileNames))
                self.setVoiceLanguageOverrides(
                    self.currentVoiceLanguageOverrides().filter { $0.modelID != descriptor.id })
                self.sanitizeSpeechModelSelections()
                self.appendDiagnostic("Speech-Modell \(descriptor.displayName) wurde entfernt.")
            } catch {
                self.appendDiagnostic(
                    "Speech-Modell \(descriptor.displayName) konnte nicht entfernt werden: \(error.localizedDescription)"
                )
            }
        }
    }

    func setSelectedVoiceModel(_ descriptor: VoiceModelDescriptor) {
        guard isVoiceModelInstalled(descriptor) else {
            appendDiagnostic(
                "Speech-Modell \(descriptor.displayName) ist nicht installiert und kann nicht ausgewählt werden."
            )
            return
        }
        setSelectedVoiceProviderID(descriptor.providerID)
        setSelectedVoiceModelID(descriptor.id)
    }

    func assignSelectedVoiceModelToCurrentLanguage() {
        guard currentSelectedLanguage() != .auto, let descriptor = selectedVoiceModel else { return }
        var overrides = currentVoiceLanguageOverrides()
        overrides.removeAll { $0.languageCode == currentSelectedLanguage().rawValue }
        overrides.append(
            VoiceLanguageOverride(
                languageCode: currentSelectedLanguage().rawValue,
                modelID: descriptor.id
            )
        )
        setVoiceLanguageOverrides(overrides)
        sanitizeSpeechModelSelections()
        appendDiagnostic(
            "Für \(currentSelectedLanguage().displayName) wird jetzt standardmäßig \(descriptor.displayName) verwendet."
        )
    }

    func clearSelectedLanguageVoiceOverride() {
        guard currentSelectedLanguage() != .auto else { return }
        setVoiceLanguageOverrides(
            currentVoiceLanguageOverrides().filter {
                $0.languageCode != currentSelectedLanguage().rawValue
            }
        )
        sanitizeSpeechModelSelections()
        appendDiagnostic(
            "Sprachspezifisches Speech-Modell für \(currentSelectedLanguage().displayName) entfernt."
        )
    }

    func isVoiceModelInstalled(_ descriptor: VoiceModelDescriptor) -> Bool {
        guard descriptor.providerID == VoiceProviderID.whisperCpp.rawValue else {
            return descriptor.installState == .bundled
        }
        guard let localFileName = descriptor.localFileName else { return false }
        return currentInstalledVoiceModelFileNames().contains(localFileName)
    }

    func isVoiceModelBusy(_ descriptor: VoiceModelDescriptor) -> Bool {
        currentVoiceModelOperationInFlightIDs().contains(descriptor.id)
    }

    func canUseVoiceModel(_ descriptor: VoiceModelDescriptor, for language: DictationLanguage)
        -> Bool
    {
        if descriptor.providerID != VoiceProviderID.whisperCpp.rawValue {
            return false
        }
        if !isVoiceModelInstalled(descriptor) {
            return false
        }
        guard let languageCode = descriptor.languageCode else { return true }
        return language == .auto || language.rawValue == languageCode
    }

    func voiceLanguageOptions(for descriptor: VoiceModelDescriptor?) -> [DictationLanguage] {
        guard let descriptor, let languageCode = descriptor.languageCode else {
            return DictationLanguage.allCases
        }

        let fixedLanguage = DictationLanguage(rawValue: languageCode) ?? .english
        return [.auto, fixedLanguage]
    }

    func sanitizeSpeechModelSelections() {
        if currentVoiceProviders().isEmpty {
            setVoiceProviders(LocalVoiceModelCatalog.availableProviders())
        }
        if currentVoiceModels().isEmpty {
            setVoiceModels(LocalVoiceModelCatalog.availableModels(includeParakeet: false))
        }

        if !currentVoiceProviders().contains(where: { $0.id == currentSelectedVoiceProviderID() }) {
            setSelectedVoiceProviderID(LocalVoiceModelCatalog.defaultProviderID)
        }

        if let selectedVoiceModel,
            selectedVoiceModel.providerID != currentSelectedVoiceProviderID()
        {
            setSelectedVoiceModelID(
                currentVoiceModels().first(where: {
                    $0.providerID == currentSelectedVoiceProviderID()
                })?.id
                    ?? LocalVoiceModelCatalog.defaultModelID
            )
        }

        if selectedVoiceModel == nil || selectedVoiceModel.map(isVoiceModelInstalled) == false {
            if let defaultModel = currentVoiceModels().first(where: {
                $0.id == LocalVoiceModelCatalog.defaultModelID
            }) {
                setSelectedVoiceProviderID(defaultModel.providerID)
                setSelectedVoiceModelID(defaultModel.id)
            } else if let providerFallback = currentVoiceModels().first(where: {
                $0.providerID == currentSelectedVoiceProviderID()
            }) {
                setSelectedVoiceModelID(providerFallback.id)
            } else if let anyFallback = currentVoiceModels().first {
                setSelectedVoiceProviderID(anyFallback.providerID)
                setSelectedVoiceModelID(anyFallback.id)
            }
        }

        if let selectedVoiceModel {
            let availableLanguages = Set(
                voiceLanguageOptions(for: selectedVoiceModel).map(\.rawValue))
            if !availableLanguages.contains(currentSelectedLanguage().rawValue) {
                setSelectedLanguage(.auto)
            }
            if let languageCode = selectedVoiceModel.languageCode,
                currentSelectedLanguage() == .auto
            {
                setSelectedLanguage(DictationLanguage(rawValue: languageCode) ?? .english)
            }
        }

        setVoiceLanguageOverrides(
            currentVoiceLanguageOverrides().filter { overrideEntry in
                guard let descriptor = currentVoiceModels().first(where: {
                    $0.id == overrideEntry.modelID
                })
                else {
                    return false
                }
                let language = DictationLanguage(rawValue: overrideEntry.languageCode) ?? .auto
                return canUseVoiceModel(descriptor, for: language)
            }
        )

        if !selectedVoiceModelSupportsTranslation, currentTranslationOutputMode() != .original {
            setTranslationOutputMode(.original)
        }
    }

    private var selectedVoiceModel: VoiceModelDescriptor? {
        currentVoiceModels().first(where: { $0.id == currentSelectedVoiceModelID() })
    }

    private var selectedVoiceModelSupportsTranslation: Bool {
        selectedVoiceModel?.supportsTranslationToEnglish ?? false
    }
}
