#if os(macOS)
import ASRCore
import FluidAudio
import Foundation

func makeStreamingWindowUpdate(
    words: [WordTiming], committed: [WordTiming], baseTime: TimeInterval
) -> (committed: [WordTiming], mutable: [WordTiming], offset: Int) {
    let boundary = baseTime + 12
    let lastStableWord = words.last { $0.endTime <= boundary }
    let newBoundary = lastStableWord?.endTime ?? boundary
    let newlyCommitted = words.filter { word in
        // The next window may emit the previously committed final token at time zero again.
        let repeatsBoundaryWord = word.startTime <= baseTime + 0.05 && committed.last?.word == word.word
        return word.endTime > baseTime && word.endTime <= newBoundary && !repeatsBoundaryWord
    }
    return (committed + newlyCommitted, words.filter { $0.endTime > newBoundary }, Int(newBoundary * 16_000))
}

public final class FluidSpeechEngine: WhisperEngine, @unchecked Sendable {
    public var onPartial: ((PartialTranscript) -> Void)?
    public var onFinalSegment: ((FinalSegment) -> Void)?
    public var onFailure: ((Error) -> Void)?
    private let lock = NSLock()
    private var manager: AsrManager?
    private var samples: [Float] = []
    private var generation: UInt64 = 0
    private var running = false
    private var decoding = false
    private var lastDecodedCount = 0
    private var offset = 0
    private var committed: [WordTiming] = []
    private var language: Language?
    private var sequence = 0
    private var partialTask: Task<Void, Never>?

    public init() {}

    public func loadModel(at path: URL, config: ASRCore.ASRConfig) throws {
        let version: AsrModelVersion
        switch config.modelID {
        case "fermion.phonon2": version = .phonon2
        case "moondream.parakeet-redux": version = .redux
        default: throw WhisperEngineError.modelNotLoaded
        }
        let models = try AsrModels.loadLocal(from: path, version: version)
        let loaded = AsrManager(models: models)
        locked { manager = loaded; language = config.languageHint.flatMap(Language.init(rawValue:)) }
    }

    public func startStreaming() throws {
        try locked {
            guard manager != nil else { throw WhisperEngineError.modelNotLoaded }
            guard !running else { throw WhisperEngineError.engineAlreadyRunning }
            generation &+= 1
            running = true
            samples = []; committed = []; offset = 0; lastDecodedCount = 0; sequence = 0
        }
    }

    public func pushAudioPCM16kMono(_ buffer: UnsafePointer<Float>, frameCount: Int) throws {
        guard frameCount > 0 else { throw WhisperEngineError.invalidAudioBuffer }
        let shouldDecode = try locked {
            guard running else { throw WhisperEngineError.engineNotRunning }
            samples.append(contentsOf: UnsafeBufferPointer(start: buffer, count: frameCount))
            return !decoding && samples.count - offset >= 16_000 && samples.count - lastDecodedCount >= 8_000
        }
        if shouldDecode { schedulePartial() }
    }

    private func schedulePartial() {
        let snapshot = locked { () -> (AsrManager, [Float], UInt64, Int, Language?)? in
            guard running, !decoding, let manager else { return nil }
            decoding = true
            lastDecodedCount = samples.count
            let end = min(samples.count, offset + 240_000)
            return (manager, Array(samples[offset..<end]), generation, offset, language)
        }
        guard let snapshot else { return }
        let task = Task.detached { [self] in
            do {
                var state = try TdtDecoderState()
                let result = try await snapshot.0.transcribe(snapshot.1, decoderState: &state, language: snapshot.4)
                let partial = locked { () -> PartialTranscript? in
                    guard running, generation == snapshot.2 else { return nil }
                    let baseTime = Double(snapshot.3) / 16_000
                    let words = buildWordTimings(from: result.tokenTimings ?? []).map {
                        WordTiming(word: $0.word, startTime: $0.startTime + baseTime,
                            endTime: $0.endTime + baseTime)
                    }
                    let mutableWords: [WordTiming]
                    if snapshot.1.count == 240_000 {
                        let update = makeStreamingWindowUpdate(
                            words: words, committed: committed, baseTime: baseTime)
                        committed = update.committed
                        offset = update.offset
                        mutableWords = update.mutable
                    } else {
                        mutableWords = words
                    }
                    let text = (committed.map(\.word) + mutableWords.map(\.word)).joined(separator: " ")
                    sequence += 1
                    return PartialTranscript(text: text, sequenceNumber: sequence)
                }
                if let partial { onPartial?(partial) }
            } catch {
                if locked({ running && generation == snapshot.2 }) { onFailure?(error) }
            }
            let shouldScheduleNext = locked {
                decoding = false
                return running && samples.count - offset >= 16_000
                    && samples.count - lastDecodedCount >= 8_000
            }
            if shouldScheduleNext { schedulePartial() }
        }
        locked { partialTask = task }
    }

    public func stopStreaming() async throws -> FinalTranscript {
        let snapshot = try locked { () -> (AsrManager, [Float], UInt64, Language?) in
            guard running, let manager else { throw WhisperEngineError.engineNotRunning }
            running = false
            return (manager, samples, generation, language)
        }
        let pending = locked { partialTask }
        await pending?.value
        guard locked({ generation == snapshot.2 }) else { throw CancellationError() }
        var state = try TdtDecoderState()
        let result = try await snapshot.0.transcribe(snapshot.1, decoderState: &state, language: snapshot.3)
        guard locked({ generation == snapshot.2 }) else { throw CancellationError() }
        return transcript(result)
    }

    public func resetStreaming() {
        locked { generation &+= 1; running = false; samples = []; committed = [] }
    }

    public func transcribeFile(url: URL) async throws -> FinalTranscript {
        guard let manager = locked({ manager }) else { throw WhisperEngineError.modelNotLoaded }
        var state = try TdtDecoderState()
        return transcript(try await manager.transcribe(url, decoderState: &state, language: locked({ language })))
    }

    private func transcript(_ result: ASRResult) -> FinalTranscript {
        let segments = buildWordTimings(from: result.tokenTimings ?? []).map {
            FinalSegment(text: $0.word, startTime: $0.startTime, endTime: $0.endTime)
        }
        return FinalTranscript(text: result.text, segments: segments, language: locked({ language?.rawValue }))
    }

    private func locked<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body()
    }
}
#endif
