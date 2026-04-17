import Foundation

enum AppShellStoragePaths {
    static func appSupportDirectory(
        fileManager: FileManager = .default,
        rootDirectory: URL? = nil
    ) -> URL {
        if let rootDirectory {
            return rootDirectory
        }

        let base =
            (try? fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ))
            ?? fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)

        return base.appendingPathComponent("WisprLocal", isDirectory: true)
    }

    static func snippetStorageURL(
        fileManager: FileManager = .default,
        rootDirectory: URL? = nil
    ) -> URL {
        appSupportDirectory(fileManager: fileManager, rootDirectory: rootDirectory)
            .appendingPathComponent("snippets.json", isDirectory: false)
    }

    static func historyStorageURL(
        fileManager: FileManager = .default,
        rootDirectory: URL? = nil
    ) -> URL {
        appSupportDirectory(fileManager: fileManager, rootDirectory: rootDirectory)
            .appendingPathComponent("transcript-history.json", isDirectory: false)
    }

    static func dictionaryStorageURL(
        fileManager: FileManager = .default,
        rootDirectory: URL? = nil
    ) -> URL {
        appSupportDirectory(fileManager: fileManager, rootDirectory: rootDirectory)
            .appendingPathComponent("personal-dictionary.json", isDirectory: false)
    }

    static func auditLogStorageURL(
        fileManager: FileManager = .default,
        rootDirectory: URL? = nil
    ) -> URL {
        appSupportDirectory(fileManager: fileManager, rootDirectory: rootDirectory)
            .appendingPathComponent("audit.log", isDirectory: false)
    }

    static func debugLogStorageURL(
        fileManager: FileManager = .default,
        rootDirectory: URL? = nil
    ) -> URL {
        appSupportDirectory(fileManager: fileManager, rootDirectory: rootDirectory)
            .appendingPathComponent("debug.log", isDirectory: false)
    }

    static func legacyLicenseCacheURL(
        fileManager: FileManager = .default,
        rootDirectory: URL? = nil
    ) -> URL {
        appSupportDirectory(fileManager: fileManager, rootDirectory: rootDirectory)
            .appendingPathComponent("license-cache.json", isDirectory: false)
    }
}

extension MacAppState {
    static func appSupportDirectory() -> URL {
        AppShellStoragePaths.appSupportDirectory()
    }
}
