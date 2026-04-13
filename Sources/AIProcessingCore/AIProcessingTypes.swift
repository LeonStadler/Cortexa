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
    public let displayName: String
    public let providerKind: AIProviderKind
    public let availability: AIModelAvailability
    public let quickSettingsEligible: Bool

    public init(
        id: String,
        displayName: String,
        providerKind: AIProviderKind,
        availability: AIModelAvailability,
        quickSettingsEligible: Bool
    ) {
        self.id = id
        self.displayName = displayName
        self.providerKind = providerKind
        self.availability = availability
        self.quickSettingsEligible = quickSettingsEligible
    }
}

public enum AIProcessingScope: String, Codable, CaseIterable, Identifiable, Sendable {
    case finalOnly
    case liveAndFinal

    public var id: String { rawValue }
}

public enum ContextAwarenessMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case off
    case finalOnly
    case liveOnly
    case liveAndFinal

    public var id: String { rawValue }
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
    public let scope: AIProcessingScope
    public let contextAwarenessMode: ContextAwarenessMode
    public let style: AIWritingStyle
    public let salutation: AISalutation

    public init(
        enabled: Bool,
        selectedModelID: String?,
        scope: AIProcessingScope = .finalOnly,
        contextAwarenessMode: ContextAwarenessMode = .finalOnly,
        style: AIWritingStyle = .none,
        salutation: AISalutation = .none
    ) {
        self.enabled = enabled
        self.selectedModelID = selectedModelID
        self.scope = scope
        self.contextAwarenessMode = contextAwarenessMode
        self.style = style
        self.salutation = salutation
    }
}

public enum AIProcessingStage: String, Sendable {
    case live
    case final
}

public struct AIProcessingRequest: Sendable {
    public let text: String
    public let stage: AIProcessingStage
    public let locale: Locale
    public let configuration: AIProcessingConfiguration
    public let appContextText: String?
    public let dictionaryTerms: [String]

    public init(
        text: String,
        stage: AIProcessingStage,
        locale: Locale,
        configuration: AIProcessingConfiguration,
        appContextText: String? = nil,
        dictionaryTerms: [String] = []
    ) {
        self.text = text
        self.stage = stage
        self.locale = locale
        self.configuration = configuration
        self.appContextText = appContextText
        self.dictionaryTerms = dictionaryTerms
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
