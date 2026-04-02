import Foundation

public protocol AITextProcessingProviding: Sendable {
    var providerKind: AIProviderKind { get }
    func models() -> [AIModelDescriptor]
    func process(_ request: AIProcessingRequest, model: AIModelDescriptor) async throws -> String
}

public enum AIProcessingError: LocalizedError {
    case providerUnavailable(String)
    case modelUnavailable(String)
    case modelNotFound(String)

    public var errorDescription: String? {
        switch self {
        case let .providerUnavailable(reason),
             let .modelUnavailable(reason):
            return reason
        case let .modelNotFound(modelID):
            return "AI model \(modelID) was not found."
        }
    }
}

public struct AIModelCatalog: Sendable {
    private let descriptors: [AIModelDescriptor]

    public init(descriptors: [AIModelDescriptor]) {
        self.descriptors = descriptors.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    public var allModels: [AIModelDescriptor] {
        descriptors
    }

    public var availableModels: [AIModelDescriptor] {
        descriptors.filter { $0.availability.isAvailable }
    }

    public var quickSettingsModels: [AIModelDescriptor] {
        descriptors.filter { $0.quickSettingsEligible && $0.availability.isAvailable }
    }

    public func model(id: String?) -> AIModelDescriptor? {
        guard let id else { return nil }
        return descriptors.first(where: { $0.id == id })
    }
}

public struct AIProcessingService: Sendable {
    private let providers: [AIProviderKind: any AITextProcessingProviding]

    public init(providers: [AIProviderKind: any AITextProcessingProviding] = Self.makeDefaultProviders()) {
        self.providers = providers
    }

    public func catalog() -> AIModelCatalog {
        AIModelCatalog(descriptors: providers.values.flatMap { $0.models() })
    }

    public func process(_ request: AIProcessingRequest) async -> AIProcessingOutcome {
        let trimmed = request.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .bypassed(text: request.text, reason: "AI processing skipped because the text is empty.")
        }

        let configuration = request.configuration
        guard configuration.enabled else {
            return .bypassed(text: request.text, reason: "AI processing is disabled.")
        }

        if request.stage == .live, configuration.scope == .finalOnly {
            return .bypassed(text: request.text, reason: "AI processing is limited to final transcripts.")
        }

        let catalog = catalog()
        guard let model = catalog.model(id: configuration.selectedModelID) else {
            return .bypassed(text: request.text, reason: "AI processing skipped because no usable model is selected.")
        }

        guard model.availability.isAvailable else {
            let reason = model.availability.reason ?? "The selected AI model is currently unavailable."
            return .bypassed(text: request.text, reason: reason)
        }

        guard let provider = providers[model.providerKind] else {
            return .failedFallback(text: request.text, modelID: model.id, reason: "AI provider is not configured.")
        }

        do {
            let processed = try await provider.process(request, model: model)
            let normalized = processed.trimmingCharacters(in: .whitespacesAndNewlines)
            if normalized.isEmpty {
                return .failedFallback(text: request.text, modelID: model.id, reason: "AI processing returned an empty result. Keeping the original text.")
            }
            return .processed(text: normalized, modelID: model.id)
        } catch {
            return .failedFallback(
                text: request.text,
                modelID: model.id,
                reason: "AI processing failed: \(error.localizedDescription). Keeping the original text."
            )
        }
    }

    private static func makeDefaultProviders() -> [AIProviderKind: any AITextProcessingProviding] {
        [AppleFoundationTextProcessor().providerKind: AppleFoundationTextProcessor()]
    }
}
