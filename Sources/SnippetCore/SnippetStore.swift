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

        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode([SnippetRule].self, from: data)
        } catch {
            quarantineCorruptedSnippets(reason: "corrupt")
            return []
        }
    }

    public func save(_ rules: [SnippetRule]) throws {
        let data = try JSONEncoder().encode(rules)
        try SecurePersistence.writeData(data, to: fileURL, fileManager: fileManager)
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

    private func quarantineCorruptedSnippets(reason: String) {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return
        }

        let parent = fileURL.deletingLastPathComponent()
        let timestamp = Int(Date().timeIntervalSince1970)
        let quarantineURL = parent.appendingPathComponent(
            "\(fileURL.lastPathComponent).corrupt-\(reason)-\(timestamp)-\(UUID().uuidString)"
        )

        do {
            try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
            if fileManager.fileExists(atPath: quarantineURL.path) {
                try fileManager.removeItem(at: quarantineURL)
            }
            try fileManager.moveItem(at: fileURL, to: quarantineURL)
            try SecurePersistence.hardenFileIfPresent(at: quarantineURL, fileManager: fileManager)
        } catch {
            // Best-effort quarantine only.
        }
    }
}
