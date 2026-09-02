import AIProcessingCore
import Foundation

@MainActor
final class AIProviderController {
    private let aiRemoteProviderSecretStore: AIRemoteProviderSecretStoring
    private let dictationRuntime: DictationRuntimeControlling
    private let currentRemoteProviders: () -> [AIRemoteProviderConfiguration]
    private let setRemoteProviders: ([AIRemoteProviderConfiguration]) -> Void
    private let currentSelectedRemoteProviderID: () -> String?
    private let setSelectedRemoteProviderID: (String?) -> Void
    private let currentRemoteProviderAPIKeyDraft: () -> String
    private let setRemoteProviderAPIKeyDraft: (String) -> Void
    private let currentSelectedAIModelID: () -> String?
    private let setSelectedAIModelID: (String?) -> Void
    private let currentAIProcessingEnabled: () -> Bool
    private let setAIProcessingEnabled: (Bool) -> Void
    private let setAIModels: ([AIModelDescriptor]) -> Void
    private let persistRemoteProviders: () -> Void
    private let appendDiagnostic: (String) -> Void
    private let appendAudit: (String) -> Void

    private var aiProcessingService = AIProcessingService()
    private var modelRefreshTasks: [String: Task<Void, Never>] = [:]

    init(
        aiRemoteProviderSecretStore: AIRemoteProviderSecretStoring,
        dictationRuntime: DictationRuntimeControlling,
        currentRemoteProviders: @escaping () -> [AIRemoteProviderConfiguration],
        setRemoteProviders: @escaping ([AIRemoteProviderConfiguration]) -> Void,
        currentSelectedRemoteProviderID: @escaping () -> String?,
        setSelectedRemoteProviderID: @escaping (String?) -> Void,
        currentRemoteProviderAPIKeyDraft: @escaping () -> String,
        setRemoteProviderAPIKeyDraft: @escaping (String) -> Void,
        currentSelectedAIModelID: @escaping () -> String?,
        setSelectedAIModelID: @escaping (String?) -> Void,
        currentAIProcessingEnabled: @escaping () -> Bool,
        setAIProcessingEnabled: @escaping (Bool) -> Void,
        setAIModels: @escaping ([AIModelDescriptor]) -> Void,
        persistRemoteProviders: @escaping () -> Void,
        appendDiagnostic: @escaping (String) -> Void,
        appendAudit: @escaping (String) -> Void
    ) {
        self.aiRemoteProviderSecretStore = aiRemoteProviderSecretStore
        self.dictationRuntime = dictationRuntime
        self.currentRemoteProviders = currentRemoteProviders
        self.setRemoteProviders = setRemoteProviders
        self.currentSelectedRemoteProviderID = currentSelectedRemoteProviderID
        self.setSelectedRemoteProviderID = setSelectedRemoteProviderID
        self.currentRemoteProviderAPIKeyDraft = currentRemoteProviderAPIKeyDraft
        self.setRemoteProviderAPIKeyDraft = setRemoteProviderAPIKeyDraft
        self.currentSelectedAIModelID = currentSelectedAIModelID
        self.setSelectedAIModelID = setSelectedAIModelID
        self.currentAIProcessingEnabled = currentAIProcessingEnabled
        self.setAIProcessingEnabled = setAIProcessingEnabled
        self.setAIModels = setAIModels
        self.persistRemoteProviders = persistRemoteProviders
        self.appendDiagnostic = appendDiagnostic
        self.appendAudit = appendAudit
    }

    func remoteProvidersDidChange(reason: String) {
        persistRemoteProviders()
        rebuildAIProcessingStack(reason: reason)
    }

    func selectedRemoteProviderDidChange() {
        let apiKey = currentSelectedRemoteProviderID().flatMap {
            aiRemoteProviderSecretStore.loadAPIKey(providerID: $0)
        } ?? ""
        setRemoteProviderAPIKeyDraft(apiKey)
    }

    func selectedAIModelDidChange() {
        rebuildAIProcessingStack(reason: "model-selection")
    }

    func addRemoteProvider(preset: AIRemoteProviderPreset) {
        let providers = currentRemoteProviders()
        if let existing = providers.first(where: { $0.preset == preset }) {
            setSelectedRemoteProviderID(existing.id)
            appendDiagnostic(
                "Anbieter \(existing.displayName) ist bereits in der Liste — Auswahl übernommen.")
            return
        }

        var provider = AIRemoteProviderConfiguration.template(
            for: preset,
            appTitle: "Cortexa",
            appReferer: Bundle.main.bundleURL.absoluteString
        )
        if preset == .customOpenAICompatible {
            provider.displayName = "Custom API"
        }
        setRemoteProviders(providers + [provider])
        setSelectedRemoteProviderID(provider.id)
        if provider.requiresAPIKey {
            appendDiagnostic(
                "\(provider.displayName) wurde als API-Anbieter hinzugefügt und startet deaktiviert. Hinterlege jetzt den API-Key, speichere die Konfiguration und aktiviere den Anbieter danach bewusst."
            )
        } else {
            appendDiagnostic(
                "\(provider.displayName) wurde als API-Anbieter hinzugefügt und startet deaktiviert. Speichere die Konfiguration und aktiviere den Anbieter danach bewusst."
            )
        }
    }

    func removeSelectedRemoteProvider() {
        guard let selectedRemoteProviderID = currentSelectedRemoteProviderID() else { return }
        setRemoteProviders(currentRemoteProviders().filter { $0.id != selectedRemoteProviderID })
        aiRemoteProviderSecretStore.removeAPIKey(providerID: selectedRemoteProviderID)
        setSelectedRemoteProviderID(currentRemoteProviders().first?.id)
        rebuildAIProcessingStack(reason: "remote-provider-removed")
    }

    func updateSelectedRemoteProvider(_ update: (inout AIRemoteProviderConfiguration) -> Void) {
        guard let selectedRemoteProviderID = currentSelectedRemoteProviderID() else { return }
        updateRemoteProvider(id: selectedRemoteProviderID, update)
    }

    func saveSelectedRemoteProviderAPIKey() {
        guard let selectedRemoteProviderID = currentSelectedRemoteProviderID() else { return }
        let trimmed = currentRemoteProviderAPIKeyDraft().trimmingCharacters(
            in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            aiRemoteProviderSecretStore.removeAPIKey(providerID: selectedRemoteProviderID)
            appendDiagnostic("API-Key für den gewählten Anbieter entfernt.")
        } else {
            do {
                try aiRemoteProviderSecretStore.saveAPIKey(trimmed, providerID: selectedRemoteProviderID)
                appendDiagnostic("API-Key für den gewählten Anbieter im Keychain gespeichert.")
            } catch {
                appendDiagnostic(
                    "API-Key konnte nicht gespeichert werden: \(error.localizedDescription)")
            }
        }

        rebuildAIProcessingStack(reason: "remote-provider-api-key")
    }

    func saveSelectedRemoteProvider() {
        guard let selectedRemoteProvider = selectedRemoteProvider else { return }

        saveSelectedRemoteProviderAPIKey()

        let trimmedAPIKey = currentRemoteProviderAPIKeyDraft().trimmingCharacters(
            in: .whitespacesAndNewlines)
        if selectedRemoteProvider.requiresAPIKey && trimmedAPIKey.isEmpty {
            appendDiagnostic(
                "Anbieter gespeichert. Hinterlege einen API-Key, um den Modellkatalog zu laden.")
            return
        }

        refreshSelectedRemoteProviderModels()
    }

    func refreshSelectedRemoteProviderModels() {
        guard let selectedRemoteProvider = selectedRemoteProvider else { return }
        refreshRemoteProviderModels(selectedRemoteProvider)
    }

    func refreshAllRemoteProviderModels() {
        for provider in currentRemoteProviders() where provider.isEnabled {
            refreshRemoteProviderModels(provider)
        }
    }

    private func refreshRemoteProviderModels(_ provider: AIRemoteProviderConfiguration) {
        guard modelRefreshTasks[provider.id] == nil else { return }
        let providerID = provider.id
        let providerName = provider.displayName
        let apiKey =
            aiRemoteProviderSecretStore.loadAPIKey(providerID: providerID) ?? ""
        if provider.requiresAPIKey,
            apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            appendDiagnostic("Für (providerName) fehlt ein API-Key.")
            return
        }

        appendDiagnostic("Lade Modellkatalog für \(providerName)...")
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.modelRefreshTasks[providerID] = nil }
            do {
                let models = try await OpenAICompatibleRemoteTextProcessor.discoverModels(
                    configuration: provider,
                    apiKey: apiKey
                )
                self.updateRemoteProvider(id: providerID) { provider in
                    provider.discoveredModels = models
                }
                self.rebuildAIProcessingStack(reason: "remote-models-refreshed")
                self.appendDiagnostic(
                    "Modellkatalog für \(providerName) aktualisiert: \(models.count) Modelle.")
            } catch {
                self.appendDiagnostic(
                    "Modellkatalog für \(providerName) konnte nicht geladen werden: \(error.localizedDescription)"
                )
            }
        }
        modelRefreshTasks[providerID] = task
    }

    func rebuildAIProcessingStack(reason: String) {
        aiProcessingService = AIProcessingService(providers: makeAIProviders())
        dictationRuntime.setAIProcessingService(aiProcessingService)
        let catalog = aiProcessingService.catalog()
        setAIModels(catalog.allModels)
        let fallbackModelID =
            catalog.availableModels.first?.id
            ?? catalog.allModels.first?.id

        if catalog.model(id: currentSelectedAIModelID()) == nil,
            currentSelectedAIModelID() != fallbackModelID
        {
            let previousSelection = currentSelectedAIModelID()
            setSelectedAIModelID(fallbackModelID)
            if previousSelection != nil, fallbackModelID != nil {
                appendDiagnostic(
                    "Das zuvor gewählte AI-Modell ist nicht mehr verfügbar. Ein anderes verfügbares Modell wurde ausgewählt."
                )
            }
        }

        if currentAIProcessingEnabled(),
            let selectedAIModelID = currentSelectedAIModelID(),
            let selectedAIModel = catalog.model(id: selectedAIModelID),
            !selectedAIModel.availability.isAvailable
        {
            setAIProcessingEnabled(false)
            appendDiagnostic(
                "AI-Verarbeitung wurde deaktiviert, weil das ausgewählte Modell aktuell nicht verfügbar ist."
            )
        }

        appendAudit(
            "ai.catalog.refresh reason=\(reason) models=\(catalog.allModels.count) available=\(catalog.availableModels.count)"
        )
    }

    private var selectedRemoteProvider: AIRemoteProviderConfiguration? {
        guard let selectedRemoteProviderID = currentSelectedRemoteProviderID() else { return nil }
        return currentRemoteProviders().first(where: { $0.id == selectedRemoteProviderID })
    }

    private func updateRemoteProvider(
        id providerID: String,
        _ update: (inout AIRemoteProviderConfiguration) -> Void
    ) {
        guard let index = currentRemoteProviders().firstIndex(where: { $0.id == providerID }) else {
            return
        }

        var providers = currentRemoteProviders()
        var provider = providers[index]
        update(&provider)
        providers[index] = provider
        setRemoteProviders(providers)
    }

    private func makeAIProviders() -> [any AITextProcessingProviding] {
        var providers: [any AITextProcessingProviding] = [AppleFoundationTextProcessor()]

        for provider in currentRemoteProviders() where provider.isEnabled {
            let apiKey = aiRemoteProviderSecretStore.loadAPIKey(providerID: provider.id) ?? ""
            if provider.requiresAPIKey,
                apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            {
                continue
            }

            providers.append(
                OpenAICompatibleRemoteTextProcessor(configuration: provider, apiKey: apiKey))
        }

        return providers
    }
}
