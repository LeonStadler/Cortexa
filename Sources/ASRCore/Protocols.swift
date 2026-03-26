import Foundation

public protocol WhisperEngine: AnyObject {
    func loadModel(at path: URL, config: ASRConfig) throws
    func startStreaming() throws
    func pushAudioPCM16kMono(_ buffer: UnsafePointer<Float>, frameCount: Int) throws
    func stopStreaming() async throws -> FinalTranscript
    func resetStreaming()
    func transcribeFile(url: URL) async throws -> FinalTranscript
    var onPartial: ((PartialTranscript) -> Void)? { get set }
    var onFinalSegment: ((FinalSegment) -> Void)? { get set }
}

public protocol AudioCapture: AnyObject {
    func requestPermissions() async -> Bool
    func start() throws
    func stop() throws
    var onChunk: ((AudioChunk) -> Void)? { get set }
    var onInterruption: ((AudioInterruptionEvent) -> Void)? { get set }
}
