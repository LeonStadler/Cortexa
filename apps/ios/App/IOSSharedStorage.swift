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

private struct VersionedSharedPayload<Payload: Codable>: Codable {
    let version: Int
    let payload: Payload

    init(payload: Payload, version: Int = 1) {
        self.version = version
        self.payload = payload
    }
}

struct IOSSharedStorage {
    static let appGroupIdentifier = "group.com.wisprlocal.shared"
    private static let currentSchemaVersion = 1
    private static let auditLogMaximumBytes = 256_000
    private static let auditLogBackupCount = 3

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
        try localApplicationSupportURL().appendingPathComponent("transcript-history.json", isDirectory: false)
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

    func localApplicationSupportURL() throws -> URL {
        guard let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw CocoaError(.fileNoSuchFile)
        }

        let appURL = baseURL.appendingPathComponent("WisprLocaliOS", isDirectory: true)
        try SecurePersistence.ensureDirectory(appURL, fileManager: fileManager)
        return appURL
    }

    func ensureSharedContainer() throws {
        let container = try sharedContainerURL()
        try SecurePersistence.ensureDirectory(container, fileManager: fileManager)
    }

    func loadSnippets() throws -> [SnippetRule] {
        try loadVersionedArray(from: snippetsURL())
    }

    func saveSnippets(_ rules: [SnippetRule]) throws {
        try saveVersionedArray(rules, to: snippetsURL())
    }

    func loadTranscriptHistory() throws -> [IOSTranscriptHistoryEntry] {
        try loadVersionedArray(from: transcriptHistoryURL())
    }

    func saveTranscriptHistory(_ entries: [IOSTranscriptHistoryEntry]) throws {
        try saveVersionedArray(entries, to: transcriptHistoryURL())
    }

    func loadKeyboardInsertionState() throws -> IOSKeyboardInsertionState? {
        try loadVersionedOptionalPayload(from: keyboardInsertionStateURL())
    }

    func saveKeyboardInsertionState(_ state: IOSKeyboardInsertionState) throws {
        try saveVersionedOptionalPayload(state, to: keyboardInsertionStateURL())
    }

    func clearKeyboardInsertionState() throws {
        let url = try keyboardInsertionStateURL()
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }

    func appendAudit(_ line: String) throws {
        let url = try auditLogURL()
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let output = "[\(timestamp)] \(line)\n"
        let outputData = Data(output.utf8)
        try ensureParentDirectory(for: url)

        let currentData = (try? coordinatedReadData(at: url)) ?? Data()
        if currentData.count + outputData.count > Self.auditLogMaximumBytes {
            try rotateAuditLog(at: url)
            try coordinatedWriteData(outputData, to: url)
            return
        }

        var combinedData = currentData
        combinedData.append(outputData)
        try coordinatedWriteData(combinedData, to: url)
    }

    private func loadVersionedArray<Item: Codable>(from url: URL) throws -> [Item] {
        guard fileManager.fileExists(atPath: url.path) else {
            return []
        }

        do {
            let data = try coordinatedReadData(at: url)
            return try decodeVersionedPayload(from: data)
        } catch {
            try quarantineCorruptItem(at: url, reason: error.localizedDescription)
            throw error
        }
    }

    private func saveVersionedArray<Item: Codable>(_ payload: [Item], to url: URL) throws {
        let data = try JSONEncoder().encode(VersionedSharedPayload(payload: payload, version: Self.currentSchemaVersion))
        try ensureParentDirectory(for: url)
        try coordinatedWriteData(data, to: url)
    }

    private func loadVersionedOptionalPayload<Payload: Codable>(from url: URL) throws -> Payload? {
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }

        do {
            let data = try coordinatedReadData(at: url)
            return try decodeVersionedPayload(from: data)
        } catch {
            try quarantineCorruptItem(at: url, reason: error.localizedDescription)
            throw error
        }
    }

    private func saveVersionedOptionalPayload<Payload: Codable>(_ payload: Payload, to url: URL) throws {
        let data = try JSONEncoder().encode(VersionedSharedPayload(payload: payload, version: Self.currentSchemaVersion))
        try ensureParentDirectory(for: url)
        try coordinatedWriteData(data, to: url)
    }

    private func decodeVersionedPayload<Payload: Codable>(from data: Data) throws -> Payload {
        if let envelope = try? JSONDecoder().decode(VersionedSharedPayload<Payload>.self, from: data) {
            guard envelope.version == Self.currentSchemaVersion else {
                throw CocoaError(.coderReadCorrupt)
            }
            return envelope.payload
        }

        return try JSONDecoder().decode(Payload.self, from: data)
    }

    private func coordinatedReadData(at url: URL) throws -> Data {
        try coordinate(reading: url) { readingURL in
            try Data(contentsOf: readingURL)
        }
    }

    private func coordinatedWriteData(_ data: Data, to url: URL) throws {
        try coordinate(writing: url) { writingURL in
            try SecurePersistence.writeData(data, to: writingURL, fileManager: fileManager)
        }
    }

    private func coordinate<T>(reading url: URL, _ action: (URL) throws -> T) throws -> T {
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        var result: Result<T, Error>?

        coordinator.coordinate(readingItemAt: url, options: [], error: &coordinationError) { coordinatedURL in
            do {
                result = .success(try action(coordinatedURL))
            } catch {
                result = .failure(error)
            }
        }

        if let coordinationError {
            throw coordinationError
        }

        switch result {
        case let .success(value):
            return value
        case let .failure(error):
            throw error
        case nil:
            throw CocoaError(.fileReadUnknown)
        }
    }

    private func coordinate<T>(writing url: URL, _ action: (URL) throws -> T) throws -> T {
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        var result: Result<T, Error>?

        coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &coordinationError) { coordinatedURL in
            do {
                result = .success(try action(coordinatedURL))
            } catch {
                result = .failure(error)
            }
        }

        if let coordinationError {
            throw coordinationError
        }

        switch result {
        case let .success(value):
            return value
        case let .failure(error):
            throw error
        case nil:
            throw CocoaError(.fileWriteUnknown)
        }
    }

    private func ensureParentDirectory(for url: URL) throws {
        try SecurePersistence.ensureParentDirectory(for: url, fileManager: fileManager)
    }

    private func quarantineCorruptItem(at url: URL, reason _: String) throws {
        guard fileManager.fileExists(atPath: url.path) else { return }

        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let quarantineName = "\(url.lastPathComponent).corrupt-\(timestamp)-\(UUID().uuidString)"
        let quarantineURL = url.deletingLastPathComponent().appendingPathComponent(quarantineName)
        do {
            try fileManager.moveItem(at: url, to: quarantineURL)
            try SecurePersistence.hardenFileIfPresent(at: quarantineURL, fileManager: fileManager)
        } catch {
            if fileManager.fileExists(atPath: url.path) {
                try? fileManager.removeItem(at: url)
            }
        }
    }

    private func rotateAuditLog(at url: URL) throws {
        let oldestBackupURL = rotatedAuditLogURL(baseURL: url, backupIndex: Self.auditLogBackupCount)
        if fileManager.fileExists(atPath: oldestBackupURL.path) {
            try fileManager.removeItem(at: oldestBackupURL)
        }

        if Self.auditLogBackupCount >= 2 {
            for index in stride(from: Self.auditLogBackupCount, to: 1, by: -1) {
                let sourceURL = rotatedAuditLogURL(baseURL: url, backupIndex: index - 1)
                let destinationURL = rotatedAuditLogURL(baseURL: url, backupIndex: index)
                guard fileManager.fileExists(atPath: sourceURL.path) else { continue }
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                }
                try fileManager.moveItem(at: sourceURL, to: destinationURL)
                try SecurePersistence.hardenFileIfPresent(at: destinationURL, fileManager: fileManager)
            }
        }

        guard fileManager.fileExists(atPath: url.path) else { return }
        let firstBackupURL = rotatedAuditLogURL(baseURL: url, backupIndex: 1)
        if fileManager.fileExists(atPath: firstBackupURL.path) {
            try fileManager.removeItem(at: firstBackupURL)
        }
        try fileManager.moveItem(at: url, to: firstBackupURL)
        try SecurePersistence.hardenFileIfPresent(at: firstBackupURL, fileManager: fileManager)
    }

    private func rotatedAuditLogURL(baseURL: URL, backupIndex: Int) -> URL {
        baseURL.deletingLastPathComponent().appendingPathComponent("\(baseURL.lastPathComponent).\(backupIndex)")
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
