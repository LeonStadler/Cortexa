import Foundation

public struct SnippetRule: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public var trigger: String
    public var replacement: String
    public var caseSensitive: Bool
    public var localeIdentifier: String?

    public init(
        id: UUID = UUID(),
        trigger: String,
        replacement: String,
        caseSensitive: Bool = false,
        localeIdentifier: String? = nil
    ) {
        self.id = id
        self.trigger = trigger
        self.replacement = replacement
        self.caseSensitive = caseSensitive
        self.localeIdentifier = localeIdentifier
    }
}

public struct SnippetReplacementOp: Equatable, Sendable {
    public let replaceLastTokenCount: Int
    public let replacementText: String
    public let ruleID: UUID

    public init(replaceLastTokenCount: Int, replacementText: String, ruleID: UUID) {
        self.replaceLastTokenCount = replaceLastTokenCount
        self.replacementText = replacementText
        self.ruleID = ruleID
    }
}

public protocol SnippetMatcher {
    func applyToFinal(_ text: String, locale: Locale) -> String
    func consumeCommittedToken(_ token: String) -> [SnippetReplacementOp]
}
