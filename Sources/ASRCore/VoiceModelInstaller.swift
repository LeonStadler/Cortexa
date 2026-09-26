import Foundation
import CryptoKit

public enum VoiceModelInstallerError: Error, LocalizedError {
    case unsupportedProvider(String)
    case modelNotDownloadable(String)
    case missingDownloadURL(String)
    case missingLocalFileName(String)
    case removalWouldLeaveNoDefaultModel
    case downloadFailed(String)
    case runtimeInstallFailed(String)
    case runtimeCleanupFailed(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedProvider(let providerID):
            return "Voice provider \(providerID) is not supported for local installation."
        case .modelNotDownloadable(let modelID):
            return "Voice model \(modelID) cannot be downloaded."
        case .missingDownloadURL(let modelID):
            return "Voice model \(modelID) has no download URL."
        case .missingLocalFileName(let modelID):
            return "Voice model \(modelID) has no local file mapping."
        case .removalWouldLeaveNoDefaultModel:
            return "The default bundled model must remain installed."
        case .downloadFailed(let modelID):
            return "The NVIDIA model download for \(modelID) did not produce a usable GGUF file."
        case .runtimeInstallFailed(let reason):
            return "The Cortexa-managed NVIDIA NeMo-Speech runtime could not be installed: \(reason)"
        case .runtimeCleanupFailed(let reason):
            return "The Cortexa-managed NVIDIA NeMo-Speech runtime could not be removed: \(reason)"
        }
    }
}

enum VoiceModelDownloadWorkspace {
    static let temporaryDirectoryPrefix = "cortexa-voice-model-download-"
    static let legacyTemporaryDirectoryPrefix = "voice-model-download-"
    static let partialFilePrefix = ".cortexa-model-download-"
    static let partialFileSuffix = ".partial"

    static func makeTemporaryDirectory(fileManager: FileManager) throws -> URL {
        let directory = fileManager.temporaryDirectory.appendingPathComponent(
            temporaryDirectoryPrefix + UUID().uuidString,
            isDirectory: true
        )
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func removeInterruptedArtifacts(
        in modelsDirectoryURL: URL,
        temporaryDirectoryURL: URL,
        fileManager: FileManager
    ) throws {
        let temporaryDirectoryEntries = try fileManager.contentsOfDirectory(
            at: temporaryDirectoryURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        for entry in temporaryDirectoryEntries where isInterruptedTemporaryDirectory(
            entry,
            fileManager: fileManager
        ) {
            try fileManager.removeItem(at: entry)
        }

        guard fileManager.fileExists(atPath: modelsDirectoryURL.path) else { return }
        let modelEntries = try fileManager.contentsOfDirectory(
            at: modelsDirectoryURL,
            includingPropertiesForKeys: nil,
            options: []
        )
        for entry in modelEntries where isPartialModelFile(entry) {
            try fileManager.removeItem(at: entry)
        }
    }

    static func installDownloadedModel(
        from downloadedModelURL: URL,
        named localFileName: String,
        in modelsDirectoryURL: URL,
        fileManager: FileManager
    ) throws {
        let targetURL = modelsDirectoryURL.appendingPathComponent(localFileName)
        let stagingURL = modelsDirectoryURL.appendingPathComponent(
            partialFilePrefix + localFileName + partialFileSuffix
        )
        if fileManager.fileExists(atPath: stagingURL.path) {
            try fileManager.removeItem(at: stagingURL)
        }
        do {
            try fileManager.copyItem(at: downloadedModelURL, to: stagingURL)
            if fileManager.fileExists(atPath: targetURL.path) {
                _ = try fileManager.replaceItemAt(
                    targetURL,
                    withItemAt: stagingURL,
                    backupItemName: nil,
                    options: []
                )
            } else {
                try fileManager.moveItem(at: stagingURL, to: targetURL)
            }
        } catch {
            if fileManager.fileExists(atPath: stagingURL.path) {
                try? fileManager.removeItem(at: stagingURL)
            }
            throw error
        }
    }

    private static func isInterruptedTemporaryDirectory(
        _ url: URL,
        fileManager: FileManager
    ) -> Bool {
        let name = url.lastPathComponent
        guard name.hasPrefix(temporaryDirectoryPrefix)
            || name.hasPrefix(legacyTemporaryDirectoryPrefix)
        else {
            return false
        }
        var isDirectory = ObjCBool(false)
        return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)
            && isDirectory.boolValue
    }

    private static func isPartialModelFile(_ url: URL) -> Bool {
        let name = url.lastPathComponent
        return name.hasPrefix(partialFilePrefix) && name.hasSuffix(partialFileSuffix)
    }
}

public actor VoiceModelInstaller {
    private let fileManager: FileManager
    private let suppressionStore: VoiceModelSuppressionStore

    public init(
        fileManager: FileManager = .default,
        suppressionStore: VoiceModelSuppressionStore = .shared
    ) {
        self.fileManager = fileManager
        self.suppressionStore = suppressionStore
    }

    public func nemoRuntimeStatus() -> NemoSpeechRuntimeStatus {
        NemoSpeechRuntimeManager.status(fileManager: fileManager)
    }

    public func installNemoRuntime(
        progressHandler: (@Sendable (VoiceModelInstallProgress) -> Void)? = nil
    ) async throws -> URL {
        try await NemoSpeechRuntimeManager.install(fileManager: fileManager, progressHandler: progressHandler)
    }

    public func cleanupUnusedNemoRuntime() throws {
        try NemoSpeechRuntimeManager.removeManagedRuntimeIfUnused(fileManager: fileManager)
    }

    public func installedRuntime(appName: String = "WisprLocal") throws -> InstalledWhisperRuntime {
        try syncRuntimeCLI(appName: appName)
    }

    public func syncRuntimeCLI(appName: String = "WisprLocal") throws -> InstalledWhisperRuntime {
        let runtime = try BundledWhisperRuntimeInstaller.installBundledRuntime(
            appName: appName,
            syncModels: false,
            suppressedBundledModelFileNames: suppressionStore.suppressedFileNames()
        )
        try VoiceModelDownloadWorkspace.removeInterruptedArtifacts(
            in: runtime.modelsDirectoryURL,
            temporaryDirectoryURL: fileManager.temporaryDirectory,
            fileManager: fileManager
        )
        return runtime
    }

    public func installedWhisperModelFileNames(appName: String = "WisprLocal") throws -> Set<String>
    {
        let runtime = try syncRuntimeCLI(appName: appName)
        return Set(runtime.availableModelFileNames)
    }

    public func install(
        _ descriptor: VoiceModelDescriptor,
        appName: String = "WisprLocal",
        progressHandler: (@Sendable (VoiceModelInstallProgress) -> Void)? = nil
    ) async throws -> InstalledWhisperRuntime {
        if descriptor.providerID == VoiceProviderID.nvidiaParakeet.rawValue {
            return try await installParakeet(descriptor, progressHandler: progressHandler)
        }
        guard descriptor.providerID == VoiceProviderID.whisperCpp.rawValue else {
            throw VoiceModelInstallerError.unsupportedProvider(descriptor.providerID)
        }
        guard descriptor.installState != .unavailable else {
            throw VoiceModelInstallerError.modelNotDownloadable(descriptor.id)
        }
        guard let localFileName = descriptor.localFileName else {
            throw VoiceModelInstallerError.missingLocalFileName(descriptor.id)
        }
        guard let downloadIdentifier = descriptor.downloadIdentifier else {
            throw VoiceModelInstallerError.missingDownloadURL(descriptor.id)
        }

        suppressionStore.clearSuppression(for: localFileName)

        progressHandler?(
            VoiceModelInstallProgress(phase: .preparing, fractionCompleted: 0)
        )

        let runtime = try installedRuntime(appName: appName)
        if runtime.availableModelFileNames.contains(localFileName) {
            progressHandler?(
                VoiceModelInstallProgress(phase: .finalizing, fractionCompleted: 1)
            )
            return runtime
        }

        let downloadURL = URL(
            string:
                "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-\(downloadIdentifier).bin"
        )!
        let tempDirectory = try VoiceModelDownloadWorkspace.makeTemporaryDirectory(
            fileManager: fileManager
        )
        defer { try? fileManager.removeItem(at: tempDirectory) }

        let destinationURL = tempDirectory.appendingPathComponent(localFileName)
        let downloadClient = VoiceModelDownloadClient(fileManager: fileManager)
        try await downloadClient.download(
            from: downloadURL,
            to: destinationURL,
            expectedDownloadBytes: descriptor.expectedDownloadBytes
        ) { progress in
            progressHandler?(progress)
        }
        try Task.checkCancellation()

        progressHandler?(
            VoiceModelInstallProgress(phase: .finalizing, fractionCompleted: 0.99)
        )

        try VoiceModelDownloadWorkspace.installDownloadedModel(
            from: destinationURL,
            named: localFileName,
            in: runtime.modelsDirectoryURL,
            fileManager: fileManager
        )

        progressHandler?(
            VoiceModelInstallProgress(phase: .finalizing, fractionCompleted: 1)
        )

        return try installedRuntime(appName: appName)
    }

    public func installedParakeetModelFileNames() throws -> Set<String> {
        let directory = try parakeetModelsDirectory()
        guard fileManager.fileExists(atPath: directory.path) else { return [] }
        let entries = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        return Set(entries.filter { $0.pathExtension == "gguf" }.map { $0.lastPathComponent })
    }

    public static func parakeetModelURL(fileName: String) throws -> URL {
        let cache = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return cache.appendingPathComponent("NeMoSpeech/models", isDirectory: true)
            .appendingPathComponent(fileName)
    }

    public func removeParakeet(_ descriptor: VoiceModelDescriptor) throws {
        guard descriptor.providerID == VoiceProviderID.nvidiaParakeet.rawValue,
            let localFileName = descriptor.localFileName
        else { throw VoiceModelInstallerError.unsupportedProvider(descriptor.providerID) }
        NemoRuntimeAccess.lock.lock(); defer { NemoRuntimeAccess.lock.unlock() }
        let target = try parakeetModelsDirectory().appendingPathComponent(localFileName)
        if fileManager.fileExists(atPath: target.path) { try fileManager.removeItem(at: target) }
        do {
            try NemoSpeechRuntimeManager.removeManagedRuntimeIfUnused(fileManager: fileManager)
        } catch {
            throw VoiceModelInstallerError.runtimeCleanupFailed(error.localizedDescription)
        }
    }

    private func installParakeet(
        _ descriptor: VoiceModelDescriptor,
        progressHandler: (@Sendable (VoiceModelInstallProgress) -> Void)?
    ) async throws -> InstalledWhisperRuntime {
        guard descriptor.installState != .unavailable else {
            throw VoiceModelInstallerError.modelNotDownloadable(descriptor.id)
        }
        guard let localFileName = descriptor.localFileName else {
            throw VoiceModelInstallerError.missingLocalFileName(descriptor.id)
        }
        let hadCompatibleRuntime = NemoSpeechRuntimeManager.status(fileManager: fileManager).isAvailable
        if !hadCompatibleRuntime {
            progressHandler?(VoiceModelInstallProgress(phase: .installingRuntime, fractionCompleted: 0))
            _ = try await NemoSpeechRuntimeManager.install(fileManager: fileManager, progressHandler: progressHandler)
        }
        progressHandler?(VoiceModelInstallProgress(phase: .preparing, fractionCompleted: 0))
        let modelDirectory = try parakeetModelsDirectory()
        if try installedParakeetModelFileNames().contains(localFileName) {
            progressHandler?(VoiceModelInstallProgress(phase: .finalizing, fractionCompleted: 1))
            return try installedRuntime()
        }
        let sourceURL = URL(string: "https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3/resolve/main/\(localFileName)")!
        let temporaryDirectory = try VoiceModelDownloadWorkspace.makeTemporaryDirectory(fileManager: fileManager)
        defer { try? fileManager.removeItem(at: temporaryDirectory) }
        let downloadedURL = temporaryDirectory.appendingPathComponent(localFileName)
        let downloadClient = VoiceModelDownloadClient(fileManager: fileManager)
        do {
            try await downloadClient.download(from: sourceURL, to: downloadedURL, expectedDownloadBytes: descriptor.expectedDownloadBytes) { progress in
                progressHandler?(progress)
            }
            try Task.checkCancellation()
            let header = try Data(contentsOf: downloadedURL, options: .mappedIfSafe).prefix(4)
            guard header.elementsEqual([0x47, 0x47, 0x55, 0x46]) else {
                throw VoiceModelInstallerError.downloadFailed(descriptor.id)
            }
            try VoiceModelDownloadWorkspace.installDownloadedModel(
                from: downloadedURL,
                named: localFileName,
                in: modelDirectory,
                fileManager: fileManager
            )
        } catch {
            if !hadCompatibleRuntime, try installedParakeetModelFileNames().isEmpty {
                do {
                    try NemoSpeechRuntimeManager.removeManagedRuntimeIfUnused(fileManager: fileManager)
                } catch let cleanupError {
                    throw VoiceModelInstallerError.runtimeInstallFailed(
                        "Model download failed (\(error.localizedDescription)); newly installed runtime cleanup also failed (\(cleanupError.localizedDescription))."
                    )
                }
            }
            throw error
        }
        progressHandler?(VoiceModelInstallProgress(phase: .finalizing, fractionCompleted: 1))
        return try installedRuntime()
    }

    private func parakeetModelsDirectory() throws -> URL {
        let cache = try fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let directory = cache.appendingPathComponent("NeMoSpeech/models", isDirectory: true)
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    public static func resolveNemoSpeechCLI() -> URL? {
        NemoSpeechRuntimeManager.status(fileManager: .default).cliURL
    }

    public static func nemoRuntimeStatusSnapshot() -> NemoSpeechRuntimeStatus {
        NemoSpeechRuntimeManager.status(fileManager: .default)
    }

    public func remove(_ descriptor: VoiceModelDescriptor, appName: String = "WisprLocal") throws
        -> InstalledWhisperRuntime
    {
        if descriptor.providerID == VoiceProviderID.nvidiaParakeet.rawValue {
            try removeParakeet(descriptor)
            return try installedRuntime(appName: appName)
        }
        guard descriptor.providerID == VoiceProviderID.whisperCpp.rawValue else {
            throw VoiceModelInstallerError.unsupportedProvider(descriptor.providerID)
        }
        guard let localFileName = descriptor.localFileName else {
            throw VoiceModelInstallerError.missingLocalFileName(descriptor.id)
        }

        let runtime = try installedRuntime(appName: appName)
        if localFileName == runtime.defaultModelFileName {
            throw VoiceModelInstallerError.removalWouldLeaveNoDefaultModel
        }

        let targetURL = runtime.modelsDirectoryURL.appendingPathComponent(localFileName)
        if fileManager.fileExists(atPath: targetURL.path) {
            try fileManager.removeItem(at: targetURL)
        }

        if descriptor.installState != .bundled && descriptor.installState != .requiredFirstRun {
            suppressionStore.suppress(localFileName)
        }

        let remaining = try fileManager.contentsOfDirectory(
            at: runtime.modelsDirectoryURL, includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension.lowercased() == "bin" }
        .map(\.lastPathComponent)
        .sorted()

        return InstalledWhisperRuntime(
            rootDirectoryURL: runtime.rootDirectoryURL,
            cliURL: runtime.cliURL,
            modelsDirectoryURL: runtime.modelsDirectoryURL,
            availableModelFileNames: remaining,
            defaultModelFileName: runtime.defaultModelFileName,
            manifest: runtime.manifest
        )
    }
}

public struct NemoSpeechRuntimeStatus: Sendable, Equatable {
    public let cliURL: URL?
    public let version: String?
    public let isManaged: Bool
    public let diagnostic: String?
    public var isAvailable: Bool { cliURL != nil }
}

enum NemoRuntimeAccess {
    static let lock = NSRecursiveLock()
}

enum NemoSpeechRuntimeManager {
    static let version = "0.1.0"
    static let expectedSHA256 = "f1dff4f9dd9c96214f8cb78b982812459132df8a4ad1a42409fd94de4a366244"
    static let archiveURL = URL(string: "https://github.com/NVIDIA/NeMo-Speech.cpp/releases/download/v0.1.0/nemo-speech-0.1.0-macos-aarch64-metal.tar.gz")!

    private struct Manifest: Codable {
        let managedBy: String
        let runtimeID: String
        let version: String
        let archiveSHA256: String
        let binaryRelativePath: String
    }

    static func status(fileManager: FileManager) -> NemoSpeechRuntimeStatus {
        let managed = managedDirectory(fileManager: fileManager)
        if let cli = validatedManagedCLI(in: managed, fileManager: fileManager), runtimeVersion(cli) == version {
            return NemoSpeechRuntimeStatus(cliURL: cli, version: version, isManaged: true, diagnostic: nil)
        }
        var incompatibleRuntime: (URL, String)?
        for candidate in externalCandidates() {
            guard fileManager.isExecutableFile(atPath: candidate.path), let foundVersion = runtimeVersion(candidate) else { continue }
            guard foundVersion == version else {
                incompatibleRuntime = (candidate, foundVersion)
                continue
            }
            return NemoSpeechRuntimeStatus(cliURL: candidate, version: foundVersion, isManaged: false, diagnostic: nil)
        }
        let diagnostic: String
        if let (url, foundVersion) = incompatibleRuntime {
            diagnostic = "Found NeMo-Speech \(foundVersion) at \(url.path); Cortexa supports \(version) and will leave the external runtime unchanged."
        } else {
            diagnostic = "NeMo-Speech \(version) runtime not found; supported managed download: macOS Apple Silicon Metal."
        }
        return NemoSpeechRuntimeStatus(cliURL: nil, version: nil, isManaged: false, diagnostic: diagnostic)
    }

    static func install(fileManager: FileManager, progressHandler: (@Sendable (VoiceModelInstallProgress) -> Void)?) async throws -> URL {
        if let cli = status(fileManager: fileManager).cliURL { return cli }
        guard ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 14, isAppleSilicon else {
            throw VoiceModelInstallerError.runtimeInstallFailed("No validated NeMo-Speech release is available for this platform.")
        }
        progressHandler?(VoiceModelInstallProgress(phase: .installingRuntime, fractionCompleted: 0.05))
        let downloadDirectory = try VoiceModelDownloadWorkspace.makeTemporaryDirectory(fileManager: fileManager)
        defer { try? fileManager.removeItem(at: downloadDirectory) }
        let archive = downloadDirectory.appendingPathComponent("nemo-speech.tar.gz")
        let client = VoiceModelDownloadClient(fileManager: fileManager)
        try await client.download(from: archiveURL, to: archive, expectedDownloadBytes: nil) { progress in
            progressHandler?(VoiceModelInstallProgress(phase: .installingRuntime, fractionCompleted: progress.fractionCompleted * 0.65, receivedBytes: progress.receivedBytes, totalBytes: progress.totalBytes, isIndeterminate: progress.isIndeterminate))
        }
        try Task.checkCancellation()
        progressHandler?(VoiceModelInstallProgress(phase: .verifyingRuntime, fractionCompleted: 0.72))
        let archiveData = try Data(contentsOf: archive, options: .mappedIfSafe)
        guard archiveMatchesChecksum(archiveData, expectedSHA256: expectedSHA256) else {
            throw VoiceModelInstallerError.runtimeInstallFailed("NeMo-Speech archive SHA-256 mismatch.")
        }
        let listing = try run("/usr/bin/tar", ["-tzf", archive.path])
        guard listing.split(separator: "\n").allSatisfy(safeArchivePath) else {
            throw VoiceModelInstallerError.runtimeInstallFailed("NeMo-Speech archive contains an unsafe path.")
        }
        let extraction = downloadDirectory.appendingPathComponent("extracted", isDirectory: true)
        try fileManager.createDirectory(at: extraction, withIntermediateDirectories: true)
        _ = try run("/usr/bin/tar", ["-xzf", archive.path, "-C", extraction.path])
        try Task.checkCancellation()
        let binaries = (fileManager.enumerator(at: extraction, includingPropertiesForKeys: nil)?.allObjects as? [URL] ?? [])
            .filter { $0.lastPathComponent == "nemo-speech" && $0.deletingLastPathComponent().lastPathComponent == "bin" && fileManager.isExecutableFile(atPath: $0.path) }
        guard let binary = binaries.first else { throw VoiceModelInstallerError.runtimeInstallFailed("Validated archive does not contain bin/nemo-speech.") }
        let extractedRoot = binary.deletingLastPathComponent().deletingLastPathComponent()
        let base = managedDirectory(fileManager: fileManager).deletingLastPathComponent()
        let versioned = base.appendingPathComponent(version, isDirectory: true)
        let staging = base.appendingPathComponent(".\(version).installing-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: base, withIntermediateDirectories: true)
        do {
            try fileManager.copyItem(at: extractedRoot, to: staging)
            let relative = binary.path.replacingOccurrences(of: extractedRoot.path + "/", with: "")
            let manifest = Manifest(managedBy: "Cortexa", runtimeID: "nemo-speech", version: version, archiveSHA256: expectedSHA256, binaryRelativePath: relative)
            let manifestData = try JSONEncoder().encode(manifest)
            try manifestData.write(to: staging.appendingPathComponent("cortexa-runtime.json"), options: .atomic)
            guard let stagedCLI = validatedManagedCLI(in: staging, fileManager: fileManager) else {
                throw VoiceModelInstallerError.runtimeInstallFailed("Installed archive is missing its Cortexa runtime manifest or executable at \(staging.path).")
            }
            let stagedVersion = runtimeVersion(stagedCLI)
            guard stagedVersion == version else {
                throw VoiceModelInstallerError.runtimeInstallFailed("Installed NeMo-Speech runtime at \(stagedCLI.path) reported version \(stagedVersion ?? "unavailable"), expected \(version).")
            }
            try Task.checkCancellation()
            progressHandler?(VoiceModelInstallProgress(phase: .verifyingRuntime, fractionCompleted: 0.95))
            try commit(staging: staging, to: versioned, fileManager: fileManager)
            return versioned.appendingPathComponent(relative)
        } catch {
            if fileManager.fileExists(atPath: staging.path) { try? fileManager.removeItem(at: staging) }
            throw error
        }
    }

    private static func commit(staging: URL, to destination: URL, fileManager: FileManager) throws {
        NemoRuntimeAccess.lock.lock(); defer { NemoRuntimeAccess.lock.unlock() }
        let backup = destination.deletingLastPathComponent()
            .appendingPathComponent(".\(version).previous-\(UUID().uuidString)", isDirectory: true)
        let hadPrevious = fileManager.fileExists(atPath: destination.path)
        if hadPrevious { try fileManager.moveItem(at: destination, to: backup) }
        do {
            try fileManager.moveItem(at: staging, to: destination)
            if hadPrevious { try fileManager.removeItem(at: backup) }
        } catch {
            if hadPrevious, !fileManager.fileExists(atPath: destination.path) {
                try fileManager.moveItem(at: backup, to: destination)
            }
            throw error
        }
    }

    static func removeManagedRuntimeIfUnused(fileManager: FileManager) throws {
        let cache = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("NeMoSpeech/models", isDirectory: true)
        try removeManagedRuntimeIfUnused(
            runtimeDirectory: managedDirectory(fileManager: fileManager),
            modelCacheDirectory: cache,
            fileManager: fileManager
        )
    }

    static func removeManagedRuntimeIfUnused(
        runtimeDirectory: URL,
        modelCacheDirectory: URL?,
        fileManager: FileManager
    ) throws {
        NemoRuntimeAccess.lock.lock(); defer { NemoRuntimeAccess.lock.unlock() }
        guard fileManager.fileExists(atPath: runtimeDirectory.path) else { return }
        let dependentModels = LocalVoiceModelCatalog.availableModels()
            .filter { $0.runtimeID == "nemo-speech" }
        let anyDependentModelInstalled = dependentModels.contains { descriptor in
            guard let fileName = descriptor.localFileName, let modelCacheDirectory else { return false }
            return fileManager.fileExists(atPath: modelCacheDirectory.appendingPathComponent(fileName).path)
        }
        guard !anyDependentModelInstalled else { return }
        guard validatedManagedCLI(in: runtimeDirectory, fileManager: fileManager) != nil else { return }
        try fileManager.removeItem(at: runtimeDirectory)
    }

    private static func managedDirectory(fileManager: FileManager) -> URL {
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return support.appendingPathComponent("Cortexa/Runtime/NeMo-Speech/\(version)", isDirectory: true)
    }

    #if arch(arm64)
    private static let isAppleSilicon = true
    #else
    private static let isAppleSilicon = false
    #endif

    private static func externalCandidates() -> [URL] {
        [
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support/Cortexa/Runtime/nemo-speech"),
            URL(fileURLWithPath: "/opt/homebrew/bin/nemo-speech"),
            URL(fileURLWithPath: "/usr/local/bin/nemo-speech"),
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".local/bin/nemo-speech")
        ]
    }

    static func validatedManagedCLI(in directory: URL, fileManager: FileManager) -> URL? {
        let manifestURL = directory.appendingPathComponent("cortexa-runtime.json")
        guard let data = try? Data(contentsOf: manifestURL), let manifest = try? JSONDecoder().decode(Manifest.self, from: data),
              manifest.managedBy == "Cortexa", manifest.runtimeID == "nemo-speech", manifest.version == version,
              manifest.archiveSHA256 == expectedSHA256, !manifest.binaryRelativePath.hasPrefix("/"),
              !manifest.binaryRelativePath.split(separator: "/").contains("..") else { return nil }
        let cli = directory.appendingPathComponent(manifest.binaryRelativePath)
        return fileManager.isExecutableFile(atPath: cli.path) ? cli : nil
    }

    static func archiveMatchesChecksum(_ data: Data, expectedSHA256: String) -> Bool {
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        return digest == expectedSHA256
    }

    private static func runtimeVersion(_ cli: URL) -> String? {
        guard let output = try? run(cli.path, ["--version"]) else { return nil }
        guard let token = output.split(whereSeparator: { $0.isWhitespace }).last else { return nil }
        return token.trimmingCharacters(in: CharacterSet(charactersIn: "v"))
    }

    static func safeArchivePath(_ entry: Substring) -> Bool {
        !entry.hasPrefix("/") && !entry.split(separator: "/").contains("..")
    }

    private static func run(_ executable: String, _ arguments: [String]) throws -> String {
        let process = Process(); process.executableURL = URL(fileURLWithPath: executable); process.arguments = arguments
        let output = Pipe(); let errors = Pipe(); process.standardOutput = output; process.standardError = errors
        try process.run(); process.waitUntilExit()
        let outData = output.fileHandleForReading.readDataToEndOfFile()
        let errorData = errors.fileHandleForReading.readDataToEndOfFile()
        guard process.terminationStatus == 0 else { throw VoiceModelInstallerError.runtimeInstallFailed(String(data: errorData, encoding: .utf8) ?? "Runtime command failed.") }
        return String(data: outData, encoding: .utf8) ?? ""
    }
}
