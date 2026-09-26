#if canImport(XCTest)
import ASRCore
import XCTest

final class ParakeetIntegrationSmokeTests: XCTestCase {
    func testParakeetRuntimeTranscribesSynthesizedAudio() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard let audioPath = environment["CORTEXA_PARAKEET_SMOKE_AUDIO"] else {
            throw XCTSkip("Set CORTEXA_PARAKEET_SMOKE_AUDIO to a 16 kHz mono WAV file.")
        }

        let installer = VoiceModelInstaller()
        let cliURL: URL
        if let suppliedCLI = environment["CORTEXA_PARAKEET_SMOKE_CLI"] {
            cliURL = URL(fileURLWithPath: suppliedCLI)
        } else {
            cliURL = try await installer.installNemoRuntime()
        }

        let modelURL: URL
        if let suppliedModel = environment["CORTEXA_PARAKEET_SMOKE_MODEL"] {
            modelURL = URL(fileURLWithPath: suppliedModel)
        } else {
            let descriptor = try XCTUnwrap(LocalVoiceModelCatalog.model(id: "parakeet.multilingual"))
            _ = try await installer.install(descriptor)
            modelURL = try VoiceModelInstaller.parakeetModelURL(fileName: XCTUnwrap(descriptor.localFileName))
        }

        let engine = WhisperCppEngine(nemoSpeechCLIPath: cliURL)
        let audioURL = URL(fileURLWithPath: audioPath)
        let config = ASRConfig(
            languageHint: "auto",
            modelID: "parakeet.multilingual",
            backend: .nemoSpeech,
            maximumRecordingDurationSeconds: 24 * 60,
            latencyProfile: .quality
        )

        try engine.loadModel(at: modelURL, config: config)
        let transcript = try await engine.transcribeFile(url: audioURL)
        let normalizedTranscript = transcript.text.lowercased()

        XCTAssertFalse(transcript.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        XCTAssertTrue(
            normalizedTranscript.contains("speech")
                || normalizedTranscript.contains("recognition")
                || normalizedTranscript.contains("cortexa"),
            "Parakeet returned text, but none of the expected smoke-phrase words were recognized: \(transcript.text)"
        )
    }
}
#endif
