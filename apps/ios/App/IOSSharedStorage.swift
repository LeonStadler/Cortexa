import Foundation
import SnippetCore

enum IOSSharedStorageError: LocalizedError {
    case missingSharedContainer(String)
    case missingSharedDefaults(String)

    var errorDescription: String? {
        switch self {
        case let .missingSharedContainer(identifier):
            return "Shared App Group container is unavailable for \(identifier)."
        case let .missingSharedDefaults(identifier):
            return "Shared App Group defaults are unavailable for \(identifier)."
        }
    }
}

struct IOSKeyboardInsertionState: Codable, Equatable {
    let text: String
    let languageCode: String
    let updatedAt: Date
}

struct IOSSharedStorage {
    static let appGroupIdentifier = "group.com.wisprlocal.shared"

    let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func sharedContainerURL() throws -> URL {
        guard let groupURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier) else {
            throw IOSSharedStorageError.missingSharedContainer(Self.appGroupIdentifier)
        }

        return groupURL
    }

    func snippetsURL() throws -> URL {
        try sharedContainerURL().appendingPathComponent("snippets.json", isDirectory: false)
    }

    func transcriptHistoryURL() throws -> URL {
        try sharedContainerURL().appendingPathComponent("transcript-history.json", isDirectory: false)
    }

    func keyboardInsertionStateURL() throws -> URL {
        try sharedContainerURL().appendingPathComponent("keyboard-insertion-state.json", isDirectory: false)
    }

    func auditLogURL() throws -> URL {
        try sharedContainerURL().appendingPathComponent("ios-audit.log", isDirectory: false)
    }

    func sharedDefaults() throws -> UserDefaults {
        guard let sharedDefaults = UserDefaults(suiteName: Self.appGroupIdentifier) else {
            throw IOSSharedStorageError.missingSharedDefaults(Self.appGroupIdentifier)
        }

        return sharedDefaults
    }

    func ensureSharedContainer() throws {
        let container = try sharedContainerURL()
        if !fileManager.fileExists(atPath: container.path) {
            try fileManager.createDirectory(at: container, withIntermediateDirectories: true)
        }
    }

    func loadSnippets() throws -> [SnippetRule] {
        let store = SnippetStore(fileURL: try snippetsURL(), fileManager: fileManager)
        return try store.load()
    }

    func saveSnippets(_ rules: [SnippetRule]) throws {
        let store = SnippetStore(fileURL: try snippetsURL(), fileManager: fileManager)
        try store.save(rules)
    }

    func loadTranscriptHistory() throws -> [IOSTranscriptHistoryEntry] {
        let url = try transcriptHistoryURL()
        guard fileManager.fileExists(atPath: url.path) else {
            return []
        }

        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([IOSTranscriptHistoryEntry].self, from: data)
    }

    func saveTranscriptHistory(_ entries: [IOSTranscriptHistoryEntry]) throws {
        let url = try transcriptHistoryURL()
        let parent = url.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: parent.path) {
            try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
        }
        let data = try JSONEncoder().encode(entries)
        try data.write(to: url, options: [.atomic])
    }

    func loadKeyboardInsertionState() throws -> IOSKeyboardInsertionState? {
        let url = try keyboardInsertionStateURL()
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }

        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(IOSKeyboardInsertionState.self, from: data)
    }

    func saveKeyboardInsertionState(_ state: IOSKeyboardInsertionState) throws {
        let url = try keyboardInsertionStateURL()
        let parent = url.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: parent.path) {
            try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
        }

        let data = try JSONEncoder().encode(state)
        try data.write(to: url, options: [.atomic])
    }

    func clearKeyboardInsertionState() throws {
        let url = try keyboardInsertionStateURL()
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }

    func appendAudit(_ line: String) throws {
        let url = try auditLogURL()
        let parent = url.deletingLastPathComponent()
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
