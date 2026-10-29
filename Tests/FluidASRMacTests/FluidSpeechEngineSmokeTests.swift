#if os(macOS)
import AVFoundation
import ASRCore
import FluidAudio
import XCTest
@testable import FluidASRMac

final class FluidSpeechEngineSmokeTests: XCTestCase {
    func testUnknownModelIDIsRejectedInsteadOfSelectingRedux() {
        let engine = FluidSpeechEngine()
        let config = ASRConfig(
            languageHint: "en",
            modelID: "unrecognized.phonon-compatible",
            backend: .fluidAudio,
            latencyProfile: .quality
        )

        XCTAssertThrowsError(try engine.loadModel(at: URL(fileURLWithPath: "/missing"), config: config)) {
            guard case WhisperEngineError.modelNotLoaded = $0 else {
                XCTFail("Expected an explicit rejection for an unknown native model ID.")
                return
            }
        }
    }

    func testOverlappingWindowsCommitEachWordOnlyOnce() {
        let first = makeStreamingWindowUpdate(words: [
            WordTiming(word: "one", startTime: 0.2, endTime: 0.5),
            WordTiming(word: "two", startTime: 10.8, endTime: 11.3),
            WordTiming(word: "three", startTime: 11.4, endTime: 12.2),
            WordTiming(word: "four", startTime: 13, endTime: 13.5),
        ], committed: [], baseTime: 0)
        let second = makeStreamingWindowUpdate(words: [
            WordTiming(word: "two", startTime: 11.3, endTime: 11.6),
            WordTiming(word: "three", startTime: 11.7, endTime: 12.2),
            WordTiming(word: "two", startTime: 12.3, endTime: 12.6),
            WordTiming(word: "four", startTime: 13, endTime: 13.5),
            WordTiming(word: "five", startTime: 23, endTime: 23.4),
        ], committed: first.committed, baseTime: Double(first.offset) / 16_000)

        XCTAssertEqual(first.committed.map(\.word), ["one", "two"])
        XCTAssertEqual(first.mutable.map(\.word), ["three", "four"])
        XCTAssertEqual(second.committed.map(\.word), ["one", "two", "three", "two", "four"])
        XCTAssertEqual(second.mutable.map(\.word), ["five"])
    }

    func testBothManagedModelsTranscribeThirtyMinuteRecordingOffline() async throws {
        guard let audio = ProcessInfo.processInfo.environment["CORTEXA_NATIVE_LONG_SMOKE_AUDIO"] else {
            throw XCTSkip("Provide a 30-minute 16-kHz mono WAV to verify long recording transcription.")
        }
        let file = try AVAudioFile(forReading: URL(fileURLWithPath: audio))
        XCTAssertEqual(file.processingFormat.sampleRate, 16_000)
        XCTAssertEqual(file.processingFormat.channelCount, 1)
        let duration = Double(file.length) / file.processingFormat.sampleRate
        XCTAssertGreaterThanOrEqual(duration, 1_800)
        for modelID in ["fermion.phonon2", "moondream.parakeet-redux"] {
            let manifest = try NativeVoiceModelBundle.manifest(modelID: modelID)
            let root = try XCTUnwrap(ProcessInfo.processInfo.environment["CORTEXA_NATIVE_SMOKE_MODEL_ROOT"])
            let url = URL(fileURLWithPath: root).appendingPathComponent(manifest.bundleName)
            try manifest.validate(at: url)
            let engine = FluidSpeechEngine()
            let config = ASRConfig(languageHint: "en", initialPrompt: nil, translationMode: .original,
                modelID: modelID, backend: .fluidAudio, latencyProfile: .quality)
            try engine.loadModel(at: url, config: config)
            let transcript = try await engine.transcribeFile(url: URL(fileURLWithPath: audio))
            XCTAssertFalse(transcript.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(transcript.segments.isEmpty)
            XCTAssertLessThanOrEqual(transcript.segments.last?.endTime ?? 0, duration + 1)
        }
    }

    func testReduxTranscribesGermanOffline() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard let audio = environment["CORTEXA_NATIVE_GERMAN_SMOKE_AUDIO"],
              let expected = environment["CORTEXA_NATIVE_GERMAN_SMOKE_EXPECTED"] else {
            throw XCTSkip("Provide a German 16-kHz mono WAV and expected phrase to verify Redux language hinting.")
        }
        let modelID = "moondream.parakeet-redux"
        let manifest = try NativeVoiceModelBundle.manifest(modelID: modelID)
        let url: URL
        if let root = environment["CORTEXA_NATIVE_SMOKE_MODEL_ROOT"] {
            url = URL(fileURLWithPath: root).appendingPathComponent(manifest.bundleName)
        } else {
            url = try VoiceModelInstaller.nativeModelURL(modelID: modelID)
        }
        try manifest.validate(at: url)
        let engine = FluidSpeechEngine()
        let config = ASRConfig(languageHint: "de", initialPrompt: nil, translationMode: .original,
            modelID: modelID, backend: .fluidAudio, latencyProfile: .quality)
        try engine.loadModel(at: url, config: config)

        let transcript = try await engine.transcribeFile(url: URL(fileURLWithPath: audio))
        XCTAssertTrue(transcript.text.localizedCaseInsensitiveContains(expected), transcript.text)
        XCTAssertFalse(transcript.segments.isEmpty)
        XCTAssertEqual(transcript.language, "de")
    }

    func testBothManagedModelsTranscribeAndResetOffline() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard let audio = environment["CORTEXA_NATIVE_SMOKE_AUDIO"],
              let expected = environment["CORTEXA_NATIVE_SMOKE_EXPECTED"] else {
            throw XCTSkip("Provide CORTEXA_NATIVE_SMOKE_AUDIO (English 16-kHz mono WAV) and CORTEXA_NATIVE_SMOKE_EXPECTED.")
        }
        for modelID in ["fermion.phonon2", "moondream.parakeet-redux"] {
            let manifest = try NativeVoiceModelBundle.manifest(modelID: modelID)
            let url: URL
            if let root = environment["CORTEXA_NATIVE_SMOKE_MODEL_ROOT"] {
                url = URL(fileURLWithPath: root).appendingPathComponent(manifest.bundleName)
            } else {
                url = try VoiceModelInstaller.nativeModelURL(modelID: modelID)
            }
            try manifest.validate(at: url)
            let engine = FluidSpeechEngine()
            let config = ASRConfig(languageHint: "en", initialPrompt: nil, translationMode: .original,
                modelID: modelID, backend: .fluidAudio, latencyProfile: .streaming)
            try engine.loadModel(at: url, config: config)
            let transcript = try await engine.transcribeFile(url: URL(fileURLWithPath: audio))
            XCTAssertTrue(transcript.text.localizedCaseInsensitiveContains(expected), transcript.text)
            XCTAssertFalse(transcript.segments.isEmpty)
            for segment in transcript.segments {
                XCTAssertTrue(segment.startTime.isFinite)
                XCTAssertGreaterThanOrEqual(segment.endTime, segment.startTime)
            }
            let file = try AVAudioFile(forReading: URL(fileURLWithPath: audio))
            XCTAssertEqual(file.processingFormat.sampleRate, 16_000)
            XCTAssertEqual(file.processingFormat.channelCount, 1)
            let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)))
            try file.read(into: buffer)
            let samples = try XCTUnwrap(buffer.floatChannelData)[0]
            let live = expectation(description: "Live text for \(modelID)")
            live.assertForOverFulfill = false
            engine.onPartial = { partial in
                if !partial.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { live.fulfill() }
            }
            try engine.startStreaming()
            try engine.pushAudioPCM16kMono(samples, frameCount: Int(buffer.frameLength))
            await fulfillment(of: [live], timeout: 30)
            let final = try await engine.stopStreaming()
            XCTAssertTrue(final.text.localizedCaseInsensitiveContains(expected), final.text)
            XCTAssertFalse(final.segments.isEmpty)
            engine.resetStreaming()
            var warmLatencies: [TimeInterval] = []
            for _ in 0..<21 {
                let firstPartial = expectation(description: "First partial for \(modelID)")
                firstPartial.assertForOverFulfill = false
                engine.onPartial = { partial in
                    if !partial.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        firstPartial.fulfill()
                    }
                }
                try engine.startStreaming()
                let startedAt = Date()
                try engine.pushAudioPCM16kMono(samples, frameCount: min(16_000, Int(buffer.frameLength)))
                await fulfillment(of: [firstPartial], timeout: 2.5)
                let latency = Date().timeIntervalSince(startedAt)
                if warmLatencies.count < 20 { warmLatencies.append(latency) }
                engine.resetStreaming()
            }
            let p95 = warmLatencies.sorted()[Int(ceil(Double(warmLatencies.count) * 0.95)) - 1]
            print("\(modelID) first-partial warm p95: \(String(format: "%.3f", p95))s")
            XCTAssertLessThanOrEqual(p95, 2, "Warm first-partial p95 exceeded two seconds for \(modelID).")
            let stale = expectation(description: "No text after reset for \(modelID)")
            stale.isInverted = true
            engine.onPartial = { _ in stale.fulfill() }
            try engine.startStreaming()
            try engine.pushAudioPCM16kMono(samples, frameCount: Int(buffer.frameLength))
            engine.resetStreaming()
            await fulfillment(of: [stale], timeout: 2)
            try engine.startStreaming()
            engine.resetStreaming()
        }
    }
}
#endif
