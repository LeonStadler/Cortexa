import Foundation
import SnippetCore

protocol AuditLogging {
    var fileURL: URL { get }
    func append(_ line: String)
    func export(to destinationURL: URL) throws
}

final class AuditLogger: AuditLogging {
    private let maxSizeBytes = 2 * 1024 * 1024
    let fileURL: URL
    private let fileManager: FileManager

    init(fileURL: URL, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager
    }

    func append(_ line: String) {
        do {
            try rotateIfNeeded()

            let output = "[\(Self.timestampFormatter.string(from: Date()))] \(line)\n"
            let currentData = fileManager.fileExists(atPath: fileURL.path) ? (try Data(contentsOf: fileURL)) : Data()
            var combinedData = currentData
            combinedData.append(Data(output.utf8))
            try SecurePersistence.writeData(combinedData, to: fileURL, fileManager: fileManager)
        } catch {
            // Keep audit logging non-fatal.
        }
    }

    func export(to destinationURL: URL) throws {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw NSError(domain: "AuditLogger", code: 404, userInfo: [NSLocalizedDescriptionKey: "Audit log is empty"])
        }

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try fileManager.copyItem(at: fileURL, to: destinationURL)
    }

    private func rotateIfNeeded() throws {
        guard fileManager.fileExists(atPath: fileURL.path) else { return }

        let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
        let size = (attributes[.size] as? NSNumber)?.intValue ?? 0
        guard size >= maxSizeBytes else { return }

        let backupURL = fileURL.deletingPathExtension().appendingPathExtension("1.log")
        if fileManager.fileExists(atPath: backupURL.path) {
            try fileManager.removeItem(at: backupURL)
        }
        try fileManager.moveItem(at: fileURL, to: backupURL)
        try SecurePersistence.hardenFileIfPresent(at: backupURL, fileManager: fileManager)
    }

    private static let timestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        return formatter
    }()
}
