import CryptoKit
import Foundation

public struct LicenseCacheEntry: Codable, Equatable {
    public let licenseKey: String
    public let cachedAt: Date
    public let nonce: String
    public let integrityTag: String

    public init(licenseKey: String, cachedAt: Date, nonce: String, integrityTag: String) {
        self.licenseKey = licenseKey
        self.cachedAt = cachedAt
        self.nonce = nonce
        self.integrityTag = integrityTag
    }
}

public final class LicenseCache {
    private let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func write(licenseKey: String) throws {
        let nonce = UUID().uuidString
        let now = Date()
        let tag = integrityTag(licenseKey: licenseKey, nonce: nonce, timestamp: now)

        let entry = LicenseCacheEntry(licenseKey: licenseKey, cachedAt: now, nonce: nonce, integrityTag: tag)
        let data = try JSONEncoder().encode(entry)

        let parent = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        try data.write(to: fileURL, options: [.atomic])
    }

    public func clear() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return
        }

        try FileManager.default.removeItem(at: fileURL)
    }

    public func read() throws -> String? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let entry = try JSONDecoder().decode(LicenseCacheEntry.self, from: data)
            let expected = integrityTag(licenseKey: entry.licenseKey, nonce: entry.nonce, timestamp: entry.cachedAt)

            guard expected == entry.integrityTag else {
                quarantineCorruptedCache(reason: "integrity")
                return nil
            }

            return entry.licenseKey
        } catch {
            quarantineCorruptedCache(reason: "corrupt")
            return nil
        }
    }

    private func integrityTag(licenseKey: String, nonce: String, timestamp: Date) -> String {
        let source = "\(licenseKey)|\(nonce)|\(timestamp.timeIntervalSince1970)"
        let digest = SHA256.hash(data: Data(source.utf8))
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func quarantineCorruptedCache(reason: String) {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return
        }

        let parent = fileURL.deletingLastPathComponent()
        let timestamp = Int(Date().timeIntervalSince1970)
        let quarantineURL = parent.appendingPathComponent(
            "\(fileURL.lastPathComponent).corrupt-\(reason)-\(timestamp)-\(UUID().uuidString)"
        )

        do {
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: quarantineURL.path) {
                try FileManager.default.removeItem(at: quarantineURL)
            }
            try FileManager.default.moveItem(at: fileURL, to: quarantineURL)
        } catch {
            // Best-effort quarantine; callers still receive a safe nil result.
        }
    }
}
