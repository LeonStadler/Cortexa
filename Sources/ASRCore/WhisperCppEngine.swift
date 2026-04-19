import Foundation

public final class WhisperCppEngine: WhisperEngine {
    public var onPartial: ((PartialTranscript) -> Void)?
    public var onFinalSegment: ((FinalSegment) -> Void)?
    public var onDebugEvent: ((String) -> Void)?

    private let explicitCLIPath: URL?
    private let stateQueue = DispatchQueue(label: "wispr.asr.whispercpp.state", qos: .userInitiated)
    private let decodeQueue = DispatchQueue(label: "wispr.asr.whispercpp.decode", qos: .userInitiated)

    private var config: ASRConfig?
    private var modelPath: URL?
    private var resolvedCLIPath: URL?
    private var isStreaming = false
    private var streamingSamples: [Float] = []
    private var isDecodingPartial = false
    private var sequence = 0
    private var decodeVersion = 0

    // Keep enough context for responsive live partials without letting decode cost grow
    // unbounded, while preserving a much longer final buffer for stop/finalize accuracy.
    private let maxPartialDecodeWindowSamples = 16_000 * 45
    private let maxFinalRecordingSamples = 16_000 * 60 * 10

    public init(cliPath: URL? = nil) {
        self.explicitCLIPath = cliPath
    }

    public func loadBundledModel(
        fileName: String,
        config: ASRConfig,
        bundle: Bundle = .main,
        appName: String = "WisprLocal"
    ) throws {
        let runtime = try BundledWhisperRuntimeInstaller.installBundledRuntime(bundle: bundle, appName: appName)
        let modelURL = runtime.modelsDirectoryURL.appendingPathComponent(fileName)
        try loadModel(at: modelURL, config: config)
    }

    public func loadModel(at path: URL, config: ASRConfig) throws {
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw WhisperEngineError.backendUnavailable("Model file missing at \(path.path)")
        }

        var cliPath = WhisperCLIExecutor.resolveCLIPath(explicitPath: explicitCLIPath, modelPath: path)

        if cliPath == nil {
            if let installed = try? BundledWhisperRuntimeInstaller.installBundledRuntime() {
                cliPath = WhisperCLIExecutor.resolveCLIPath(explicitPath: installed.cliURL, modelPath: path)
            }
        }

        guard let cliPath else {
            throw WhisperEngineError.backendUnavailable(
                "whisper-cli not found. Bundle Runtime/whisper-cli + Runtime/models or set WHISPER_CLI_PATH."
            )
        }

        emitDebug("engine.loadModel cli=\(cliPath.lastPathComponent) model=\(path.lastPathComponent) backend=\(config.backend.rawValue) latency=\(config.latencyProfile.rawValue)")
        self.modelPath = path
        self.config = config
        self.resolvedCLIPath = cliPath
    }

    public func startStreaming() throws {
        guard modelPath != nil, config != nil, resolvedCLIPath != nil else {
            throw WhisperEngineError.modelNotLoaded
        }

        let didStart = stateQueue.sync { () -> Bool in
            guard !isStreaming else { return false }
            isStreaming = true
            streamingSamples.removeAll(keepingCapacity: true)
            isDecodingPartial = false
            sequence = 0
            decodeVersion = 0
            return true
        }

        if !didStart {
            throw WhisperEngineError.engineAlreadyRunning
        }

        emitDebug("engine.startStreaming")
    }

    public func pushAudioPCM16kMono(_ buffer: UnsafePointer<Float>, frameCount: Int) throws {
        guard frameCount > 0 else {
            throw WhisperEngineError.invalidAudioBuffer
        }

        let schedule = stateQueue.sync { () -> (samples: [Float], version: Int)? in
            guard isStreaming else { return nil }

            let incoming = Array(UnsafeBufferPointer(start: buffer, count: frameCount))
            streamingSamples.append(contentsOf: incoming)

            if streamingSamples.count > maxFinalRecordingSamples {
                streamingSamples.removeFirst(streamingSamples.count - maxFinalRecordingSamples)
            }

            let partialThreshold = minimumSamplesForPartial(for: config)
            guard streamingSamples.count >= partialThreshold,
                  !isDecodingPartial else {
                return ([], -1)
            }

            isDecodingPartial = true
            decodeVersion += 1
            if streamingSamples.count > maxPartialDecodeWindowSamples {
                let partialSlice = streamingSamples.suffix(maxPartialDecodeWindowSamples)
                return (Array(partialSlice), decodeVersion)
            }
            return (streamingSamples, decodeVersion)
        }

        guard let schedule else {
            throw WhisperEngineError.engineNotRunning
        }

        guard schedule.version >= 0 else { return }

        decodeQueue.async { [weak self] in
            self?.runPartialDecode(samples: schedule.samples, version: schedule.version)
        }
    }

    public func stopStreaming() async throws -> FinalTranscript {
        let snapshot: ([Float], ASRConfig, URL, URL)? = stateQueue.sync {
            guard isStreaming,
                  let config,
                  let modelPath,
                  let cliPath = resolvedCLIPath else {
                return nil
            }

            isStreaming = false
            return (streamingSamples, config, modelPath, cliPath)
        }

        guard let snapshot else {
            throw WhisperEngineError.engineNotRunning
        }

        emitDebug("engine.stopStreaming samples=\(snapshot.0.count)")
        let final = try transcribe(samples: snapshot.0, config: snapshot.1, modelPath: snapshot.2, cliPath: snapshot.3)
        for segment in final.segments {
            onFinalSegment?(segment)
        }
        return final
    }

    public func resetStreaming() {
        stateQueue.sync {
            isStreaming = false
            streamingSamples.removeAll(keepingCapacity: false)
            isDecodingPartial = false
            sequence = 0
            decodeVersion += 1
        }
        emitDebug("engine.resetStreaming")
    }

    public func transcribeFile(url: URL) async throws -> FinalTranscript {
        guard let config, let modelPath, let cliPath = resolvedCLIPath else {
            throw WhisperEngineError.modelNotLoaded
        }
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw NSError(domain: "WhisperCppEngine", code: 2001, userInfo: [NSLocalizedDescriptionKey: "Audio file does not exist"]) 
        }

        let transcript = try transcribeWavFile(
            wavURL: url,
            config: config,
            modelPath: modelPath,
            cliPath: cliPath
        )

        emitDebug("engine.transcribeFile path=\(url.lastPathComponent) textLength=\(transcript.text.count)")

        for segment in transcript.segments {
            onFinalSegment?(segment)
        }

        return transcript
    }

    private func runPartialDecode(samples: [Float], version: Int) {
        defer {
            stateQueue.async { [weak self] in
                self?.isDecodingPartial = false
            }
        }

        guard let config, let modelPath, let cliPath = resolvedCLIPath else {
            return
        }

        do {
            let partial = try transcribe(samples: samples, config: config, modelPath: modelPath, cliPath: cliPath)

            let update = stateQueue.sync { () -> (shouldPublish: Bool, sequence: Int) in
                guard isStreaming, version == decodeVersion else {
                    return (false, sequence)
                }
                sequence += 1
                return (true, sequence)
            }

            guard update.shouldPublish else { return }
            onPartial?(PartialTranscript(text: partial.text, sequenceNumber: update.sequence))
        } catch {
            emitDebug("engine.partialDecodeFailed version=\(version) error=\(error.localizedDescription)")
        }
    }

    private func transcribe(samples: [Float], config: ASRConfig, modelPath: URL, cliPath: URL) throws -> FinalTranscript {
        let tempDir = try makeTempDirectory(prefix: "wispr_stream")
        let wavURL = tempDir.appendingPathComponent("input.wav")
        try WAVWriter.writePCMFloat32Mono16k(samples, to: wavURL)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        return try transcribeWavFile(wavURL: wavURL, config: config, modelPath: modelPath, cliPath: cliPath)
    }

    private func transcribeWavFile(wavURL: URL, config: ASRConfig, modelPath: URL, cliPath: URL) throws -> FinalTranscript {
        let tempDir = try makeTempDirectory(prefix: "wispr_decode")
        let outputBase = tempDir.appendingPathComponent("result")

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let threads = max(1, config.threadCount > 0 ? config.threadCount : ProcessInfo.processInfo.activeProcessorCount - 1)
        let beam = max(1, config.beamSize)

        emitDebug("engine.transcribeWav model=\(modelPath.lastPathComponent) wav=\(wavURL.lastPathComponent) threads=\(threads) beam=\(beam) translation=\(config.translationMode.rawValue)")

        let jsonURL = try WhisperCLIExecutor.run(
            cliPath: cliPath,
            modelPath: modelPath,
            inputWav: wavURL,
            languageHint: config.languageHint,
            initialPrompt: config.initialPrompt,
            translationMode: config.translationMode,
            threads: threads,
            beamSize: beam,
            outputBase: outputBase,
            debugLog: { [weak self] message in
                self?.emitDebug(message)
            }
        )

        guard FileManager.default.fileExists(atPath: jsonURL.path) else {
            throw NSError(domain: "WhisperCppEngine", code: 3001, userInfo: [NSLocalizedDescriptionKey: "whisper-cli produced no JSON output"]) 
        }

        return try WhisperCLIParser.parseResult(at: jsonURL)
    }

    private func emitDebug(_ message: String) {
        onDebugEvent?("[WhisperCpp] \(message)")
    }

    private func minimumSamplesForPartial(for config: ASRConfig?) -> Int {
        guard let config else {
            return 16_000
        }
        let chunkMilliseconds = max(160, config.chunkMilliseconds)
        return max(16_000, Int((Double(chunkMilliseconds) / 1000.0) * 16_000.0))
    }

    private func makeTempDirectory(prefix: String) throws -> URL {
        let base = FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("\(prefix)_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
