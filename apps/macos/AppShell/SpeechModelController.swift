import ASRCore
import Foundation

private let voiceModelProgressUpdateIntervalPercent = 5

func shouldPublishVoiceModelOperation(
    current: VoiceModelOperationKind?,
    proposed: VoiceModelOperationKind
) -> Bool {
    guard let current else { return true }

    guard case let (.installing(currentProgress), .installing(proposedProgress)) = (current, proposed)
    else {
        return current != proposed
    }

    guard currentProgress.phase == proposedProgress.phase,
        currentProgress.isIndeterminate == proposedProgress.isIndeterminate,
        (currentProgress.totalBytes == nil) == (proposedProgress.totalBytes == nil)
    else {
        return true
    }

    return proposedProgress.percentComplete >= currentProgress.percentComplete
        + voiceModelProgressUpdateIntervalPercent
        || proposedProgress.percentComplete < currentProgress.percentComplete
        || proposedProgress.percentComplete == 100
}

@MainActor
final class SpeechModelController {
    private var installationTasks: [String: Task<Void, Never>] = [:]
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
    private let currentVoiceModelOperationStates: () -> [String: VoiceModelOperationKind]
    private let setVoiceModelOperationStates: ([String: VoiceModelOperationKind]) -> Void
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
        currentVoiceModelOperationStates: @escaping () -> [String: VoiceModelOperationKind],
        setVoiceModelOperationStates: @escaping ([String: VoiceModelOperationKind]) -> Void,
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
        self.currentVoiceModelOperationStates = currentVoiceModelOperationStates
        self.setVoiceModelOperationStates = setVoiceModelOperationStates
        self.appendDiagnostic = appendDiagnostic
    }

    func refreshVoiceModelCatalog() {
        let providers = LocalVoiceModelCatalog.availableProviders(
            parakeetBinaryURL: VoiceModelInstaller.resolveNemoSpeechCLI())
        setVoiceProviders(providers)
        setVoiceModels(LocalVoiceModelCatalog.availableModels(includeParakeet: true))

        Task { @MainActor [weak self] in
            guard let self else { return }
            var installedFiles: Set<String> = []
            do {
                installedFiles = try await self.voiceModelInstaller
                    .installedWhisperModelFileNames()
                installedFiles.formUnion(try await self.voiceModelInstaller.installedParakeetModelFileNames())
                self.setInstalledVoiceModelFileNames(installedFiles)
            } catch {
                self.setInstalledVoiceModelFileNames([])
                self.appendDiagnostic(
                    "Speech-Model-Katalog konnte nicht vollständig geladen werden: \(error.localizedDescription)"
                )
            }

            self.sanitizeSpeechModelSelections()
            self.setVoiceModels(LocalVoiceModelCatalog.availableModels(includeParakeet: true))
            self.reportLegacyInstalledModelsIfNeeded(installedFiles: installedFiles)
        }
    }

    private func reportLegacyInstalledModelsIfNeeded(installedFiles: Set<String>) {
        let reportedKey = "wispr.speech.legacyModelDiagnostics"
        var reported = Set(UserDefaults.standard.stringArray(forKey: reportedKey) ?? [])
        let downloadableModels = LocalVoiceModelCatalog.availableModels(includeParakeet: true)
            .filter { $0.installState == .downloadable && $0.id != LocalVoiceModelCatalog.defaultModelID }

        for descriptor in downloadableModels {
            guard let localFileName = descriptor.localFileName,
                installedFiles.contains(localFileName),
                !reported.contains(descriptor.id)
            else { continue }
            appendDiagnostic(
                "Speech model from a previous version found on disk: \(descriptor.displayName)."
            )
            reported.insert(descriptor.id)
        }

        UserDefaults.standard.set(Array(reported), forKey: reportedKey)
    }

    func installVoiceModel(_ descriptor: VoiceModelDescriptor) {
        guard voiceModelOperationState(for: descriptor) == nil else { return }
        guard descriptor.providerID == VoiceProviderID.whisperCpp.rawValue
                || descriptor.providerID == VoiceProviderID.nvidiaParakeet.rawValue else {
            appendDiagnostic("Dieser Speech-Anbieter ist lokal aktuell nicht installierbar.")
            return
        }

        setOperation(
            .installing(VoiceModelInstallProgress(phase: .preparing, fractionCompleted: 0)),
            for: descriptor.id)
        appendDiagnostic("Installiere Speech-Modell \(descriptor.displayName)...")

        let installationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.installationTasks.removeValue(forKey: descriptor.id)
                self.clearOperation(for: descriptor.id)
            }

            do {
                let installer = self.voiceModelInstaller
                let runtime = try await installer.install(descriptor) { [weak self] progress in
                    Task { @MainActor [weak self] in
                        self?.setOperation(.installing(progress), for: descriptor.id)
                    }
                }
                var installedFileNames = Set(runtime.availableModelFileNames)
                installedFileNames.formUnion(
                    try await self.voiceModelInstaller.installedParakeetModelFileNames())
                self.setInstalledVoiceModelFileNames(installedFileNames)
                self.setVoiceProviders(LocalVoiceModelCatalog.availableProviders(
                    parakeetBinaryURL: VoiceModelInstaller.resolveNemoSpeechCLI()))
                if self.isVoiceProviderAvailable(descriptor.providerID) {
                    if self.currentSelectedVoiceProviderID() != descriptor.providerID {
                        self.setSelectedVoiceProviderID(descriptor.providerID)
                    }
                    if self.currentSelectedVoiceModelID() != descriptor.id {
                        self.setSelectedVoiceModelID(descriptor.id)
                    }
                }
                self.sanitizeSpeechModelSelections()
                self.appendDiagnostic("Speech-Modell \(descriptor.displayName) wurde installiert.")
            } catch {
                if error is CancellationError || Task.isCancelled {
                    self.appendDiagnostic("Download von \(descriptor.displayName) abgebrochen; temporäre Dateien wurden bereinigt.")
                } else {
                    self.appendDiagnostic(
                        "Speech-Modell \(descriptor.displayName) konnte nicht installiert werden: \(error.localizedDescription)"
                    )
                }
            }
        }
        installationTasks[descriptor.id] = installationTask
    }

    func cancelVoiceModelInstallation(_ descriptor: VoiceModelDescriptor) {
        guard let task = installationTasks[descriptor.id] else { return }
        appendDiagnostic("Breche Download von \(descriptor.displayName) ab …")
        task.cancel()
    }

    func removeVoiceModel(_ descriptor: VoiceModelDescriptor) {
        guard descriptor.providerID == VoiceProviderID.whisperCpp.rawValue
                || descriptor.providerID == VoiceProviderID.nvidiaParakeet.rawValue else {
            appendDiagnostic("Dieser Speech-Anbieter ist lokal aktuell nicht entfernbar.")
            return
        }

        let previousInstalledFileNames = currentInstalledVoiceModelFileNames()
        let localFileName = descriptor.localFileName

        setOperation(.removing, for: descriptor.id)
        if let localFileName {
            var optimisticInstalled = previousInstalledFileNames
            optimisticInstalled.remove(localFileName)
            setInstalledVoiceModelFileNames(optimisticInstalled)
        }
        sanitizeSpeechModelSelections()
        appendDiagnostic("Entferne Speech-Modell \(descriptor.displayName)...")

        Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.clearOperation(for: descriptor.id)
            }

            do {
                let runtime = try await self.voiceModelInstaller.remove(descriptor)
                var installedFileNames = Set(runtime.availableModelFileNames)
                installedFileNames.formUnion(
                    try await self.voiceModelInstaller.installedParakeetModelFileNames())
                self.setInstalledVoiceModelFileNames(installedFileNames)
                self.setVoiceLanguageOverrides(
                    self.currentVoiceLanguageOverrides().filter { $0.modelID != descriptor.id })
                self.sanitizeSpeechModelSelections()
                self.appendDiagnostic("Speech-Modell \(descriptor.displayName) wurde entfernt.")
            } catch {
                do {
                    var actualFiles = Set(try await self.voiceModelInstaller.installedWhisperModelFileNames())
                    actualFiles.formUnion(try await self.voiceModelInstaller.installedParakeetModelFileNames())
                    self.setInstalledVoiceModelFileNames(actualFiles)
                } catch {
                    self.setInstalledVoiceModelFileNames(previousInstalledFileNames)
                }
                self.sanitizeSpeechModelSelections()
                self.appendDiagnostic(
                    "Speech-Modell \(descriptor.displayName) konnte nicht entfernt werden: \(error.localizedDescription)"
                )
            }
        }
    }

    func retryUnusedNemoRuntimeCleanup() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.voiceModelInstaller.cleanupUnusedNemoRuntime()
                self.refreshVoiceModelCatalog()
                self.appendDiagnostic("Nicht mehr benötigte Cortexa-NeMo-Runtime wurde bereinigt.")
            } catch {
                self.appendDiagnostic("NeMo-Runtime-Bereinigung fehlgeschlagen: \(error.localizedDescription)")
            }
        }
    }

    func setSelectedVoiceModel(_ descriptor: VoiceModelDescriptor) {
        guard isVoiceModelInstalled(descriptor), isVoiceProviderAvailable(descriptor.providerID) else {
            appendDiagnostic(
                "Speech-Modell \(descriptor.displayName) ist nicht installiert oder sein lokales Backend ist nicht verfügbar."
            )
            return
        }
        if currentSelectedVoiceProviderID() != descriptor.providerID {
            setSelectedVoiceProviderID(descriptor.providerID)
        }
        if currentSelectedVoiceModelID() != descriptor.id {
            setSelectedVoiceModelID(descriptor.id)
        }
    }

    func assignSelectedVoiceModelToCurrentLanguage() {
        guard currentSelectedLanguage() != .auto, let descriptor = selectedVoiceModel else {
            return
        }
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

    func voiceModelOperationState(for descriptor: VoiceModelDescriptor) -> VoiceModelOperationKind?
    {
        currentVoiceModelOperationStates()[descriptor.id]
    }

    func isVoiceModelInstalled(_ descriptor: VoiceModelDescriptor) -> Bool {
        if case .removing = voiceModelOperationState(for: descriptor) {
            return false
        }
        if case .installing = voiceModelOperationState(for: descriptor) {
            return false
        }

        if descriptor.providerID == VoiceProviderID.nvidiaParakeet.rawValue {
            guard let fileName = descriptor.localFileName else { return false }
            return currentInstalledVoiceModelFileNames().contains(fileName)
        }
        guard descriptor.providerID == VoiceProviderID.whisperCpp.rawValue else { return false }
        guard let localFileName = descriptor.localFileName else { return false }
        return currentInstalledVoiceModelFileNames().contains(localFileName)
    }

    func isVoiceModelBusy(_ descriptor: VoiceModelDescriptor) -> Bool {
        voiceModelOperationState(for: descriptor) != nil
    }

    func canUseVoiceModel(_ descriptor: VoiceModelDescriptor, for language: DictationLanguage)
        -> Bool
    {
        guard descriptor.providerID == VoiceProviderID.whisperCpp.rawValue
                || descriptor.providerID == VoiceProviderID.nvidiaParakeet.rawValue else { return false }
        guard isVoiceProviderAvailable(descriptor.providerID) else { return false }
        if !isVoiceModelInstalled(descriptor) {
            return false
        }
        if language == .auto { return descriptor.supportsAutomaticLanguageDetection }
        guard descriptor.supportsLanguageSelection else { return false }
        if let languageCode = descriptor.languageCode, languageCode != language.rawValue {
            return false
        }
        return descriptor.supportedLanguageCodes?.contains(language.rawValue) ?? true
    }

    func voiceLanguageOptions(for descriptor: VoiceModelDescriptor?) -> [DictationLanguage] {
        guard let descriptor else {
            return Self.autoFirstLanguageOptions(DictationLanguage.allCases)
        }
        var options = DictationLanguage.allCases.filter { language in
            if language == .auto { return descriptor.supportsAutomaticLanguageDetection }
            guard descriptor.supportsLanguageSelection else { return false }
            if let languageCode = descriptor.languageCode, languageCode != language.rawValue {
                return false
            }
            return descriptor.supportedLanguageCodes?.contains(language.rawValue) ?? true
        }
        if options.isEmpty, let fixedCode = descriptor.languageCode,
            let fixedLanguage = DictationLanguage(rawValue: fixedCode) {
            options = [fixedLanguage]
        }
        return Self.autoFirstLanguageOptions(options)
    }

    static func autoFirstLanguageOptions(_ options: [DictationLanguage]) -> [DictationLanguage] {
        guard options.contains(.auto) else { return options }
        return [.auto] + options.filter { $0 != .auto }
    }

    func sanitizeSpeechModelSelections() {
        if currentVoiceProviders().isEmpty {
            setVoiceProviders(LocalVoiceModelCatalog.availableProviders(
                parakeetBinaryURL: VoiceModelInstaller.resolveNemoSpeechCLI()))
        }
        if currentVoiceModels().isEmpty {
            setVoiceModels(LocalVoiceModelCatalog.availableModels(includeParakeet: true))
        }

        if !isVoiceProviderAvailable(currentSelectedVoiceProviderID()) {
            if currentSelectedVoiceProviderID() != LocalVoiceModelCatalog.defaultProviderID {
                setSelectedVoiceProviderID(LocalVoiceModelCatalog.defaultProviderID)
            }
        }

        if let selectedVoiceModel,
            selectedVoiceModel.providerID != currentSelectedVoiceProviderID()
        {
            let fallbackModelID =
                currentVoiceModels().first(where: {
                    $0.providerID == currentSelectedVoiceProviderID()
                })?.id
                ?? LocalVoiceModelCatalog.defaultModelID
            if currentSelectedVoiceModelID() != fallbackModelID {
                setSelectedVoiceModelID(fallbackModelID)
            }
        }

        if selectedVoiceModel == nil || selectedVoiceModel.map(isVoiceModelInstalled) == false {
            if let defaultModel = currentVoiceModels().first(where: {
                $0.id == LocalVoiceModelCatalog.defaultModelID
            }) {
                if currentSelectedVoiceProviderID() != defaultModel.providerID {
                    setSelectedVoiceProviderID(defaultModel.providerID)
                }
                if currentSelectedVoiceModelID() != defaultModel.id {
                    setSelectedVoiceModelID(defaultModel.id)
                }
            } else if let providerFallback = currentVoiceModels().first(where: {
                $0.providerID == currentSelectedVoiceProviderID()
            }) {
                if currentSelectedVoiceModelID() != providerFallback.id {
                    setSelectedVoiceModelID(providerFallback.id)
                }
            } else if let anyFallback = currentVoiceModels().first {
                if currentSelectedVoiceProviderID() != anyFallback.providerID {
                    setSelectedVoiceProviderID(anyFallback.providerID)
                }
                if currentSelectedVoiceModelID() != anyFallback.id {
                    setSelectedVoiceModelID(anyFallback.id)
                }
            }
        }

        if let selectedVoiceModel {
            let availableLanguages = Set(
                voiceLanguageOptions(for: selectedVoiceModel).map(\.rawValue))
            if !availableLanguages.contains(currentSelectedLanguage().rawValue) {
                setSelectedLanguage(voiceLanguageOptions(for: selectedVoiceModel).first ?? .english)
            }
        }

        setVoiceLanguageOverrides(
            currentVoiceLanguageOverrides().filter { overrideEntry in
                guard
                    let descriptor = currentVoiceModels().first(where: {
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

    private func isVoiceProviderAvailable(_ providerID: String) -> Bool {
        currentVoiceProviders().contains(where: { $0.id == providerID && $0.isAvailable })
    }

    private var selectedVoiceModelSupportsTranslation: Bool {
        selectedVoiceModel?.supportsTranslationToEnglish ?? false
    }

    private func setOperation(_ operation: VoiceModelOperationKind, for modelID: String) {
        var states = currentVoiceModelOperationStates()
        guard shouldPublishVoiceModelOperation(current: states[modelID], proposed: operation) else {
            return
        }
        states[modelID] = operation
        setVoiceModelOperationStates(states)
    }

    private func clearOperation(for modelID: String) {
        var states = currentVoiceModelOperationStates()
        states.removeValue(forKey: modelID)
        setVoiceModelOperationStates(states)
    }
}
