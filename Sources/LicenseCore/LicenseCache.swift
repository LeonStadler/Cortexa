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

    public func read() throws -> String? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: fileURL)
        let entry = try JSONDecoder().decode(LicenseCacheEntry.self, from: data)
        let expected = integrityTag(licenseKey: entry.licenseKey, nonce: entry.nonce, timestamp: entry.cachedAt)

        guard expected == entry.integrityTag else {
            return nil
        }

        return entry.licenseKey
    }

    private func integrityTag(licenseKey: String, nonce: String, timestamp: Date) -> String {
        let source = "\(licenseKey)|\(nonce)|\(timestamp.timeIntervalSince1970)"
        let digest = SHA256.hash(data: Data(source.utf8))
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}
