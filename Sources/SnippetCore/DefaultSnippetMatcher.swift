import Foundation
import NaturalLanguage

public final class DefaultSnippetMatcher: SnippetMatcher {
    private let rules: [SnippetRule]
    private var tokenWindow: [String] = []
    private let maxWindowTokens: Int
    private let tokenizer = NLTokenizer(unit: .word)

    public init(rules: [SnippetRule], maxWindowTokens: Int = 8) {
        self.rules = rules
            .filter { !$0.trigger.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { lhs, rhs in
                let lhsCount = Self.tokenizePhrase(lhs.trigger).count
                let rhsCount = Self.tokenizePhrase(rhs.trigger).count
                if lhsCount == rhsCount {
                    return lhs.trigger.count > rhs.trigger.count
                }
                return lhsCount > rhsCount
            }
        self.maxWindowTokens = max(2, maxWindowTokens)
    }

    public func applyToFinal(_ text: String, locale: Locale) -> String {
        guard !text.isEmpty else { return text }

        let tokens = tokenizeWithRanges(text, locale: locale)
        guard !tokens.isEmpty else { return text }

        var replacements: [(range: Range<String.Index>, replacement: String)] = []
        var index = 0

        while index < tokens.count {
            var matched: (length: Int, replacement: String, range: Range<String.Index>)?

            for rule in rules {
                let triggerTokens = Self.tokenizePhrase(rule.trigger)
                guard !triggerTokens.isEmpty else { continue }
                guard index + triggerTokens.count <= tokens.count else { continue }

                let candidate = tokens[index..<(index + triggerTokens.count)]
                if matches(candidateTokens: Array(candidate).map(\.token), triggerTokens: triggerTokens, rule: rule, locale: locale) {
                    let range = candidate.first!.range.lowerBound..<candidate.last!.range.upperBound
                    matched = (triggerTokens.count, rule.replacement, range)
                    break
                }
            }

            if let matched {
                replacements.append((range: matched.range, replacement: matched.replacement))
                index += matched.length
            } else {
                index += 1
            }
        }

        guard !replacements.isEmpty else { return text }

        var result = text
        for replacement in replacements.reversed() {
            result.replaceSubrange(replacement.range, with: replacement.replacement)
        }
        return result
    }

    public func consumeCommittedToken(_ token: String) -> [SnippetReplacementOp] {
        let normalized = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return [] }

        tokenWindow.append(normalized)
        if tokenWindow.count > maxWindowTokens {
            tokenWindow.removeFirst(tokenWindow.count - maxWindowTokens)
        }

        for rule in rules {
            let triggerTokens = Self.tokenizePhrase(rule.trigger)
            guard !triggerTokens.isEmpty else { continue }
            guard triggerTokens.count <= tokenWindow.count else { continue }

            let candidate = Array(tokenWindow.suffix(triggerTokens.count))
            if matches(candidateTokens: candidate, triggerTokens: triggerTokens, rule: rule, locale: Locale(identifier: rule.localeIdentifier ?? "en_US")) {
                tokenWindow.removeLast(triggerTokens.count)
                tokenWindow.append(rule.replacement)

                return [
                    SnippetReplacementOp(
                        replaceLastTokenCount: triggerTokens.count,
                        replacementText: rule.replacement,
                        ruleID: rule.id
                    )
                ]
            }
        }

        return []
    }

    private func matches(
        candidateTokens: [String],
        triggerTokens: [String],
        rule: SnippetRule,
        locale: Locale
    ) -> Bool {
        guard candidateTokens.count == triggerTokens.count else { return false }

        for index in candidateTokens.indices {
            let candidate = candidateTokens[index]
            let trigger = triggerTokens[index]

            if rule.caseSensitive {
                if candidate != trigger { return false }
            } else {
                if candidate.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: locale) != trigger.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: locale) {
                    return false
                }
            }
        }

        return true
    }

    private func tokenizeWithRanges(_ text: String, locale: Locale) -> [(token: String, range: Range<String.Index>)] {
        tokenizer.string = text
        tokenizer.setLanguage(NLLanguage(rawValue: locale.language.languageCode?.identifier ?? "en"))

        var results: [(String, Range<String.Index>)] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let token = String(text[range])
            results.append((token, range))
            return true
        }

        return results
    }

    private static func tokenizePhrase(_ phrase: String) -> [String] {
        phrase
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
            .filter { !$0.isEmpty }
    }
}
