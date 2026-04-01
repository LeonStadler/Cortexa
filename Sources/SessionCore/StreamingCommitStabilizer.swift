import Foundation

public struct StableCommitResult: Equatable, Sendable {
    public let committedPrefix: String
    public let tail: String

    public init(committedPrefix: String, tail: String) {
        self.committedPrefix = committedPrefix
        self.tail = tail
    }
}

public enum StreamingRewriteScope: String, CaseIterable, Identifiable, Sendable {
    case currentSentence
    case recentContext
    case wideContext
    case currentParagraph

    public var id: String { rawValue }
}

public final class StreamingCommitStabilizer {
    private let stabilityThreshold: Int
    private let minimumCommitExtensionLength: Int
    private let rewriteScope: StreamingRewriteScope
    private var previousPartial: String = ""
    private var repeatedCount = 0
    private var committedPrefix: String = ""

    public init(
        stabilityThreshold: Int = 2,
        minimumCommitExtensionLength: Int = 1,
        rewriteScope: StreamingRewriteScope = .recentContext
    ) {
        self.stabilityThreshold = max(1, stabilityThreshold)
        self.minimumCommitExtensionLength = max(1, minimumCommitExtensionLength)
        self.rewriteScope = rewriteScope
    }

    public func ingestPartial(_ partial: String) -> StableCommitResult {
        if partial == previousPartial {
            repeatedCount += 1
        } else {
            previousPartial = partial
            repeatedCount = 1
        }

        let common = longestCommonPrefix(committedPrefix, partial)
        if common.count >= committedPrefix.count {
            committedPrefix = common
        }

        if repeatedCount >= stabilityThreshold {
            let stablePrefix = stableCommitPrefix(for: partial)
            let scopedStablePrefix = scopedStablePrefix(for: partial, stablePrefix: stablePrefix)
            let extensionLength = scopedStablePrefix.count - committedPrefix.count
            let shouldCommit = extensionLength >= minimumCommitExtensionLength || endsWithStrongBoundary(stablePrefix)
            if scopedStablePrefix.count >= committedPrefix.count,
               shouldCommit,
               scopedStablePrefix.hasPrefix(committedPrefix) {
                committedPrefix = scopedStablePrefix
            }
        }

        let tail = String(partial.dropFirst(committedPrefix.count))
        return StableCommitResult(committedPrefix: committedPrefix, tail: tail)
    }

    public func reset() {
        previousPartial = ""
        repeatedCount = 0
        committedPrefix = ""
    }

    private func longestCommonPrefix(_ lhs: String, _ rhs: String) -> String {
        var result = ""
        var lhsIndex = lhs.startIndex
        var rhsIndex = rhs.startIndex

        while lhsIndex < lhs.endIndex, rhsIndex < rhs.endIndex, lhs[lhsIndex] == rhs[rhsIndex] {
            result.append(lhs[lhsIndex])
            lhs.formIndex(after: &lhsIndex)
            rhs.formIndex(after: &rhsIndex)
        }

        return result
    }

    private func stableCommitPrefix(for partial: String) -> String {
        guard !partial.isEmpty else { return "" }

        if let last = partial.last, isCommitBoundary(last) {
            return partial
        }

        guard let lastBoundary = partial.lastIndex(where: isCommitBoundary) else {
            return committedPrefix
        }

        let boundaryEnd = partial.index(after: lastBoundary)
        return String(partial[..<boundaryEnd])
    }

    private func scopedStablePrefix(for partial: String, stablePrefix: String) -> String {
        let preferredBoundaryCount: Int
        let maxMutableCharacters: Int

        switch rewriteScope {
        case .currentSentence:
            preferredBoundaryCount = 1
            maxMutableCharacters = 90
        case .recentContext:
            preferredBoundaryCount = 2
            maxMutableCharacters = 180
        case .wideContext:
            preferredBoundaryCount = 3
            maxMutableCharacters = 320
        case .currentParagraph:
            preferredBoundaryCount = 4
            maxMutableCharacters = 520
        }

        if !stablePrefix.isEmpty {
            if let boundaryLimitedPrefix = prefixDroppingLatestSentences(
                in: stablePrefix,
                keepingLastSentenceCountMutable: preferredBoundaryCount
            ) {
                return boundaryLimitedPrefix
            }

            if rewriteScope == .currentParagraph {
                return stablePrefix
            }
        }

        return prefixKeepingLastCharactersMutable(in: partial, maxMutableCharacters: maxMutableCharacters)
    }

    private func prefixDroppingLatestSentences(
        in text: String,
        keepingLastSentenceCountMutable sentenceCount: Int
    ) -> String? {
        guard sentenceCount > 0 else { return text }

        var boundaryEnds: [String.Index] = []
        var index = text.startIndex
        while index < text.endIndex {
            if isSentenceBoundary(text[index]) {
                var boundaryEnd = text.index(after: index)
                while boundaryEnd < text.endIndex, text[boundaryEnd].isWhitespace {
                    boundaryEnd = text.index(after: boundaryEnd)
                }
                boundaryEnds.append(boundaryEnd)
            }
            index = text.index(after: index)
        }

        guard boundaryEnds.count >= sentenceCount else { return nil }
        let cutoffIndex = boundaryEnds[boundaryEnds.count - sentenceCount]
        return String(text[..<cutoffIndex])
    }

    private func prefixKeepingLastCharactersMutable(in text: String, maxMutableCharacters: Int) -> String {
        guard maxMutableCharacters > 0 else {
            return ""
        }

        guard text.count > maxMutableCharacters else {
            return ""
        }

        let cutoffIndex = text.index(text.endIndex, offsetBy: -maxMutableCharacters)
        return String(text[..<cutoffIndex])
    }

    private func isSentenceBoundary(_ character: Character) -> Bool {
        ".?!\n".contains(character)
    }

    private func isCommitBoundary(_ character: Character) -> Bool {
        character.isWhitespace || ",.!?:;)]}\"'".contains(character)
    }

    private func endsWithStrongBoundary(_ text: String) -> Bool {
        guard let last = text.last else { return false }
        return ".!?:;)]}\"'".contains(last)
    }
}
