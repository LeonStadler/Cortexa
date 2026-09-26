import Foundation

public final class WhisperCppEngine: WhisperEngine {
    public var onPartial: ((PartialTranscript) -> Void)?
    public var onFinalSegment: ((FinalSegment) -> Void)?
    public var onDebugEvent: ((String) -> Void)?

    private let explicitCLIPath: URL?
    private let nemoSpeechCLIPath: URL?
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
    public init(cliPath: URL? = nil, nemoSpeechCLIPath: URL? = nil) {
        self.explicitCLIPath = cliPath
        self.nemoSpeechCLIPath = nemoSpeechCLIPath
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

        if config.backend == .nemoSpeech {
            guard let cliPath = nemoSpeechCLIPath ?? VoiceModelInstaller.resolveNemoSpeechCLI(),
                FileManager.default.isExecutableFile(atPath: cliPath.path)
            else { throw WhisperEngineError.backendUnavailable("NVIDIA NeMo-Speech CLI is missing.") }
            emitDebug("engine.loadModel nemo-speech model=\(path.lastPathComponent)")
            self.modelPath = path
            self.config = config
            self.resolvedCLIPath = cliPath
            return
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

        let schedule = stateQueue.sync { () -> (samples: [Float], version: Int, maximumDuration: Int)? in
            guard isStreaming else { return nil }

            let maximumDurationSeconds = config?.maximumRecordingDurationSeconds ?? 600
            let maximumSamples = 16_000 * maximumDurationSeconds
            guard streamingSamples.count + frameCount <= maximumSamples else {
                isStreaming = false
                return ([], -2, maximumDurationSeconds)
            }

            let incoming = Array(UnsafeBufferPointer(start: buffer, count: frameCount))
            streamingSamples.append(contentsOf: incoming)

            let partialThreshold = minimumSamplesForPartial(for: config)
            guard config?.backend != .nemoSpeech,
                  streamingSamples.count >= partialThreshold,
                  !isDecodingPartial else {
                return ([], -1, maximumDurationSeconds)
            }

            isDecodingPartial = true
            decodeVersion += 1
            if streamingSamples.count > maxPartialDecodeWindowSamples {
                let partialSlice = streamingSamples.suffix(maxPartialDecodeWindowSamples)
                return (Array(partialSlice), decodeVersion, maximumDurationSeconds)
            }
            return (streamingSamples, decodeVersion, maximumDurationSeconds)
        }

        guard let schedule else {
            throw WhisperEngineError.engineNotRunning
        }

        if schedule.version == -2 {
            throw WhisperEngineError.recordingDurationExceeded(seconds: schedule.maximumDuration)
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

        let finalConfig = makeFinalDecodeConfig(from: snapshot.1)
        emitDebug(
            "engine.stopStreaming samples=\(snapshot.0.count) beamLive=\(snapshot.1.beamSize) beamFinal=\(finalConfig.beamSize) chunkLive=\(snapshot.1.chunkMilliseconds) chunkFinal=\(finalConfig.chunkMilliseconds)"
        )
        let final = try transcribe(
            samples: snapshot.0,
            config: finalConfig,
            modelPath: snapshot.2,
            cliPath: snapshot.3
        )
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

        if config.backend == .nemoSpeech {
            return try transcribeNemoSpeech(wavURL: url, cliPath: cliPath)
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

    private func transcribeNemoSpeech(wavURL: URL, cliPath: URL) throws -> FinalTranscript {
        NemoRuntimeAccess.lock.lock()
        defer { NemoRuntimeAccess.lock.unlock() }
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("nemo-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: outputURL) }
        let process = Process()
        process.executableURL = cliPath
        process.arguments = ["transcribe", wavURL.path, "--model", modelPath?.path ?? "", "--language", config?.languageHint ?? "auto", "--json"]
        let errorPipe = Pipe()
        let outputPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = outputPipe
        try process.run()
        let outputSemaphore = DispatchSemaphore(value: 0)
        let errorSemaphore = DispatchSemaphore(value: 0)
        let readQueue = DispatchQueue.global(qos: .userInitiated)
        let outputDataLock = NSLock()
        let errorDataLock = NSLock()
        var outputData = Data()
        var errorData = Data()
        readQueue.async {
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            outputDataLock.lock()
            outputData = data
            outputDataLock.unlock()
            outputSemaphore.signal()
        }
        readQueue.async {
            let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
            errorDataLock.lock()
            errorData = data
            errorDataLock.unlock()
            errorSemaphore.signal()
        }
        process.waitUntilExit()
        outputSemaphore.wait()
        errorSemaphore.wait()
        errorDataLock.lock()
        let errorText = String(data: errorData, encoding: .utf8) ?? ""
        errorDataLock.unlock()
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "NemoSpeech", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "nemo-speech transcribe failed: \(errorText)"])
        }
        outputDataLock.lock()
        let data = outputData
        outputDataLock.unlock()
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        let text = root["text"] as? String ?? ""
        let language = root["language"] as? String
        let segments = (root["segments"] as? [[String: Any]] ?? []).compactMap { item -> FinalSegment? in
            guard let segmentText = item["text"] as? String else { return nil }
            return FinalSegment(text: segmentText, startTime: item["start"] as? Double ?? 0, endTime: item["end"] as? Double ?? 0)
        }
        let transcript = FinalTranscript(text: text, segments: segments, language: language)
        for segment in segments { onFinalSegment?(segment) }
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

        if config.backend == .nemoSpeech {
            return try transcribeNemoSpeech(wavURL: wavURL, cliPath: cliPath)
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

    private func makeFinalDecodeConfig(from baseConfig: ASRConfig) -> ASRConfig {
        let boostedBeam = max(baseConfig.beamSize, baseConfig.latencyProfile == .streaming ? 3 : 5)
        let boostedChunk = max(
            baseConfig.chunkMilliseconds,
            baseConfig.latencyProfile == .streaming ? 420 : 560
        )

        return ASRConfig(
            languageHint: baseConfig.languageHint,
            initialPrompt: baseConfig.initialPrompt,
            translationMode: baseConfig.translationMode,
            modelID: baseConfig.modelID,
            backend: baseConfig.backend,
            latencyProfile: .quality,
            threadCount: baseConfig.threadCount,
            beamSize: boostedBeam,
            chunkMilliseconds: boostedChunk
        )
    }

    private func makeTempDirectory(prefix: String) throws -> URL {
        let base = FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("\(prefix)_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
