import Foundation

public struct StableCommitResult: Equatable, Sendable {
    public let committedPrefix: String
    public let tail: String

    public init(committedPrefix: String, tail: String) {
        self.committedPrefix = committedPrefix
        self.tail = tail
    }
}

public final class StreamingCommitStabilizer {
    private let stabilityThreshold: Int
    private let minimumCommitExtensionLength: Int
    private var previousPartial: String = ""
    private var repeatedCount = 0
    private var committedPrefix: String = ""

    public init(stabilityThreshold: Int = 2, minimumCommitExtensionLength: Int = 1) {
        self.stabilityThreshold = max(1, stabilityThreshold)
        self.minimumCommitExtensionLength = max(1, minimumCommitExtensionLength)
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
            let extensionLength = stablePrefix.count - committedPrefix.count
            let shouldCommit = extensionLength >= minimumCommitExtensionLength || endsWithStrongBoundary(stablePrefix)
            if stablePrefix.count >= committedPrefix.count,
               shouldCommit,
               stablePrefix.hasPrefix(committedPrefix) {
                committedPrefix = stablePrefix
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

    private func isCommitBoundary(_ character: Character) -> Bool {
        character.isWhitespace || ",.!?:;)]}\"'".contains(character)
    }

    private func endsWithStrongBoundary(_ text: String) -> Bool {
        guard let last = text.last else { return false }
        return ".!?:;)]}\"'".contains(last)
    }
}
