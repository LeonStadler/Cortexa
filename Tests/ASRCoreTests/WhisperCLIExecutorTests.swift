#if canImport(XCTest)
import Foundation
import XCTest
@testable import ASRCore

final class WhisperCLIExecutorTests: XCTestCase {
    func testBuildArgumentsUseBeamSizeFlag() {
        let arguments = WhisperCLIExecutor.buildArguments(
            modelPath: URL(fileURLWithPath: "/tmp/model.bin"),
            inputWav: URL(fileURLWithPath: "/tmp/input.wav"),
            languageHint: "de",
            translationMode: .original,
            threads: 4,
            beamSize: 5,
            outputBase: URL(fileURLWithPath: "/tmp/result")
        )

        XCTAssertTrue(arguments.contains("-bs"))
        XCTAssertFalse(arguments.contains("-b"))
        XCTAssertTrue(arguments.contains("de"))
    }

    func testBuildArgumentsUseAutoLanguageAndTranslationFlagWhenRequested() {
        let arguments = WhisperCLIExecutor.buildArguments(
            modelPath: URL(fileURLWithPath: "/tmp/model.bin"),
            inputWav: URL(fileURLWithPath: "/tmp/input.wav"),
            languageHint: "auto",
            translationMode: .toEnglish,
            threads: 4,
            beamSize: 2,
            outputBase: URL(fileURLWithPath: "/tmp/result")
        )

        XCTAssertTrue(arguments.contains("-l"))
        XCTAssertTrue(arguments.contains("auto"))
        XCTAssertTrue(arguments.contains("-tr"))
    }

    func testResolveCLIPathPrefersExplicitExecutablePath() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("whisper_cli_explicit_test_\(UUID().uuidString)")
        defer { try? fm.removeItem(at: root) }

        try fm.createDirectory(at: root, withIntermediateDirectories: true)

        let explicitCLI = root.appendingPathComponent("custom-whisper-cli")
        try Data("#!/bin/sh\necho test\n".utf8).write(to: explicitCLI)

        #if os(macOS)
        try fm.setAttributes([.posixPermissions: NSNumber(value: 0o755)], ofItemAtPath: explicitCLI.path)
        #endif

        let modelPath = root.appendingPathComponent("model.bin")
        try Data([0x01]).write(to: modelPath)

        let resolved = WhisperCLIExecutor.resolveCLIPath(explicitPath: explicitCLI, modelPath: modelPath)

        XCTAssertEqual(resolved, explicitCLI)
    }
}
#endif
