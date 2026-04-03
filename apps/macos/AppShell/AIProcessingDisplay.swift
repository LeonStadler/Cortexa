import AIProcessingCore
import Foundation

extension AIWritingStyle {
    func localizedDisplayName(interfaceLanguageCode: String) -> String {
        switch (interfaceLanguageCode, self) {
        case ("en", .none):
            return "None"
        case ("en", .simple):
            return "Simple"
        case ("en", .business):
            return "Business"
        case ("en", .academic):
            return "Academic"
        case ("en", .casual):
            return "Casual"
        case ("en", .enthusiastic):
            return "Enthusiastic"
        case ("en", .friendlyConfident):
            return "Friendly confident"
        case ("en", .diplomatic):
            return "Diplomatic"
        case (_, .none):
            return "Kein Stil"
        case (_, .simple):
            return "Einfach"
        case (_, .business):
            return "Geschäftlich"
        case (_, .academic):
            return "Akademisch"
        case (_, .casual):
            return "Locker"
        case (_, .enthusiastic):
            return "Enthusiastisch"
        case (_, .friendlyConfident):
            return "Freundlich souverän"
        case (_, .diplomatic):
            return "Diplomatisch"
        }
    }
}

extension AISalutation {
    func localizedDisplayName(interfaceLanguageCode: String) -> String {
        switch (interfaceLanguageCode, self) {
        case ("en", .none):
            return "Keep as is"
        case ("en", .formal):
            return "Formal"
        case ("en", .informal):
            return "Informal"
        case (_, .none):
            return "Wie gesprochen"
        case (_, .formal):
            return "Formell"
        case (_, .informal):
            return "Informell"
        }
    }
}

extension AIModelAvailability {
    func localizedDisplayName(interfaceLanguageCode: String) -> String {
        switch self {
        case .available:
            return interfaceLanguageCode == "en" ? "Available" : "Verfügbar"
        case .unavailable(let reason):
            let prefix = interfaceLanguageCode == "en" ? "Unavailable" : "Nicht verfügbar"
            return "\(prefix): \(reason)"
        }
    }
}

extension AIRemoteProviderPreset {
    func localizedDisplayName(interfaceLanguageCode: String) -> String {
        switch (interfaceLanguageCode, self) {
        case ("en", .openRouter):
            return "OpenRouter"
        case ("en", .openAI):
            return "OpenAI"
        case ("en", .groq):
            return "Groq"
        case ("en", .mistral):
            return "Mistral"
        case ("en", .deepSeek):
            return "DeepSeek"
        case ("en", .togetherAI):
            return "Together AI"
        case ("en", .fireworksAI):
            return "Fireworks AI"
        case ("en", .xAI):
            return "xAI"
        case ("en", .ollama):
            return "Ollama"
        case ("en", .lmStudio):
            return "LM Studio"
        case ("en", .customOpenAICompatible):
            return "Custom OpenAI-compatible"
        case (_, .openRouter):
            return "OpenRouter"
        case (_, .openAI):
            return "OpenAI"
        case (_, .groq):
            return "Groq"
        case (_, .mistral):
            return "Mistral"
        case (_, .deepSeek):
            return "DeepSeek"
        case (_, .togetherAI):
            return "Together AI"
        case (_, .fireworksAI):
            return "Fireworks AI"
        case (_, .xAI):
            return "xAI"
        case (_, .ollama):
            return "Ollama"
        case (_, .lmStudio):
            return "LM Studio"
        case (_, .customOpenAICompatible):
            return "Eigener OpenAI-kompatibler Anbieter"
        }
    }
}
