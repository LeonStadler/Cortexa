import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

public struct AppleFoundationTextProcessor: AITextProcessingProviding {
    public let providerID: String = "apple.foundation"
    public let providerKind: AIProviderKind = .appleFoundation
    private let defaultModelID = "apple.ondevice"

    public init() {}

    public func models() -> [AIModelDescriptor] {
        let availability = currentAvailability()
        return [AIModelDescriptor(
            id: defaultModelID,
            providerID: providerID,
            requestModelID: defaultModelID,
            displayName: "Apple On-Device",
            providerKind: providerKind,
            availability: availability,
            quickSettingsEligible: availability.isAvailable
        )]
    }

    public func process(_ request: AIProcessingRequest, model: AIModelDescriptor) async throws -> String {
        guard model.id == defaultModelID else {
            throw AIProcessingError.modelNotFound(model.id)
        }

        switch currentAvailability() {
        case .available:
            break
        case let .unavailable(reason):
            throw AIProcessingError.modelUnavailable(reason)
        }

        #if canImport(FoundationModels)
        if #available(macOS 26.0, iOS 26.0, visionOS 26.0, *) {
            let systemModel = SystemLanguageModel.default
            guard systemModel.isAvailable else {
                throw AIProcessingError.modelUnavailable(unavailabilityReason(for: systemModel.availability))
            }

            let session = LanguageModelSession(
                model: systemModel,
                instructions: AppleFoundationPromptBuilder.instructions(for: request.configuration)
            )
            let response = try await session.respond(to: AppleFoundationPromptBuilder.prompt(for: request))
            return response.content
        }
        #endif

        throw AIProcessingError.providerUnavailable("Apple Foundation Models are not available on this OS version.")
    }

    private func currentAvailability() -> AIModelAvailability {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, iOS 26.0, visionOS 26.0, *) {
            let model = SystemLanguageModel.default
            if model.isAvailable {
                return .available
            }
            return .unavailable(reason: unavailabilityReason(for: model.availability))
        }
        #endif

        return .unavailable(reason: "Requires Apple Foundation Models on a supported macOS version.")
    }
    private func unavailabilityReason(for availability: Any) -> String {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, iOS 26.0, visionOS 26.0, *),
           let availability = availability as? SystemLanguageModel.Availability {
            switch availability {
            case .available:
                return "Available"
            case let .unavailable(reason):
                switch reason {
                case .deviceNotEligible:
                    return "This Mac is not eligible for Apple on-device AI."
                case .appleIntelligenceNotEnabled:
                    return "Apple Intelligence is not enabled on this Mac."
                case .modelNotReady:
                    return "The Apple on-device model is not ready yet."
                @unknown default:
                    return "Apple on-device AI is currently unavailable."
                }
            }
        }
        #endif

        return "Apple on-device AI is currently unavailable."
    }
}

enum AppleFoundationPromptBuilder {
    static func instructions(for configuration: AIProcessingConfiguration) -> String {
        let styleInstruction: String
        switch configuration.style {
        case .none:
            styleInstruction = "Keep the original tone unless the prompt asks for a specific adjustment."
        case .simple:
            styleInstruction = "Rewrite in a simple, clear style."
        case .business:
            styleInstruction = "Rewrite in a businesslike, professional style."
        case .academic:
            styleInstruction = "Rewrite in an academic, precise style."
        case .casual:
            styleInstruction = "Rewrite in a casual, natural style."
        case .enthusiastic:
            styleInstruction = "Rewrite in an enthusiastic, energetic style."
        case .friendlyConfident:
            styleInstruction = "Rewrite in a friendly and confident style."
        case .diplomatic:
            styleInstruction = "Rewrite in a diplomatic, tactful style."
        }

        let salutationInstruction: String
        switch configuration.salutation {
        case .none:
            salutationInstruction = "Keep the existing form of address unless it is obviously inconsistent."
        case .formal:
            salutationInstruction = "Use a formal form of address."
        case .informal:
            salutationInstruction = "Use an informal form of address."
        }

        return [
            "You revise dictated text without changing its meaning.",
            "Keep the wording as close to the original as possible.",
            "Preserve the input language exactly as given.",
            "Do not translate unless the text is already translated before it reaches you.",
            "If the safest way to preserve the language or meaning is unclear, return the input unchanged.",
            "Preserve names, numbers, dates, and factual content.",
            styleInstruction,
            salutationInstruction,
            "Return only the revised text without commentary."
        ].joined(separator: " ")
    }

    static func prompt(for request: AIProcessingRequest) -> String {
        let languageHint = languageHint(for: request.locale)
        let stageInstruction = request.stage == .live
            ? "This is a live dictation tail. Make only the smallest useful rewrite."
            : "This is the final dictated text. Polish it while preserving the meaning and the original language."

        return [
            stageInstruction,
            "The text language is \(languageHint). Your answer must stay in \(languageHint).",
            "Text to revise:",
            "<input>",
            request.text,
            "</input>"
        ].joined(separator: "\n")
    }

    private static func languageHint(for locale: Locale) -> String {
        if let languageCode = locale.language.languageCode?.identifier,
           let localized = Locale(identifier: "en_US").localizedString(forLanguageCode: languageCode) {
            return localized
        }

        if !locale.identifier.isEmpty {
            return locale.identifier
        }

        return "the original input language"
    }
}
