import Foundation

public enum ASRBackend: String, Sendable, Codable {
    case whisperCpp
    case coreMLHybrid
}

public enum LatencyProfile: String, Sendable, Codable {
    case streaming
    case quality
}

public enum ASRTranslationMode: String, Sendable, Codable, Equatable {
    case original
    case toEnglish
}

public struct ASRConfig: Sendable, Codable, Equatable {
    public let languageHint: String?
    public let translationMode: ASRTranslationMode
    public let providerID: String
    public let catalogModelID: String
    public let modelID: String
    public let backend: ASRBackend
    public let latencyProfile: LatencyProfile
    public let threadCount: Int
    public let beamSize: Int
    public let chunkMilliseconds: Int

    public init(
        languageHint: String?,
        translationMode: ASRTranslationMode = .original,
        providerID: String = VoiceProviderID.whisperCpp.rawValue,
        catalogModelID: String = LocalVoiceModelCatalog.defaultModelID,
        modelID: String,
        backend: ASRBackend,
        latencyProfile: LatencyProfile,
        threadCount: Int? = nil,
        beamSize: Int? = nil,
        chunkMilliseconds: Int? = nil
    ) {
        self.languageHint = languageHint
        self.translationMode = translationMode
        self.providerID = providerID
        self.catalogModelID = catalogModelID
        self.modelID = modelID
        self.backend = backend
        self.latencyProfile = latencyProfile
        self.threadCount = threadCount ?? 0
        self.beamSize = beamSize ?? (latencyProfile == .streaming ? 1 : 5)
        self.chunkMilliseconds = chunkMilliseconds ?? (latencyProfile == .streaming ? 280 : 600)
    }
}

public struct PartialTranscript: Sendable, Equatable {
    public let text: String
    public let sequenceNumber: Int
    public let timestamp: Date

    public init(text: String, sequenceNumber: Int, timestamp: Date = Date()) {
        self.text = text
        self.sequenceNumber = sequenceNumber
        self.timestamp = timestamp
    }
}

public struct FinalSegment: Sendable, Equatable {
    public let text: String
    public let startTime: TimeInterval
    public let endTime: TimeInterval

    public init(text: String, startTime: TimeInterval, endTime: TimeInterval) {
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
    }
}

public struct FinalTranscript: Sendable, Equatable {
    public let text: String
    public let segments: [FinalSegment]
    public let language: String?

    public init(text: String, segments: [FinalSegment], language: String?) {
        self.text = text
        self.segments = segments
        self.language = language
    }
}

public struct AudioChunk: Sendable {
    public let pcm16kMonoFloat: [Float]
    public let sampleRate: Int
    public let channelCount: Int
    public let frameCount: Int
    public let timestamp: Date

    public init(
        pcm16kMonoFloat: [Float],
        sampleRate: Int,
        channelCount: Int,
        frameCount: Int,
        timestamp: Date = Date()
    ) {
        self.pcm16kMonoFloat = pcm16kMonoFloat
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.frameCount = frameCount
        self.timestamp = timestamp
    }
}

public enum AudioInterruptionEvent: Sendable, Equatable {
    case began(reason: String)
    case ended(shouldResume: Bool)
    case routeChanged(description: String)
}

public enum WhisperEngineError: Error, LocalizedError {
    case modelNotLoaded
    case engineAlreadyRunning
    case engineNotRunning
    case invalidAudioBuffer
    case backendUnavailable(String)

    public var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "No model has been loaded."
        case .engineAlreadyRunning:
            return "Streaming already started."
        case .engineNotRunning:
            return "Streaming has not been started."
        case .invalidAudioBuffer:
            return "Audio input buffer is invalid."
        case let .backendUnavailable(reason):
            return "ASR backend unavailable: \(reason)"
        }
    }
}
