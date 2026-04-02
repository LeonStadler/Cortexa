import Foundation

public enum SecurePersistence {
    public static func ensureDirectory(_ directoryURL: URL, fileManager: FileManager = .default) throws {
        if !fileManager.fileExists(atPath: directoryURL.path) {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }

        try hardenDirectory(at: directoryURL, fileManager: fileManager)
    }

    public static func ensureParentDirectory(for fileURL: URL, fileManager: FileManager = .default) throws {
        try ensureDirectory(fileURL.deletingLastPathComponent(), fileManager: fileManager)
    }

    public static func writeData(_ data: Data, to fileURL: URL, fileManager: FileManager = .default) throws {
        try ensureParentDirectory(for: fileURL, fileManager: fileManager)
        try data.write(to: fileURL, options: writingOptions)
        try hardenFile(at: fileURL, fileManager: fileManager)
    }

    public static func hardenFileIfPresent(at fileURL: URL, fileManager: FileManager = .default) throws {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return
        }

        try hardenFile(at: fileURL, fileManager: fileManager)
    }

    private static var writingOptions: Data.WritingOptions {
        #if os(iOS) || os(tvOS) || os(watchOS)
        return [.atomic, .completeFileProtection]
        #else
        return [.atomic]
        #endif
    }

    private static func hardenDirectory(at directoryURL: URL, fileManager: FileManager) throws {
        #if os(iOS) || os(tvOS) || os(watchOS)
        try fileManager.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: directoryURL.path
        )
        #else
        try fileManager.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: directoryURL.path
        )
        #endif
    }

    private static func hardenFile(at fileURL: URL, fileManager: FileManager) throws {
        #if os(iOS) || os(tvOS) || os(watchOS)
        try fileManager.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: fileURL.path
        )
        #else
        try fileManager.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: fileURL.path
        )
        #endif
    }
}
