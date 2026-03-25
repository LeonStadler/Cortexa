import Foundation
import SnippetCore

struct IOSSharedStorage {
    static let appGroupIdentifier = "group.com.wisprlocal.shared"

    let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func sharedContainerURL() -> URL {
        if let groupURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier) {
            return groupURL
        }

        let base = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return base.appendingPathComponent("WisprLocalShared", isDirectory: true)
    }

    func snippetsURL() -> URL {
        sharedContainerURL().appendingPathComponent("snippets.json", isDirectory: false)
    }

    func transcriptHistoryURL() -> URL {
        sharedContainerURL().appendingPathComponent("transcript-history.json", isDirectory: false)
    }

    func auditLogURL() -> URL {
        sharedContainerURL().appendingPathComponent("ios-audit.log", isDirectory: false)
    }

    func sharedDefaults() -> UserDefaults {
        UserDefaults(suiteName: Self.appGroupIdentifier) ?? .standard
    }

    func ensureSharedContainer() throws {
        let container = sharedContainerURL()
        if !fileManager.fileExists(atPath: container.path) {
            try fileManager.createDirectory(at: container, withIntermediateDirectories: true)
        }
    }

    func loadSnippets() -> [SnippetRule] {
        let store = SnippetStore(fileURL: snippetsURL(), fileManager: fileManager)
        return (try? store.load()) ?? []
    }

    func saveSnippets(_ rules: [SnippetRule]) throws {
        let store = SnippetStore(fileURL: snippetsURL(), fileManager: fileManager)
        try store.save(rules)
    }

    func loadTranscriptHistory() -> [IOSTranscriptHistoryEntry] {
        let url = transcriptHistoryURL()
        guard fileManager.fileExists(atPath: url.path) else {
            return []
        }

        guard let data = try? Data(contentsOf: url) else {
            return []
        }

        return (try? JSONDecoder().decode([IOSTranscriptHistoryEntry].self, from: data)) ?? []
    }

    func loadLatestTranscriptEntry() -> IOSTranscriptHistoryEntry? {
        loadTranscriptHistory().first
    }

    func saveTranscriptHistory(_ entries: [IOSTranscriptHistoryEntry]) throws {
        let url = transcriptHistoryURL()
        let parent = url.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: parent.path) {
            try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
        }
        let data = try JSONEncoder().encode(entries)
        try data.write(to: url, options: [.atomic])
    }

    func appendAudit(_ line: String) {
        let url = auditLogURL()
        let parent = url.deletingLastPathComponent()
        do {
            if !fileManager.fileExists(atPath: parent.path) {
                try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
            }

            let timestamp = ISO8601DateFormatter().string(from: Date())
            let output = "[\(timestamp)] \(line)\n"
            if !fileManager.fileExists(atPath: url.path) {
                try Data(output.utf8).write(to: url, options: [.atomic])
                return
            }

            let handle = try FileHandle(forWritingTo: url)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: Data(output.utf8))
        } catch {
            return
        }
    }
}

struct IOSTranscriptHistoryEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let createdAt: Date
    let text: String
    let languageCode: String

    init(id: UUID = UUID(), createdAt: Date = Date(), text: String, languageCode: String) {
        self.id = id
        self.createdAt = createdAt
        self.text = text
        self.languageCode = languageCode
    }
}
