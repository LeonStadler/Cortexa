import CryptoKit
import Foundation

public struct InstalledWhisperRuntime: Sendable, Equatable {
    public let rootDirectoryURL: URL
    public let cliURL: URL
    public let modelsDirectoryURL: URL
    public let availableModelFileNames: [String]
    public let defaultModelFileName: String
    public let manifest: BundledWhisperRuntimeManifest?

    public init(
        rootDirectoryURL: URL,
        cliURL: URL,
        modelsDirectoryURL: URL,
        availableModelFileNames: [String],
        defaultModelFileName: String,
        manifest: BundledWhisperRuntimeManifest?
    ) {
        self.rootDirectoryURL = rootDirectoryURL
        self.cliURL = cliURL
        self.modelsDirectoryURL = modelsDirectoryURL
        self.availableModelFileNames = availableModelFileNames
        self.defaultModelFileName = defaultModelFileName
        self.manifest = manifest
    }
}

public struct BundledWhisperRuntimeManifest: Sendable, Codable, Equatable {
    public let defaultModelFileName: String
    public let modelFileNames: [String]?
    public let cliChecksumSHA256: String?
    public let modelChecksumsSHA256: [String: String]?

    public init(
        defaultModelFileName: String,
        modelFileNames: [String]? = nil,
        cliChecksumSHA256: String? = nil,
        modelChecksumsSHA256: [String: String]? = nil
    ) {
        self.defaultModelFileName = defaultModelFileName
        self.modelFileNames = modelFileNames
        self.cliChecksumSHA256 = cliChecksumSHA256
        self.modelChecksumsSHA256 = modelChecksumsSHA256
    }
}

public enum BundledWhisperRuntimeError: Error, LocalizedError {
    case bundledRuntimeDirectoryMissing(String)
    case sourceCLIMissing(URL)
    case sourceModelsDirectoryMissing(URL)
    case noModelsFound(URL)
    case invalidManifest(URL)
    case manifestDefaultModelMissing(String, URL)
    case manifestModelFileNamesMismatch([String], [String], URL)
    case manifestChecksumMismatch(String, URL)

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
        case let .invalidManifest(path):
            return "Bundled runtime manifest is invalid at \(path.path)."
        case let .manifestDefaultModelMissing(modelFileName, modelsDirectory):
            return "Bundled runtime manifest default model \(modelFileName) does not exist in \(modelsDirectory.path)."
        case let .manifestModelFileNamesMismatch(expected, actual, modelsDirectory):
            return "Bundled runtime manifest model list \(expected) does not match available models \(actual) in \(modelsDirectory.path)."
        case let .manifestChecksumMismatch(artifactName, manifestURL):
            return "Bundled runtime manifest checksum for \(artifactName) did not match at \(manifestURL.path)."
        }
    }
}

public enum BundledWhisperRuntimeInstaller {
    private static let runtimeSubdirectory = "Runtime"
    private static let modelsSubdirectory = "models"
    private static let cliName = "whisper-cli"
    private static let manifestFileName = "runtime-manifest.json"

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
        preserveAdditionalModels: Bool = true,
        fileManager: FileManager = .default
    ) throws -> InstalledWhisperRuntime {
        guard let sourceRuntime = bundledRuntimeDirectory(in: bundle, resourceSubdirectory: resourceSubdirectory) else {
            let expected = (bundle.resourceURL ?? URL(fileURLWithPath: "<unknown>"))
                .appendingPathComponent(resourceSubdirectory)
                .path
            throw BundledWhisperRuntimeError.bundledRuntimeDirectoryMissing(expected)
        }

        return try installRuntime(
            from: sourceRuntime,
            destinationRuntimeDirectory: nil,
            appName: appName,
            preserveAdditionalModels: preserveAdditionalModels,
            fileManager: fileManager
        )
    }

    public static func installRuntime(
        from sourceRuntimeDirectory: URL,
        destinationRuntimeDirectory: URL? = nil,
        appName: String = "WisprLocal",
        preserveAdditionalModels: Bool = false,
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

        let availableModelFileNames = modelFiles
            .map(\.lastPathComponent)
            .sorted()
        let manifest = try loadManifest(in: sourceRuntimeDirectory, fileManager: fileManager)
        let defaultModelFileName = try resolveDefaultModelFileName(
            manifest: manifest,
            availableModelFileNames: availableModelFileNames,
            sourceModelsDirectory: sourceModels
        )
        try validateManifestIntegrity(
            manifest: manifest,
            availableModelFileNames: availableModelFileNames,
            sourceCLI: sourceCLI,
            sourceModelsDirectory: sourceModels,
            sourceRuntimeDirectory: sourceRuntimeDirectory,
            modelFiles: modelFiles
        )

        let destinationRoot = try destinationRuntimeDirectory ?? defaultInstallDirectory(appName: appName, fileManager: fileManager)
        let destinationModels = destinationRoot.appendingPathComponent(modelsSubdirectory, isDirectory: true)
        let destinationCLI = destinationRoot.appendingPathComponent(cliName)
        let destinationManifest = destinationRoot.appendingPathComponent(manifestFileName)

        try fileManager.createDirectory(at: destinationModels, withIntermediateDirectories: true)
        try pruneStaleRuntimeAssets(
            destinationRoot: destinationRoot,
            destinationModels: destinationModels,
            expectedModelFileNames: Set(availableModelFileNames),
            preserveAdditionalModels: preserveAdditionalModels,
            fileManager: fileManager
        )

        try copyIfChanged(from: sourceCLI, to: destinationCLI, fileManager: fileManager)
        try makeExecutable(destinationCLI, fileManager: fileManager)

        for modelFile in modelFiles {
            let target = destinationModels.appendingPathComponent(modelFile.lastPathComponent)
            try copyIfChanged(from: modelFile, to: target, fileManager: fileManager)
        }

        try syncManifest(
            manifest: manifest,
            sourceRuntimeDirectory: sourceRuntimeDirectory,
            destinationManifest: destinationManifest,
            fileManager: fileManager
        )

        let installedModelFiles = try fileManager.contentsOfDirectory(at: destinationModels, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension.lowercased() == "bin" }
            .map(\.lastPathComponent)
            .sorted()

        return InstalledWhisperRuntime(
            rootDirectoryURL: destinationRoot,
            cliURL: destinationCLI,
            modelsDirectoryURL: destinationModels,
            availableModelFileNames: installedModelFiles,
            defaultModelFileName: defaultModelFileName,
            manifest: manifest
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

    private static func loadManifest(in runtimeDirectory: URL, fileManager: FileManager) throws -> BundledWhisperRuntimeManifest? {
        let manifestURL = runtimeDirectory.appendingPathComponent(manifestFileName)
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: manifestURL)
            return try JSONDecoder().decode(BundledWhisperRuntimeManifest.self, from: data)
        } catch {
            throw BundledWhisperRuntimeError.invalidManifest(manifestURL)
        }
    }

    private static func resolveDefaultModelFileName(
        manifest: BundledWhisperRuntimeManifest?,
        availableModelFileNames: [String],
        sourceModelsDirectory: URL
    ) throws -> String {
        if let manifest {
            guard availableModelFileNames.contains(manifest.defaultModelFileName) else {
                throw BundledWhisperRuntimeError.manifestDefaultModelMissing(manifest.defaultModelFileName, sourceModelsDirectory)
            }
            return manifest.defaultModelFileName
        }

        return availableModelFileNames[0]
    }

    private static func validateManifestIntegrity(
        manifest: BundledWhisperRuntimeManifest?,
        availableModelFileNames: [String],
        sourceCLI: URL,
        sourceModelsDirectory: URL,
        sourceRuntimeDirectory: URL,
        modelFiles: [URL]
    ) throws {
        guard let manifest else {
            return
        }

        if let declaredModelFileNames = manifest.modelFileNames {
            let declared = declaredModelFileNames.sorted()
            let available = availableModelFileNames.sorted()
            guard declared == available else {
                throw BundledWhisperRuntimeError.manifestModelFileNamesMismatch(declared, available, sourceModelsDirectory)
            }
        }

        if let cliChecksumSHA256 = manifest.cliChecksumSHA256 {
            try validateChecksum(
                of: sourceCLI,
                expectedSHA256: cliChecksumSHA256,
                artifactName: sourceCLI.lastPathComponent,
                artifactURL: sourceCLI
            )
        }

        if let modelChecksumsSHA256 = manifest.modelChecksumsSHA256 {
            let availableModels = Set(availableModelFileNames)
            guard Set(modelChecksumsSHA256.keys) == availableModels else {
                throw BundledWhisperRuntimeError.manifestChecksumMismatch("model checksum keys", sourceRuntimeDirectory)
            }

            for modelFile in modelFiles {
                guard let expectedChecksum = modelChecksumsSHA256[modelFile.lastPathComponent] else {
                    throw BundledWhisperRuntimeError.manifestChecksumMismatch(modelFile.lastPathComponent, sourceModelsDirectory)
                }
                try validateChecksum(
                    of: modelFile,
                    expectedSHA256: expectedChecksum,
                    artifactName: modelFile.lastPathComponent,
                    artifactURL: modelFile
                )
            }
        }
    }

    private static func validateChecksum(
        of fileURL: URL,
        expectedSHA256: String,
        artifactName: String,
        artifactURL: URL
    ) throws {
        let data = try Data(contentsOf: fileURL)
        let actualChecksum = sha256Hex(of: data)
        guard actualChecksum.caseInsensitiveCompare(expectedSHA256) == .orderedSame else {
            throw BundledWhisperRuntimeError.manifestChecksumMismatch(artifactName, artifactURL)
        }
    }

    private static func sha256Hex(of data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func pruneStaleRuntimeAssets(
        destinationRoot: URL,
        destinationModels: URL,
        expectedModelFileNames: Set<String>,
        preserveAdditionalModels: Bool,
        fileManager: FileManager
    ) throws {
        if fileManager.fileExists(atPath: destinationModels.path), !preserveAdditionalModels {
            let existingModelFiles = try fileManager.contentsOfDirectory(at: destinationModels, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension.lowercased() == "bin" }

            for existingModelFile in existingModelFiles where !expectedModelFileNames.contains(existingModelFile.lastPathComponent) {
                try fileManager.removeItem(at: existingModelFile)
            }
        }

        let destinationManifest = destinationRoot.appendingPathComponent(manifestFileName)
        if fileManager.fileExists(atPath: destinationManifest.path), !preserveAdditionalModels {
            try fileManager.removeItem(at: destinationManifest)
        }
    }

    private static func syncManifest(
        manifest: BundledWhisperRuntimeManifest?,
        sourceRuntimeDirectory: URL,
        destinationManifest: URL,
        fileManager: FileManager
    ) throws {
        let sourceManifest = sourceRuntimeDirectory.appendingPathComponent(manifestFileName)

        guard manifest != nil else {
            return
        }

        try copyIfChanged(from: sourceManifest, to: destinationManifest, fileManager: fileManager)
    }

    private static func isValidRuntimeDirectory(_ directory: URL, fileManager: FileManager) -> Bool {
        let cliURL = directory.appendingPathComponent(cliName)
        let modelsURL = directory.appendingPathComponent(modelsSubdirectory, isDirectory: true)
        return fileManager.fileExists(atPath: cliURL.path) && fileManager.fileExists(atPath: modelsURL.path)
    }
}
