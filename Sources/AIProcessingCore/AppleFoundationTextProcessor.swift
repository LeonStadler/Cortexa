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
        let relevantStyle = configuration.formattingMode.allowedWritingStyles.contains(configuration.style)
            ? configuration.style
            : .none
        let relevantSalutation = configuration.formattingMode.supportsSalutation
            ? configuration.salutation
            : .none

        let goalInstruction: String
        switch configuration.revisionGoal {
        case .cleanup:
            goalInstruction = "Your default task is to clean up dictated text by fixing recognition artifacts, punctuation, casing, and obvious grammar while keeping the wording as close to the original as possible."
        case .adjustTone:
            goalInstruction = "Your main task is to keep the meaning while adapting the text to the requested tone."
        case .adjustSalutation:
            goalInstruction = "Your main task is to adjust the form of address while changing the surrounding wording as little as possible."
        case .adaptFormat:
            goalInstruction = "Your main task is to adapt the dictated text to the requested output format while preserving the meaning."
        }

        let formatInstruction: String
        switch configuration.formattingMode {
        case .plainText:
            formatInstruction = "Keep the output as plain running text unless the input already provides a stronger structure."
        case .email:
            formatInstruction = "Format the output as an email with a suitable greeting, body, and closing when helpful."
        case .message:
            formatInstruction = "Format the output as a concise personal or professional message."
        case .whatsapp:
            formatInstruction = "Format the output as a concise WhatsApp-style message with natural short phrasing."
        case .documentation:
            formatInstruction = "Format the output as concise documentation with clear structure, neutral wording, and no conversational phrasing."
        case .scientificPaper:
            formatInstruction = "Format the output as scientific prose with precise terminology, formal structure, and no casual wording."
        }

        let styleInstruction: String
        switch relevantStyle {
        case .none:
            styleInstruction = "Keep the natural tone that best fits the requested task and format."
        case .simple:
            styleInstruction = "Use a simple, clear style."
        case .business:
            styleInstruction = "Use a businesslike, professional style."
        case .academic:
            styleInstruction = "Use an academic, precise style."
        case .casual:
            styleInstruction = "Use a casual, natural style."
        case .enthusiastic:
            styleInstruction = "Use an enthusiastic, energetic style."
        case .friendlyConfident:
            styleInstruction = "Use a friendly and confident style."
        case .diplomatic:
            styleInstruction = "Use a diplomatic, tactful style."
        }

        let salutationInstruction: String
        switch relevantSalutation {
        case .none:
            salutationInstruction = "Keep the existing form of address unless it is obviously inconsistent with the requested format."
        case .formal:
            salutationInstruction = "Use a formal form of address."
        case .informal:
            salutationInstruction = "Use an informal form of address."
        }

        return [
            "You revise dictated text without changing its meaning.",
            goalInstruction,
            "Preserve the input language exactly as given.",
            "Do not translate unless the text is already translated before it reaches you.",
            "If the safest way to preserve the language or meaning is unclear, return the input unchanged.",
            "Preserve names, numbers, dates, and factual content.",
            formatInstruction,
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
