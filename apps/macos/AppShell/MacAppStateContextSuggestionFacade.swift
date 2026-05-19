import ApplicationServices
import Foundation

enum MacAppStateContextSuggestionFacade {
    private static var rejectedCandidateBackoffUntil: [String: Date] = [:]
    private static let rejectedCandidateCooldown: TimeInterval = 60 * 60 * 12

    static func handleDictionaryCandidatesIfNeeded(
        isAutoAddEnabled: Bool,
        event: FinalTranscriptEvent,
        currentReviewQueueCount: () -> Int,
        queueCandidate: (String, DictionaryTermCategory, String?) -> Void,
        appendDiagnostic: (String) -> Void
    ) {
        guard isAutoAddEnabled else { return }

        let added = autoQueueDictionaryCandidates(
            from: event.text,
            languageCode: event.languageCode,
            currentReviewQueueCount: currentReviewQueueCount,
            queueCandidate: queueCandidate
        )

        if added > 0 {
            appendDiagnostic("Dictionary-Vorschläge ergänzt: \(added)")
        }
    }

    static func autoQueueDictionaryCandidates(
        from text: String,
        languageCode: String,
        currentReviewQueueCount: () -> Int,
        queueCandidate: (String, DictionaryTermCategory, String?) -> Void
    ) -> Int {
        let before = currentReviewQueueCount()
        let normalizedLanguage = languageCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let scopedLanguage = normalizedLanguage.isEmpty ? nil : normalizedLanguage
        let maxNewCandidates = 8
        var added = 0
        var seenInTranscript = Set<String>()

        for phrase in matchedTerms(
            in: text,
            pattern: #"\b[A-ZÄÖÜ][\p{L}]{2,}\s+[A-ZÄÖÜ][\p{L}]{2,}\b"#
        ) {
            guard shouldAutoSuggestPersonPhrase(phrase) else { continue }
            let key = normalizedDictionaryKey(phrase, languageCode: scopedLanguage)
            guard !seenInTranscript.contains(key) else { continue }
            guard !isCandidateInBackoff(key) else { continue }
            seenInTranscript.insert(key)

            let queueCountBefore = currentReviewQueueCount()
            queueCandidate(phrase, .personName, scopedLanguage)
            if currentReviewQueueCount() > queueCountBefore {
                added += 1
            }
            if added >= maxNewCandidates {
                return max(0, currentReviewQueueCount() - before)
            }
        }

        for token in matchedTerms(in: text, pattern: #"\b[\p{L}\d][\p{L}\d\-\._]{2,}\b"#) {
            let normalizedToken = normalizeDictionaryCandidate(token)
            guard shouldAutoSuggestDictionaryToken(normalizedToken) else { continue }

            let key = normalizedDictionaryKey(normalizedToken, languageCode: scopedLanguage)
            guard !seenInTranscript.contains(key) else { continue }
            guard !isCandidateInBackoff(key) else { continue }
            seenInTranscript.insert(key)

            let category: DictionaryTermCategory =
                if normalizedToken.contains(where: { $0.isNumber }) || isUppercaseAcronym(normalizedToken) {
                    .industryLanguage
                } else {
                    .custom
                }

            let queueCountBefore = currentReviewQueueCount()
            queueCandidate(normalizedToken, category, scopedLanguage)
            if currentReviewQueueCount() > queueCountBefore {
                added += 1
            }
            if added >= maxNewCandidates {
                break
            }
        }

        return max(0, currentReviewQueueCount() - before)
    }

    static func normalizedDictionaryKey(_ term: String, languageCode: String?) -> String {
        let normalizedTerm = term
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let normalizedLanguage = languageCode?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? "*"
        return "\(normalizedLanguage)|\(normalizedTerm)"
    }

    static func buildDictionaryHintPrompt(
        selectedLanguage: DictationLanguage,
        dictionaryTerms: [DictionaryTerm],
        maxCharacters: Int = 320
    ) -> String? {
        let currentLanguageCode = selectedLanguage == .auto ? nil : selectedLanguage.rawValue
        let filtered = dictionaryTerms.filter { term in
            guard
                let languageCode = term.languageCode?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                !languageCode.isEmpty
            else {
                return true
            }
            guard let currentLanguageCode else { return true }
            return languageCode.caseInsensitiveCompare(currentLanguageCode) == .orderedSame
        }

        guard !filtered.isEmpty else { return nil }

        let rankedTerms = rankDictionaryTerms(
            filtered,
            currentLanguageCode: currentLanguageCode
        )

        var result = "Preferred terms: "
        for term in rankedTerms {
            let candidate = result == "Preferred terms: " ? "\(result)\(term)" : "\(result), \(term)"
            if candidate.count > maxCharacters { break }
            result = candidate
        }

        return result == "Preferred terms: " ? nil : result
    }

    static func bestEffortFocusedContextText(
        accessibilityPermissionStatus: PermissionStatus,
        maxLength: Int
    ) -> String? {
        guard accessibilityPermissionStatus == .granted else { return nil }

        let systemWide = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        let focusedResult = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedRef
        )

        guard focusedResult == .success, let focusedRef else {
            return nil
        }
        let focusedElement = focusedRef as! AXUIElement

        var valueRef: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(
                focusedElement,
                kAXValueAttribute as CFString,
                &valueRef
            ) == .success,
            let fullText = valueRef as? String
        else {
            return nil
        }

        let trimmed = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var selectedRangeRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(
            focusedElement,
            kAXSelectedTextRangeAttribute as CFString,
            &selectedRangeRef
        ) == .success,
            let axValue = selectedRangeRef,
            CFGetTypeID(axValue) == AXValueGetTypeID()
        {
            let selectedRangeValue = axValue as! AXValue
            var range = CFRange(location: 0, length: 0)
            if AXValueGetType(selectedRangeValue) == .cfRange,
                AXValueGetValue(selectedRangeValue, .cfRange, &range)
            {
                return contextWindow(
                    in: fullText,
                    cursorLocation: max(0, range.location),
                    maxLength: maxLength
                )
            }
        }

        if trimmed.count <= maxLength {
            return trimmed
        }
        return String(trimmed.suffix(maxLength))
    }

    static func contextWindow(in text: String, cursorLocation: Int, maxLength: Int) -> String? {
        guard !text.isEmpty else { return nil }
        let safeCursor = min(max(0, cursorLocation), text.count)
        let beforeLength = maxLength / 2
        let afterLength = maxLength - beforeLength

        let startOffset = max(0, safeCursor - beforeLength)
        let endOffset = min(text.count, safeCursor + afterLength)

        let startIndex = text.index(text.startIndex, offsetBy: startOffset)
        let endIndex = text.index(text.startIndex, offsetBy: endOffset)
        let window = String(text[startIndex..<endIndex]).trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        return window.isEmpty ? nil : window
    }

    static let commonAutoAddStopwords: Set<String> = [
        "aber", "als", "am", "an", "auch", "auf", "aus", "bei", "bin", "bist", "da", "dann",
        "das", "dein", "der", "des", "die", "dir", "doch", "du", "ein", "eine", "einer", "eines",
        "er", "es", "für", "hat", "hast", "hier", "ich", "im", "in", "ist", "ja", "kein", "mit",
        "nach", "nicht", "noch", "oder", "schon", "sein", "sind", "so", "und", "vom", "von",
        "war", "was", "wenn", "wie", "wir", "wird", "you", "your", "the", "this", "that", "and",
        "for", "from", "with", "have", "has", "are", "was", "were", "not", "but", "what", "when",
        "where", "which", "who", "why", "can", "could", "would", "should", "will",
    ]

    private static func matchedTerms(in text: String, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }

        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, options: [], range: nsRange)
        return matches.compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            return String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private static func shouldAutoSuggestDictionaryToken(_ token: String) -> Bool {
        guard token.count >= 3, token.count <= 40 else { return false }
        guard !isLikelyCommonWord(token) else { return false }

        if isUppercaseAcronym(token) {
            return true
        }
        if token.contains(where: { $0.isNumber }) && token.contains(where: { $0.isLetter }) {
            return true
        }
        guard let first = token.first, first.isUppercase else {
            return false
        }
        return token.dropFirst().contains(where: { $0.isUppercase })
    }

    private static func isUppercaseAcronym(_ token: String) -> Bool {
        let letters = token.filter(\.isLetter)
        guard letters.count >= 2 else { return false }
        return letters == letters.uppercased()
    }

    private static func shouldAutoSuggestPersonPhrase(_ phrase: String) -> Bool {
        let components = phrase.split(whereSeparator: \.isWhitespace).map(String.init)
        guard components.count == 2 else { return false }
        guard components.allSatisfy({ !$0.isEmpty && !$0.contains(where: { $0.isNumber }) }) else {
            return false
        }
        guard components.allSatisfy({ !isLikelyCommonWord($0) }) else { return false }
        return true
    }

    private static func normalizeDictionaryCandidate(_ candidate: String) -> String {
        candidate.trimmingCharacters(
            in: CharacterSet(charactersIn: " \t\n\r.,;:!?()[]{}\"'")
        )
    }

    private static func isLikelyCommonWord(_ token: String) -> Bool {
        let normalized = token
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
        return commonAutoAddStopwords.contains(normalized)
    }

    static func registerRejectedCandidate(_ term: String, languageCode: String?) {
        let key = normalizedDictionaryKey(term, languageCode: languageCode)
        rejectedCandidateBackoffUntil[key] = Date().addingTimeInterval(rejectedCandidateCooldown)
    }

    private static func isCandidateInBackoff(_ key: String) -> Bool {
        pruneExpiredRejectedBackoffEntries()
        guard let until = rejectedCandidateBackoffUntil[key] else {
            return false
        }
        return until > Date()
    }

    private static func pruneExpiredRejectedBackoffEntries() {
        let now = Date()
        rejectedCandidateBackoffUntil = rejectedCandidateBackoffUntil.filter { $0.value > now }
    }

    private static func rankDictionaryTerms(
        _ terms: [DictionaryTerm],
        currentLanguageCode: String?
    ) -> [String] {
        let deduped = dedupeDictionaryTerms(terms)
        return deduped
            .sorted { lhs, rhs in
                let lhsScore = dictionaryPriorityScore(lhs, currentLanguageCode: currentLanguageCode)
                let rhsScore = dictionaryPriorityScore(rhs, currentLanguageCode: currentLanguageCode)
                if lhsScore != rhsScore {
                    return lhsScore > rhsScore
                }
                return lhs.createdAt > rhs.createdAt
            }
            .map(\.term)
    }

    private static func dedupeDictionaryTerms(_ terms: [DictionaryTerm]) -> [DictionaryTerm] {
        var seen: Set<String> = []
        var deduped: [DictionaryTerm] = []
        for term in terms {
            let normalized = normalizedDictionaryKey(term.term, languageCode: term.languageCode)
            if seen.contains(normalized) {
                continue
            }
            seen.insert(normalized)
            deduped.append(term)
        }
        return deduped
    }

    private static func dictionaryPriorityScore(
        _ term: DictionaryTerm,
        currentLanguageCode: String?
    ) -> Int {
        var score = 0

        if let currentLanguageCode,
            let languageCode = term.languageCode?.trimmingCharacters(in: .whitespacesAndNewlines),
            !languageCode.isEmpty,
            languageCode.caseInsensitiveCompare(currentLanguageCode) == .orderedSame
        {
            score += 20
        }

        switch term.category {
        case .personName, .clientName:
            score += 15
        case .companyJargon, .industryLanguage:
            score += 10
        case .personalTerm:
            score += 7
        case .custom:
            score += 4
        }

        if term.source == .manual {
            score += 4
        }

        if term.term.count <= 24 {
            score += 2
        }

        return score
    }
}

extension MacAppState {
    func handleDictionaryCandidatesIfNeeded(from event: FinalTranscriptEvent) {
        MacAppStateContextSuggestionFacade.handleDictionaryCandidatesIfNeeded(
            isAutoAddEnabled: dictionaryAutoAddEnabled,
            event: event,
            currentReviewQueueCount: { [unowned self] in
                self.dictionaryReviewQueue.count
            },
            queueCandidate: { [unowned self] term, category, languageCode in
                self.queueDictionaryCandidate(term, category: category, languageCode: languageCode)
            },
            appendDiagnostic: { [unowned self] line in
                self.appendDiagnostic(line)
            }
        )
    }

    func buildDictionaryHintPrompt(maxCharacters: Int = 320) -> String? {
        MacAppStateContextSuggestionFacade.buildDictionaryHintPrompt(
            selectedLanguage: selectedLanguage,
            dictionaryTerms: dictionaryTerms,
            maxCharacters: maxCharacters
        )
    }

    func bestEffortFocusedContextText(maxLength: Int) -> String? {
        MacAppStateContextSuggestionFacade.bestEffortFocusedContextText(
            accessibilityPermissionStatus: accessibilityPermissionStatus,
            maxLength: maxLength
        )
    }
}
