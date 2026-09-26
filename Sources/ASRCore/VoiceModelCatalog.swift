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
    case requiredFirstRun
    case unavailable
}

public struct VoiceModelDescriptor: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let providerID: String
    public let displayName: String
    public let languageCode: String?
    public let languageScope: VoiceModelLanguageScope
    public let supportsTranslationToEnglish: Bool
    public let supportsLiveTranscription: Bool
    public let supportsAutomaticLanguageDetection: Bool
    public let supportsLanguageSelection: Bool
    /// Nil means that the model accepts every language supported by the app.
    public let supportedLanguageCodes: Set<String>?
    public let maximumRecordingDurationSeconds: Int?
    public let speedScore: Int
    public let accuracyScore: Int
    public let sizeLabel: String
    public let expectedDownloadBytes: Int64?
    public let installState: VoiceModelInstallState
    public let localFileName: String?
    public let downloadIdentifier: String?
    public let runtimeID: String?

    public init(
        id: String,
        providerID: String,
        displayName: String,
        languageCode: String?,
        languageScope: VoiceModelLanguageScope,
        supportsTranslationToEnglish: Bool,
        supportsLiveTranscription: Bool = true,
        supportsAutomaticLanguageDetection: Bool = true,
        supportsLanguageSelection: Bool = true,
        supportedLanguageCodes: Set<String>? = nil,
        maximumRecordingDurationSeconds: Int? = nil,
        speedScore: Int,
        accuracyScore: Int,
        sizeLabel: String,
        expectedDownloadBytes: Int64? = nil,
        installState: VoiceModelInstallState,
        localFileName: String? = nil,
        downloadIdentifier: String? = nil,
        runtimeID: String? = nil
    ) {
        self.id = id
        self.providerID = providerID
        self.displayName = displayName
        self.languageCode = languageCode
        self.languageScope = languageScope
        self.supportsTranslationToEnglish = supportsTranslationToEnglish
        self.supportsLiveTranscription = supportsLiveTranscription
        self.supportsAutomaticLanguageDetection = supportsAutomaticLanguageDetection
        self.supportsLanguageSelection = supportsLanguageSelection
        self.supportedLanguageCodes = supportedLanguageCodes
        self.maximumRecordingDurationSeconds = maximumRecordingDurationSeconds
        self.speedScore = speedScore
        self.accuracyScore = accuracyScore
        self.sizeLabel = sizeLabel
        self.expectedDownloadBytes = expectedDownloadBytes
        self.installState = installState
        self.localFileName = localFileName
        self.downloadIdentifier = downloadIdentifier
        self.runtimeID = runtimeID
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
    public static let defaultModelFileName = "ggml-base.bin"

    /// Hugging Face `ggml-base.bin` (2024-03 resolve/main).
    public static let defaultModelExpectedBytes: Int64 = 147_964_096
    /// Hugging Face `ggml-small.bin`.
    public static let proModelExpectedBytes: Int64 = 487_601_958
    /// NVIDIA Parakeet TDT v3 Q8 GGUF (Hugging Face file metadata).
    public static let parakeetExpectedBytes: Int64 = 713_975_456

    public static func formattedDownloadSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    public static func availableProviders(parakeetBinaryURL: URL? = nil)
        -> [VoiceProviderDescriptor]
    {
        var providers = [
            VoiceProviderDescriptor(
                id: VoiceProviderID.whisperCpp.rawValue,
                displayName: "Whisper Models",
                summary:
                    "Lokale whisper.cpp-Modelle mit installierbaren Größen und Sprachvarianten.",
                isAvailable: true
            )
        ]

        let parakeetAvailable = parakeetBinaryURL.map {
            FileManager.default.isExecutableFile(atPath: $0.path)
        } ?? false
        providers.append(
            VoiceProviderDescriptor(
                id: VoiceProviderID.nvidiaParakeet.rawValue,
                displayName: "Nvidia Parakeet",
                summary: parakeetAvailable
                    ? "Lokale NVIDIA-Parakeet-Modelle für Sprachtranskription."
                    : "Parakeet-Modelle können heruntergeladen werden; für die Transkription wird zusätzlich NeMo-Speech.cpp benötigt.",
                isAvailable: parakeetAvailable
            )
        )

        return providers
    }

    public static func availableModels(includeParakeet: Bool = true) -> [VoiceModelDescriptor] {
        var models = whisperModels
        if includeParakeet {
            models.append(contentsOf: parakeetModels)
        }
        return models
    }

    public static func model(id: String, includeParakeet: Bool = true) -> VoiceModelDescriptor? {
        availableModels(includeParakeet: includeParakeet).first(where: { $0.id == id })
    }

    private static let whisperModels: [VoiceModelDescriptor] = [
        VoiceModelDescriptor(
            id: "whisper.ultra-v3-turbo", providerID: VoiceProviderID.whisperCpp.rawValue,
            displayName: "Ultra V3 Turbo", languageCode: nil, languageScope: .all,
            supportsTranslationToEnglish: true, speedScore: 8, accuracyScore: 8,
            sizeLabel: "1.6 GB", installState: .downloadable,
            localFileName: "ggml-large-v3-turbo.bin", downloadIdentifier: "large-v3-turbo"),
        VoiceModelDescriptor(
            id: "whisper.ultra", providerID: VoiceProviderID.whisperCpp.rawValue,
            displayName: "Ultra", languageCode: nil, languageScope: .all,
            supportsTranslationToEnglish: true, speedScore: 6, accuracyScore: 10, sizeLabel: "3 GB",
            installState: .downloadable, localFileName: "ggml-large-v3.bin",
            downloadIdentifier: "large-v3"),
        VoiceModelDescriptor(
            id: "whisper.pro", providerID: VoiceProviderID.whisperCpp.rawValue, displayName: "Pro",
            languageCode: nil, languageScope: .all, supportsTranslationToEnglish: true,
            speedScore: 7, accuracyScore: 8,
            sizeLabel: formattedDownloadSize(proModelExpectedBytes),
            expectedDownloadBytes: proModelExpectedBytes,
            installState: .downloadable,
            localFileName: "ggml-small.bin", downloadIdentifier: "small"),
        VoiceModelDescriptor(
            id: "whisper.pro.en", providerID: VoiceProviderID.whisperCpp.rawValue,
            displayName: "Pro (English)", languageCode: "en", languageScope: .english,
            supportsTranslationToEnglish: false, supportsAutomaticLanguageDetection: false,
            speedScore: 7, accuracyScore: 8,
            sizeLabel: formattedDownloadSize(proModelExpectedBytes),
            expectedDownloadBytes: proModelExpectedBytes,
            installState: .downloadable, localFileName: "ggml-small.en.bin",
            downloadIdentifier: "small.en"),
        VoiceModelDescriptor(
            id: defaultModelID, providerID: VoiceProviderID.whisperCpp.rawValue,
            displayName: "Standard", languageCode: nil, languageScope: .all,
            supportsTranslationToEnglish: true, speedScore: 8, accuracyScore: 5,
            sizeLabel: formattedDownloadSize(defaultModelExpectedBytes),
            expectedDownloadBytes: defaultModelExpectedBytes,
            installState: .requiredFirstRun, localFileName: defaultModelFileName,
            downloadIdentifier: "base"),
        VoiceModelDescriptor(
            id: "whisper.standard.en", providerID: VoiceProviderID.whisperCpp.rawValue,
            displayName: "Standard (English)", languageCode: "en", languageScope: .english,
            supportsTranslationToEnglish: false, supportsAutomaticLanguageDetection: false,
            speedScore: 8, accuracyScore: 5,
            sizeLabel: formattedDownloadSize(defaultModelExpectedBytes),
            expectedDownloadBytes: defaultModelExpectedBytes,
            installState: .downloadable, localFileName: "ggml-base.en.bin",
            downloadIdentifier: "base.en"),
        VoiceModelDescriptor(
            id: "whisper.nano", providerID: VoiceProviderID.whisperCpp.rawValue,
            displayName: "Nano", languageCode: nil, languageScope: .all,
            supportsTranslationToEnglish: true, speedScore: 9, accuracyScore: 3,
            sizeLabel: "150 MB", installState: .downloadable, localFileName: "ggml-base-q5_1.bin",
            downloadIdentifier: "base-q5_1"),
        VoiceModelDescriptor(
            id: "whisper.nano.en", providerID: VoiceProviderID.whisperCpp.rawValue,
            displayName: "Nano (English)", languageCode: "en", languageScope: .english,
            supportsTranslationToEnglish: false, supportsAutomaticLanguageDetection: false,
            speedScore: 9, accuracyScore: 3,
            sizeLabel: "150 MB", installState: .downloadable,
            localFileName: "ggml-base.en-q5_1.bin", downloadIdentifier: "base.en-q5_1"),
        VoiceModelDescriptor(
            id: "whisper.fast", providerID: VoiceProviderID.whisperCpp.rawValue,
            displayName: "Fast", languageCode: nil, languageScope: .all,
            supportsTranslationToEnglish: true, speedScore: 10, accuracyScore: 1,
            sizeLabel: "75 MB", installState: .downloadable, localFileName: "ggml-tiny.bin",
            downloadIdentifier: "tiny"),
        VoiceModelDescriptor(
            id: "whisper.fast.en", providerID: VoiceProviderID.whisperCpp.rawValue,
            displayName: "Fast (English)", languageCode: "en", languageScope: .english,
            supportsTranslationToEnglish: false, supportsAutomaticLanguageDetection: false,
            speedScore: 10, accuracyScore: 1,
            sizeLabel: "75 MB", installState: .downloadable, localFileName: "ggml-tiny.en.bin",
            downloadIdentifier: "tiny.en"),
    ]

    private static let parakeetModels: [VoiceModelDescriptor] = [
        VoiceModelDescriptor(
            id: "parakeet.multilingual", providerID: VoiceProviderID.nvidiaParakeet.rawValue,
            displayName: "Parakeet TDT v3", languageCode: nil, languageScope: .multilingual,
            supportsTranslationToEnglish: false, supportsLiveTranscription: false,
            supportsAutomaticLanguageDetection: true, supportsLanguageSelection: false,
            supportedLanguageCodes: ["bg", "hr", "cs", "da", "nl", "en", "et", "fi", "fr", "de", "el", "hu", "it", "lv", "lt", "mt", "pl", "pt", "ro", "sk", "sl", "es", "sv", "ru", "uk"],
            maximumRecordingDurationSeconds: 24 * 60,
            speedScore: 10, accuracyScore: 8,
            sizeLabel: formattedDownloadSize(parakeetExpectedBytes),
            expectedDownloadBytes: parakeetExpectedBytes,
            installState: .downloadable,
            localFileName: "parakeet-tdt-0.6b-v3.q8_0.gguf",
            downloadIdentifier: "parakeet-tdt",
            runtimeID: "nemo-speech"),
    ]
}
