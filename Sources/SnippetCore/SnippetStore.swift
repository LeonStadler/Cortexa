import Foundation

public final class SnippetStore {
    private let fileURL: URL
    private let fileManager: FileManager

    public init(fileURL: URL, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager
    }

    public func load() throws -> [SnippetRule] {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([SnippetRule].self, from: data)
    }

    public func save(_ rules: [SnippetRule]) throws {
        let parent = fileURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: parent.path) {
            try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
        }

        let data = try JSONEncoder().encode(rules)
        try data.write(to: fileURL, options: [.atomic])
    }

    public func importRules(from sourceURL: URL) throws -> [SnippetRule] {
        let data = try Data(contentsOf: sourceURL)
        let rules = try JSONDecoder().decode([SnippetRule].self, from: data)
        try save(rules)
        return rules
    }

    public func exportRules(_ rules: [SnippetRule], to destinationURL: URL) throws {
        let parent = destinationURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: parent.path) {
            try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
        }

        let data = try JSONEncoder().encode(rules)
        try data.write(to: destinationURL, options: [.atomic])
    }
}
