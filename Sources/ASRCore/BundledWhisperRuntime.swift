import Foundation

public struct InstalledWhisperRuntime: Sendable, Equatable {
    public let rootDirectoryURL: URL
    public let cliURL: URL
    public let modelsDirectoryURL: URL

    public init(rootDirectoryURL: URL, cliURL: URL, modelsDirectoryURL: URL) {
        self.rootDirectoryURL = rootDirectoryURL
        self.cliURL = cliURL
        self.modelsDirectoryURL = modelsDirectoryURL
    }
}

public enum BundledWhisperRuntimeError: Error, LocalizedError {
    case bundledRuntimeDirectoryMissing(String)
    case sourceCLIMissing(URL)
    case sourceModelsDirectoryMissing(URL)
    case noModelsFound(URL)

    public var errorDescription: String? {
        switch self {
        case let .bundledRuntimeDirectoryMissing(path):
            return "Bundled runtime directory not found at \(path)."
        case let .sourceCLIMissing(path):
            return "Bundled whisper-cli is missing at \(path.path)."
        case let .sourceModelsDirectoryMissing(path):
            return "Bundled model directory is missing at \(path.path)."
        case let .noModelsFound(path):
            return "No .bin models found in \(path.path)."
        }
    }
}

public enum BundledWhisperRuntimeInstaller {
    private static let runtimeSubdirectory = "Runtime"
    private static let modelsSubdirectory = "models"
    private static let cliName = "whisper-cli"

    public static func bundledRuntimeDirectory(in bundle: Bundle = .main, resourceSubdirectory: String = "Runtime") -> URL? {
        guard let resourceURL = bundle.resourceURL else { return nil }
        let nestedRuntimeURL = resourceURL.appendingPathComponent(resourceSubdirectory, isDirectory: true)

        if isValidRuntimeDirectory(nestedRuntimeURL, fileManager: .default) {
            return nestedRuntimeURL
        }

        // Xcode can flatten folder resources depending on how the target is configured.
        // Accept both `Resources/Runtime/...` and `Resources/...` layouts.
        if isValidRuntimeDirectory(resourceURL, fileManager: .default) {
            return resourceURL
        }

        return nil
    }

    public static func defaultInstallDirectory(appName: String = "WisprLocal", fileManager: FileManager = .default) throws -> URL {
        let appSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return appSupport
            .appendingPathComponent(appName, isDirectory: true)
            .appendingPathComponent("runtime", isDirectory: true)
    }

    public static func installBundledRuntime(
        bundle: Bundle = .main,
        resourceSubdirectory: String = "Runtime",
        appName: String = "WisprLocal",
        fileManager: FileManager = .default
    ) throws -> InstalledWhisperRuntime {
        guard let sourceRuntime = bundledRuntimeDirectory(in: bundle, resourceSubdirectory: resourceSubdirectory) else {
            let expected = (bundle.resourceURL ?? URL(fileURLWithPath: "<unknown>"))
                .appendingPathComponent(resourceSubdirectory)
                .path
            throw BundledWhisperRuntimeError.bundledRuntimeDirectoryMissing(expected)
        }

        return try installRuntime(from: sourceRuntime, destinationRuntimeDirectory: nil, appName: appName, fileManager: fileManager)
    }

    public static func installRuntime(
        from sourceRuntimeDirectory: URL,
        destinationRuntimeDirectory: URL? = nil,
        appName: String = "WisprLocal",
        fileManager: FileManager = .default
    ) throws -> InstalledWhisperRuntime {
        let sourceCLI = sourceRuntimeDirectory.appendingPathComponent(cliName)
        let sourceModels = sourceRuntimeDirectory.appendingPathComponent(modelsSubdirectory, isDirectory: true)

        guard fileManager.fileExists(atPath: sourceCLI.path) else {
            throw BundledWhisperRuntimeError.sourceCLIMissing(sourceCLI)
        }
        guard fileManager.fileExists(atPath: sourceModels.path) else {
            throw BundledWhisperRuntimeError.sourceModelsDirectoryMissing(sourceModels)
        }

        let modelFiles = try fileManager.contentsOfDirectory(at: sourceModels, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension.lowercased() == "bin" }

        guard !modelFiles.isEmpty else {
            throw BundledWhisperRuntimeError.noModelsFound(sourceModels)
        }

        let destinationRoot = try destinationRuntimeDirectory ?? defaultInstallDirectory(appName: appName, fileManager: fileManager)
        let destinationModels = destinationRoot.appendingPathComponent(modelsSubdirectory, isDirectory: true)
        let destinationCLI = destinationRoot.appendingPathComponent(cliName)

        try fileManager.createDirectory(at: destinationModels, withIntermediateDirectories: true)

        try copyIfChanged(from: sourceCLI, to: destinationCLI, fileManager: fileManager)
        try makeExecutable(destinationCLI, fileManager: fileManager)

        for modelFile in modelFiles {
            let target = destinationModels.appendingPathComponent(modelFile.lastPathComponent)
            try copyIfChanged(from: modelFile, to: target, fileManager: fileManager)
        }

        return InstalledWhisperRuntime(
            rootDirectoryURL: destinationRoot,
            cliURL: destinationCLI,
            modelsDirectoryURL: destinationModels
        )
    }

    private static func copyIfChanged(from source: URL, to destination: URL, fileManager: FileManager) throws {
        if fileManager.fileExists(atPath: destination.path) {
            let sourceAttributes = try fileManager.attributesOfItem(atPath: source.path)
            let destinationAttributes = try fileManager.attributesOfItem(atPath: destination.path)

            let sameSize = (sourceAttributes[.size] as? NSNumber) == (destinationAttributes[.size] as? NSNumber)
            let sameDate = (sourceAttributes[.modificationDate] as? Date) == (destinationAttributes[.modificationDate] as? Date)
            if sameSize && sameDate {
                return
            }

            try fileManager.removeItem(at: destination)
        }

        try fileManager.copyItem(at: source, to: destination)
    }

    private static func makeExecutable(_ fileURL: URL, fileManager: FileManager) throws {
        #if os(macOS)
        var attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
        let currentPermissions = (attributes[.posixPermissions] as? NSNumber)?.intValue ?? 0o644
        attributes[.posixPermissions] = NSNumber(value: currentPermissions | 0o111)
        try fileManager.setAttributes(attributes, ofItemAtPath: fileURL.path)
        #else
        _ = fileURL
        _ = fileManager
        #endif
    }

    private static func isValidRuntimeDirectory(_ directory: URL, fileManager: FileManager) -> Bool {
        let cliURL = directory.appendingPathComponent(cliName)
        let modelsURL = directory.appendingPathComponent(modelsSubdirectory, isDirectory: true)
        return fileManager.fileExists(atPath: cliURL.path) && fileManager.fileExists(atPath: modelsURL.path)
    }
}
