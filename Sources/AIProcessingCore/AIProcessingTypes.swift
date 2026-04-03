import Foundation

public enum AIProviderKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case appleFoundation
    case localDownloaded
    case remoteAPI

    public var id: String { rawValue }
}

public enum AIModelAvailability: Codable, Equatable, Sendable {
    case available
    case unavailable(reason: String)

    public var isAvailable: Bool {
        if case .available = self {
            return true
        }
        return false
    }

    public var reason: String? {
        if case let .unavailable(reason) = self {
            return reason
        }
        return nil
    }
}

public struct AIModelDescriptor: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let providerID: String
    public let requestModelID: String
    public let displayName: String
    public let providerKind: AIProviderKind
    public let availability: AIModelAvailability
    public let quickSettingsEligible: Bool

    public init(
        id: String,
        providerID: String? = nil,
        requestModelID: String? = nil,
        displayName: String,
        providerKind: AIProviderKind,
        availability: AIModelAvailability,
        quickSettingsEligible: Bool
    ) {
        self.id = id
        self.providerID = providerID ?? id
        self.requestModelID = requestModelID ?? id
        self.displayName = displayName
        self.providerKind = providerKind
        self.availability = availability
        self.quickSettingsEligible = quickSettingsEligible
    }
}

public enum AIRemoteProviderPreset: String, Codable, CaseIterable, Identifiable, Sendable {
    case openRouter
    case openAI
    case groq
    case mistral
    case deepSeek
    case togetherAI
    case fireworksAI
    case xAI
    case ollama
    case lmStudio
    case customOpenAICompatible

    public var id: String { rawValue }

    public var defaultDisplayName: String {
        switch self {
        case .openRouter:
            return "OpenRouter"
        case .openAI:
            return "OpenAI"
        case .groq:
            return "Groq"
        case .mistral:
            return "Mistral"
        case .deepSeek:
            return "DeepSeek"
        case .togetherAI:
            return "Together AI"
        case .fireworksAI:
            return "Fireworks AI"
        case .xAI:
            return "xAI"
        case .ollama:
            return "Ollama"
        case .lmStudio:
            return "LM Studio"
        case .customOpenAICompatible:
            return "Custom API"
        }
    }

    public var defaultBaseURLString: String {
        switch self {
        case .openRouter:
            return "https://openrouter.ai/api/v1"
        case .openAI:
            return "https://api.openai.com/v1"
        case .groq:
            return "https://api.groq.com/openai/v1"
        case .mistral:
            return "https://api.mistral.ai/v1"
        case .deepSeek:
            return "https://api.deepseek.com/v1"
        case .togetherAI:
            return "https://api.together.xyz/v1"
        case .fireworksAI:
            return "https://api.fireworks.ai/inference/v1"
        case .xAI:
            return "https://api.x.ai/v1"
        case .ollama:
            return "http://localhost:11434/v1"
        case .lmStudio:
            return "http://localhost:1234/v1"
        case .customOpenAICompatible:
            return "https://api.example.com/v1"
        }
    }

    public var defaultModelsPath: String { "/models" }

    public var defaultChatCompletionsPath: String { "/chat/completions" }

    public var requiresAPIKey: Bool {
        switch self {
        case .ollama, .lmStudio:
            return false
        default:
            return true
        }
    }

    public var supportsOpenRouterHeaders: Bool {
        self == .openRouter
    }
}

public struct AIRemoteProviderConfiguration: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var preset: AIRemoteProviderPreset
    public var displayName: String
    public var baseURLString: String
    public var modelsPath: String
    public var chatCompletionsPath: String
    public var requiresAPIKey: Bool
    public var isEnabled: Bool
    public var appReferer: String?
    public var appTitle: String?
    public var discoveredModels: [AIRemoteModel]

    public init(
        id: String = UUID().uuidString,
        preset: AIRemoteProviderPreset,
        displayName: String,
        baseURLString: String,
        modelsPath: String = "/models",
        chatCompletionsPath: String = "/chat/completions",
        requiresAPIKey: Bool? = nil,
        isEnabled: Bool = true,
        appReferer: String? = nil,
        appTitle: String? = nil,
        discoveredModels: [AIRemoteModel] = []
    ) {
        self.id = id
        self.preset = preset
        self.displayName = displayName
        self.baseURLString = baseURLString
        self.modelsPath = modelsPath
        self.chatCompletionsPath = chatCompletionsPath
        self.requiresAPIKey = requiresAPIKey ?? preset.requiresAPIKey
        self.isEnabled = isEnabled
        self.appReferer = appReferer
        self.appTitle = appTitle
        self.discoveredModels = discoveredModels
    }

    public static func template(
        for preset: AIRemoteProviderPreset,
        appTitle: String = "WisprLocal",
        appReferer: String? = nil
    ) -> AIRemoteProviderConfiguration {
        AIRemoteProviderConfiguration(
            preset: preset,
            displayName: preset.defaultDisplayName,
            baseURLString: preset.defaultBaseURLString,
            modelsPath: preset.defaultModelsPath,
            chatCompletionsPath: preset.defaultChatCompletionsPath,
            requiresAPIKey: preset.requiresAPIKey,
            isEnabled: true,
            appReferer: preset.supportsOpenRouterHeaders ? appReferer : nil,
            appTitle: appTitle
        )
    }
}

public struct AIRemoteModel: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let displayName: String
    public let quickSettingsEligible: Bool

    public init(id: String, displayName: String, quickSettingsEligible: Bool = true) {
        self.id = id
        self.displayName = displayName
        self.quickSettingsEligible = quickSettingsEligible
    }
}

public enum AIWritingStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case none
    case simple
    case business
    case academic
    case casual
    case enthusiastic
    case friendlyConfident
    case diplomatic

    public var id: String { rawValue }
}

public enum AISalutation: String, Codable, CaseIterable, Identifiable, Sendable {
    case none
    case formal
    case informal

    public var id: String { rawValue }
}

public struct AIProcessingConfiguration: Codable, Equatable, Sendable {
    public let enabled: Bool
    public let selectedModelID: String?
    public let applyDuringLiveInsertion: Bool
    public let applyToFinalResult: Bool
    public let style: AIWritingStyle
    public let salutation: AISalutation

    public init(
        enabled: Bool,
        selectedModelID: String?,
        applyDuringLiveInsertion: Bool = false,
        applyToFinalResult: Bool = true,
        style: AIWritingStyle = .none,
        salutation: AISalutation = .none
    ) {
        self.enabled = enabled
        self.selectedModelID = selectedModelID
        self.applyDuringLiveInsertion = applyDuringLiveInsertion
        self.applyToFinalResult = applyToFinalResult
        self.style = style
        self.salutation = salutation
    }
}

public enum AIProcessingStage: String, Sendable, Equatable {
    case live
    case final
}

public struct AIProcessingRequest: Sendable {
    public let text: String
    public let stage: AIProcessingStage
    public let locale: Locale
    public let configuration: AIProcessingConfiguration

    public init(
        text: String,
        stage: AIProcessingStage,
        locale: Locale,
        configuration: AIProcessingConfiguration
    ) {
        self.text = text
        self.stage = stage
        self.locale = locale
        self.configuration = configuration
    }
}

public enum AIProcessingOutcome: Sendable, Equatable {
    case bypassed(text: String, reason: String)
    case processed(text: String, modelID: String)
    case failedFallback(text: String, modelID: String?, reason: String)

    public var text: String {
        switch self {
        case let .bypassed(text, _), let .processed(text, _), let .failedFallback(text, _, _):
            return text
        }
    }

    public var diagnosticMessage: String? {
        switch self {
        case let .bypassed(_, reason):
            return reason
        case let .processed(_, modelID):
            return "AI processing applied with model \(modelID)."
        case let .failedFallback(_, _, reason):
            return reason
        }
    }
}
