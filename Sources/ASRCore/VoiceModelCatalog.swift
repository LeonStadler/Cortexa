import Foundation

public enum VoiceProviderID: String, Codable, CaseIterable, Sendable {
    case whisperCpp = "whisper.cpp"
    case nvidiaParakeet = "nvidia.parakeet"
}

public struct VoiceProviderDescriptor: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let summary: String
    public let isAvailable: Bool

    public init(id: String, displayName: String, summary: String, isAvailable: Bool) {
        self.id = id
        self.displayName = displayName
        self.summary = summary
        self.isAvailable = isAvailable
    }
}

public enum VoiceModelLanguageScope: String, Codable, Equatable, Sendable {
    case all
    case english
    case multilingual
}

public enum VoiceModelInstallState: String, Codable, Equatable, Sendable {
    case bundled
    case downloadable
    case unavailable
}

public struct VoiceModelDescriptor: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let providerID: String
    public let displayName: String
    public let languageCode: String?
    public let languageScope: VoiceModelLanguageScope
    public let supportsTranslationToEnglish: Bool
    public let speedScore: Int
    public let accuracyScore: Int
    public let sizeLabel: String
    public let installState: VoiceModelInstallState
    public let localFileName: String?
    public let downloadIdentifier: String?

    public init(
        id: String,
        providerID: String,
        displayName: String,
        languageCode: String?,
        languageScope: VoiceModelLanguageScope,
        supportsTranslationToEnglish: Bool,
        speedScore: Int,
        accuracyScore: Int,
        sizeLabel: String,
        installState: VoiceModelInstallState,
        localFileName: String? = nil,
        downloadIdentifier: String? = nil
    ) {
        self.id = id
        self.providerID = providerID
        self.displayName = displayName
        self.languageCode = languageCode
        self.languageScope = languageScope
        self.supportsTranslationToEnglish = supportsTranslationToEnglish
        self.speedScore = speedScore
        self.accuracyScore = accuracyScore
        self.sizeLabel = sizeLabel
        self.installState = installState
        self.localFileName = localFileName
        self.downloadIdentifier = downloadIdentifier
    }
}

public struct VoiceModelSelection: Codable, Equatable, Sendable {
    public let providerID: String
    public let modelID: String

    public init(providerID: String, modelID: String) {
        self.providerID = providerID
        self.modelID = modelID
    }
}

public struct VoiceLanguageOverride: Codable, Equatable, Sendable {
    public let languageCode: String
    public let modelID: String

    public init(languageCode: String, modelID: String) {
        self.languageCode = languageCode
        self.modelID = modelID
    }
}

public enum LocalVoiceModelCatalog {
    public static let defaultProviderID = VoiceProviderID.whisperCpp.rawValue
    public static let defaultModelID = "whisper.standard"

    public static func availableProviders(parakeetBinaryURL: URL? = nil) -> [VoiceProviderDescriptor] {
        var providers = [
            VoiceProviderDescriptor(
                id: VoiceProviderID.whisperCpp.rawValue,
                displayName: "Whisper Models (Local)",
                summary: "Lokale whisper.cpp-Modelle mit installierbaren Größen und Sprachvarianten.",
                isAvailable: true
            )
        ]

        if let parakeetBinaryURL,
           FileManager.default.isExecutableFile(atPath: parakeetBinaryURL.path) {
            providers.append(
                VoiceProviderDescriptor(
                    id: VoiceProviderID.nvidiaParakeet.rawValue,
                    displayName: "Nvidia Parakeet (Local)",
                    summary: "Lokale NVIDIA-Parakeet-Modelle für Sprachtranskription.",
                    isAvailable: true
                )
            )
        }

        return providers
    }

    public static func availableModels(includeParakeet: Bool = false) -> [VoiceModelDescriptor] {
        var models = whisperModels
        if includeParakeet {
            models.append(contentsOf: parakeetModels)
        }
        return models
    }

    public static func model(id: String, includeParakeet: Bool = false) -> VoiceModelDescriptor? {
        availableModels(includeParakeet: includeParakeet).first(where: { $0.id == id })
    }

    private static let whisperModels: [VoiceModelDescriptor] = [
        VoiceModelDescriptor(id: "whisper.ultra-v3-turbo", providerID: VoiceProviderID.whisperCpp.rawValue, displayName: "Ultra V3 Turbo", languageCode: nil, languageScope: .all, supportsTranslationToEnglish: true, speedScore: 8, accuracyScore: 8, sizeLabel: "1.6 GB", installState: .downloadable, localFileName: "ggml-large-v3-turbo.bin", downloadIdentifier: "large-v3-turbo"),
        VoiceModelDescriptor(id: "whisper.ultra", providerID: VoiceProviderID.whisperCpp.rawValue, displayName: "Ultra", languageCode: nil, languageScope: .all, supportsTranslationToEnglish: true, speedScore: 6, accuracyScore: 10, sizeLabel: "3 GB", installState: .downloadable, localFileName: "ggml-large-v3.bin", downloadIdentifier: "large-v3"),
        VoiceModelDescriptor(id: "whisper.pro", providerID: VoiceProviderID.whisperCpp.rawValue, displayName: "Pro", languageCode: nil, languageScope: .all, supportsTranslationToEnglish: true, speedScore: 7, accuracyScore: 8, sizeLabel: "1.5 GB", installState: .downloadable, localFileName: "ggml-small.bin", downloadIdentifier: "small"),
        VoiceModelDescriptor(id: "whisper.pro.en", providerID: VoiceProviderID.whisperCpp.rawValue, displayName: "Pro (English)", languageCode: "en", languageScope: .english, supportsTranslationToEnglish: false, speedScore: 7, accuracyScore: 8, sizeLabel: "1.5 GB", installState: .downloadable, localFileName: "ggml-small.en.bin", downloadIdentifier: "small.en"),
        VoiceModelDescriptor(id: defaultModelID, providerID: VoiceProviderID.whisperCpp.rawValue, displayName: "Standard", languageCode: nil, languageScope: .all, supportsTranslationToEnglish: true, speedScore: 8, accuracyScore: 5, sizeLabel: "500 MB", installState: .bundled, localFileName: "ggml-base.bin", downloadIdentifier: "base"),
        VoiceModelDescriptor(id: "whisper.standard.en", providerID: VoiceProviderID.whisperCpp.rawValue, displayName: "Standard (English)", languageCode: "en", languageScope: .english, supportsTranslationToEnglish: false, speedScore: 8, accuracyScore: 5, sizeLabel: "500 MB", installState: .downloadable, localFileName: "ggml-base.en.bin", downloadIdentifier: "base.en"),
        VoiceModelDescriptor(id: "whisper.nano", providerID: VoiceProviderID.whisperCpp.rawValue, displayName: "Nano", languageCode: nil, languageScope: .all, supportsTranslationToEnglish: true, speedScore: 9, accuracyScore: 3, sizeLabel: "150 MB", installState: .downloadable, localFileName: "ggml-base-q5_1.bin", downloadIdentifier: "base-q5_1"),
        VoiceModelDescriptor(id: "whisper.nano.en", providerID: VoiceProviderID.whisperCpp.rawValue, displayName: "Nano (English)", languageCode: "en", languageScope: .english, supportsTranslationToEnglish: false, speedScore: 9, accuracyScore: 3, sizeLabel: "150 MB", installState: .downloadable, localFileName: "ggml-base.en-q5_1.bin", downloadIdentifier: "base.en-q5_1"),
        VoiceModelDescriptor(id: "whisper.fast", providerID: VoiceProviderID.whisperCpp.rawValue, displayName: "Fast", languageCode: nil, languageScope: .all, supportsTranslationToEnglish: true, speedScore: 10, accuracyScore: 1, sizeLabel: "75 MB", installState: .downloadable, localFileName: "ggml-tiny.bin", downloadIdentifier: "tiny"),
        VoiceModelDescriptor(id: "whisper.fast.en", providerID: VoiceProviderID.whisperCpp.rawValue, displayName: "Fast (English)", languageCode: "en", languageScope: .english, supportsTranslationToEnglish: false, speedScore: 10, accuracyScore: 1, sizeLabel: "75 MB", installState: .downloadable, localFileName: "ggml-tiny.en.bin", downloadIdentifier: "tiny.en")
    ]

    private static let parakeetModels: [VoiceModelDescriptor] = [
        VoiceModelDescriptor(id: "parakeet.english", providerID: VoiceProviderID.nvidiaParakeet.rawValue, displayName: "Parakeet", languageCode: "en", languageScope: .english, supportsTranslationToEnglish: false, speedScore: 10, accuracyScore: 8, sizeLabel: "476 MB", installState: .unavailable),
        VoiceModelDescriptor(id: "parakeet.multilingual", providerID: VoiceProviderID.nvidiaParakeet.rawValue, displayName: "Parakeet Multilanguage", languageCode: nil, languageScope: .multilingual, supportsTranslationToEnglish: false, speedScore: 10, accuracyScore: 8, sizeLabel: "494 MB", installState: .unavailable)
    ]
}
