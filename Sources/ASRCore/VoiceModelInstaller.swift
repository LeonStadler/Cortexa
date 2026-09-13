import Foundation

public enum VoiceModelInstallerError: Error, LocalizedError {
    case unsupportedProvider(String)
    case modelNotDownloadable(String)
    case missingDownloadURL(String)
    case missingLocalFileName(String)
    case removalWouldLeaveNoDefaultModel

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

    public func remove(_ descriptor: VoiceModelDescriptor, appName: String = "WisprLocal") throws
        -> InstalledWhisperRuntime
    {
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
