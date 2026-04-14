import Foundation
import NaturalLanguage

struct AIProcessingOutputValidator {
    func validate(originalText: String, processedText: String) -> String? {
        let trimmedOriginal = originalText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedProcessed = processedText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedOriginal.isEmpty, !trimmedProcessed.isEmpty else {
            return nil
        }

        guard let originalLanguage = dominantLanguage(for: trimmedOriginal),
              let processedLanguage = dominantLanguage(for: trimmedProcessed) else {
            return nil
        }

        if originalLanguage != processedLanguage {
            return "AI processing changed the dominant language from \(originalLanguage.rawValue) to \(processedLanguage.rawValue). Keeping the original text."
        }

        return nil
    }

    private func dominantLanguage(for text: String) -> NLLanguage? {
        guard text.count >= 12 else {
            return nil
        }

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        guard let language = recognizer.dominantLanguage else {
            return nil
        }

        let confidence = recognizer.languageHypotheses(withMaximum: 1)[language] ?? 0
        guard confidence >= 0.5 else {
            return nil
        }

        return language
    }
}
