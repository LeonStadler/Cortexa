import Foundation

struct AppleFoundationPromptBuilder {
    private let maxContextCharacters = 600

    func prompt(for request: AIProcessingRequest) -> String {
        let stageInstruction = request.stage == .live
            ? "This is a live dictation tail. Make the smallest useful rewrite."
            : "This is the final dictated text. Polish it fully while preserving the meaning."

        var sections = [stageInstruction]

        if shouldIncludeContext(for: request),
           let context = boundedContext(from: request.appContextText) {
            sections.append("Relevant app context for spelling and disambiguation (do not quote it unless needed): \(context)")
        }

        let terms = normalizedDictionaryTerms(request.dictionaryTerms)
        if !terms.isEmpty {
            sections.append("Preserve and spell these preferred terms exactly when applicable: \(terms.joined(separator: ", ")).")
        }

        sections.append(request.text)
        return sections.joined(separator: "\n\n")
    }

    private func shouldIncludeContext(for request: AIProcessingRequest) -> Bool {
        switch request.configuration.contextAwarenessMode {
        case .off:
            return false
        case .finalOnly:
            return request.stage == .final
        case .liveOnly:
            return request.stage == .live
        case .liveAndFinal:
            return true
        }
    }

    private func boundedContext(from rawContext: String?) -> String? {
        guard let rawContext else { return nil }
        let trimmed = rawContext.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.count <= maxContextCharacters {
            return trimmed
        }

        let endIndex = trimmed.index(trimmed.startIndex, offsetBy: maxContextCharacters)
        return String(trimmed[..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizedDictionaryTerms(_ terms: [String]) -> [String] {
        var seen = Set<String>()
        var result = [String]()
        for rawTerm in terms {
            let term = rawTerm.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !term.isEmpty else { continue }

            let key = term.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(term)
        }
        return result
    }
}
