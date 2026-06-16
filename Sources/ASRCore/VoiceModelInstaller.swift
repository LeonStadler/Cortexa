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
        try BundledWhisperRuntimeInstaller.installBundledRuntime(
            appName: appName,
            suppressedBundledModelFileNames: suppressionStore.suppressedFileNames()
        )
    }

    public func installedWhisperModelFileNames(appName: String = "WisprLocal") throws -> Set<String>
    {
        let runtime = try installedRuntime(appName: appName)
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
        let tempDirectory = fileManager.temporaryDirectory.appendingPathComponent(
            "voice-model-download-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempDirectory) }

        let destinationURL = tempDirectory.appendingPathComponent(localFileName)
        let downloadClient = VoiceModelDownloadClient(fileManager: fileManager)
        try await downloadClient.download(from: downloadURL, to: destinationURL) { progress in
            progressHandler?(progress)
        }

        progressHandler?(
            VoiceModelInstallProgress(phase: .finalizing, fractionCompleted: 0.99)
        )

        let targetURL = runtime.modelsDirectoryURL.appendingPathComponent(localFileName)
        if fileManager.fileExists(atPath: targetURL.path) {
            try fileManager.removeItem(at: targetURL)
        }
        try fileManager.copyItem(at: destinationURL, to: targetURL)

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

        if descriptor.installState != .bundled {
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
