import ASRCore
import Foundation

#if canImport(AVFoundation)
import AVFoundation

public enum AudioCaptureError: Error {
    case engineUnavailable
    case conversionFailed
    case permissionDenied
}

public final class AVAudioCaptureService: AudioCapture {
    public var onChunk: ((AudioChunk) -> Void)?
    public var onInterruption: ((AudioInterruptionEvent) -> Void)?

    private let engine = AVAudioEngine()
    private var converter: AVAudioConverter?
    private let outputFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false)
    private let queue = DispatchQueue(label: "wispr.audio.capture")

    public init() {}

    public func requestPermissions() async -> Bool {
        #if os(macOS)
        return await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
        #else
        return await withCheckedContinuation { continuation in
            if #available(iOS 17, tvOS 17, watchOS 10, macCatalyst 17, *) {
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
        #endif
    }

    public func start() throws {
        let input = engine.inputNode
        let inputFormat = input.inputFormat(forBus: 0)

        guard let outputFormat else {
            throw AudioCaptureError.engineUnavailable
        }

        converter = AVAudioConverter(from: inputFormat, to: outputFormat)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            self?.queue.async {
                self?.handleInput(buffer: buffer, inputFormat: inputFormat, outputFormat: outputFormat)
            }
        }

        engine.prepare()
        try engine.start()
    }

    public func stop() throws {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
    }

    private func handleInput(buffer: AVAudioPCMBuffer, inputFormat: AVAudioFormat, outputFormat: AVAudioFormat) {
        guard let converter else { return }

        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * outputFormat.sampleRate) / inputFormat.sampleRate) + 64
        guard let converted = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else {
            onInterruption?(.began(reason: "Failed to allocate converted audio buffer"))
            return
        }

        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        let status = converter.convert(to: converted, error: &error, withInputFrom: inputBlock)
        guard status != .error, error == nil else {
            onInterruption?(.began(reason: "Audio conversion failed"))
            return
        }

        guard let channelData = converted.floatChannelData?.pointee else {
            onInterruption?(.began(reason: "Missing channel data"))
            return
        }

        let frameLength = Int(converted.frameLength)
        let values = Array(UnsafeBufferPointer(start: channelData, count: frameLength))
        let chunk = AudioChunk(pcm16kMonoFloat: values, sampleRate: 16_000, channelCount: 1, frameCount: frameLength)
        onChunk?(chunk)
    }
}

#else

public final class AVAudioCaptureService: AudioCapture {
    public var onChunk: ((AudioChunk) -> Void)?
    public var onInterruption: ((AudioInterruptionEvent) -> Void)?

    public init() {}

    public func requestPermissions() async -> Bool { false }
    public func start() throws {
        throw NSError(domain: "AudioCore", code: 1, userInfo: [NSLocalizedDescriptionKey: "AVFoundation unavailable"]) 
    }
    public func stop() throws {}
}

#endif
