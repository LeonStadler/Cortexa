import Foundation

protocol TranscriptHistoryStoring {
    func load() throws -> [TranscriptHistoryEntry]
    func save(_ entries: [TranscriptHistoryEntry]) throws
    func exportText(entries: [TranscriptHistoryEntry], to destinationURL: URL) throws
}

struct TranscriptHistoryStore: TranscriptHistoryStoring {
    let fileURL: URL
    private let fileManager: FileManager

    init(fileURL: URL, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager
    }

    func load() throws -> [TranscriptHistoryEntry] {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([TranscriptHistoryEntry].self, from: data)
    }

    func save(_ entries: [TranscriptHistoryEntry]) throws {
        let parent = fileURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: parent.path) {
            try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
        }

        let data = try JSONEncoder().encode(entries)
        try data.write(to: fileURL, options: [.atomic])
    }

    func exportText(entries: [TranscriptHistoryEntry], to destinationURL: URL) throws {
        let output = entries
            .reversed()
            .map { "[\(Self.dateFormatter.string(from: $0.createdAt))] [\($0.mode)] [\($0.languageCode)] \($0.text)" }
            .joined(separator: "\n")
        try output.write(to: destinationURL, atomically: true, encoding: .utf8)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter
    }()
}
