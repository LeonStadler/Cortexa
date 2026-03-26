#if canImport(XCTest)
import Foundation
import XCTest
@testable import ASRCore

final class WhisperCppEngineLifecycleTests: XCTestCase {
    func testResetStreamingClearsActiveSessionAndAllowsRestart() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("whisper_engine_lifecycle_\(UUID().uuidString)")
        defer { try? fm.removeItem(at: root) }

        try fm.createDirectory(at: root, withIntermediateDirectories: true)

        let cliURL = root.appendingPathComponent("whisper-cli")
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: cliURL)

        #if os(macOS)
        try fm.setAttributes([.posixPermissions: NSNumber(value: 0o755)], ofItemAtPath: cliURL.path)
        #endif

        let modelURL = root.appendingPathComponent("ggml-base.bin")
        try Data([0x00, 0x01, 0x02]).write(to: modelURL)

        let engine = WhisperCppEngine(cliPath: cliURL)
        try engine.loadModel(
            at: modelURL,
            config: ASRConfig(
                languageHint: "de",
                modelID: "ggml-base.bin",
                backend: .whisperCpp,
                latencyProfile: .streaming
            )
        )

        try engine.startStreaming()
        engine.resetStreaming()

        await XCTAssertThrowsErrorAsync(try await engine.stopStreaming()) { error in
            guard case WhisperEngineError.engineNotRunning = error else {
                return XCTFail("Expected engineNotRunning, got \(error)")
            }
        }

        XCTAssertNoThrow(try engine.startStreaming())
        engine.resetStreaming()
    }
}

private func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    _ errorHandler: (Error) -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("Expected error to be thrown", file: file, line: line)
    } catch {
        errorHandler(error)
    }
}
#endif
