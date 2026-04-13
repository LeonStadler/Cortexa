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
            initialPrompt: nil,
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
            initialPrompt: nil,
            translationMode: .toEnglish,
            threads: 4,
            beamSize: 2,
            outputBase: URL(fileURLWithPath: "/tmp/result")
        )

        XCTAssertTrue(arguments.contains("-l"))
        XCTAssertTrue(arguments.contains("auto"))
        XCTAssertTrue(arguments.contains("-tr"))
    }

    func testBuildArgumentsAddsPromptWhenProvided() {
        let arguments = WhisperCLIExecutor.buildArguments(
            modelPath: URL(fileURLWithPath: "/tmp/model.bin"),
            inputWav: URL(fileURLWithPath: "/tmp/input.wav"),
            languageHint: "de",
            initialPrompt: "ProductName ACMEClient",
            translationMode: .original,
            threads: 2,
            beamSize: 3,
            outputBase: URL(fileURLWithPath: "/tmp/result")
        )

        guard let promptFlagIndex = arguments.firstIndex(of: "--prompt") else {
            return XCTFail("Expected --prompt flag to be present")
        }
        XCTAssertLessThan(promptFlagIndex, arguments.count - 1)
        XCTAssertEqual(arguments[promptFlagIndex + 1], "ProductName ACMEClient")
    }

    func testBuildArgumentsSkipsPromptWhenOnlyWhitespace() {
        let arguments = WhisperCLIExecutor.buildArguments(
            modelPath: URL(fileURLWithPath: "/tmp/model.bin"),
            inputWav: URL(fileURLWithPath: "/tmp/input.wav"),
            languageHint: "de",
            initialPrompt: "  \n\t   ",
            translationMode: .original,
            threads: 2,
            beamSize: 3,
            outputBase: URL(fileURLWithPath: "/tmp/result")
        )

        XCTAssertFalse(arguments.contains("--prompt"))
    }

    func testBuildArgumentsSanitizesAndTruncatesPrompt() {
        let rawPrompt = "  Kunde:\n\tACME    GmbH   \(String(repeating: "x", count: 700))   "
        let arguments = WhisperCLIExecutor.buildArguments(
            modelPath: URL(fileURLWithPath: "/tmp/model.bin"),
            inputWav: URL(fileURLWithPath: "/tmp/input.wav"),
            languageHint: "de",
            initialPrompt: rawPrompt,
            translationMode: .original,
            threads: 2,
            beamSize: 3,
            outputBase: URL(fileURLWithPath: "/tmp/result")
        )

        guard let promptFlagIndex = arguments.firstIndex(of: "--prompt") else {
            return XCTFail("Expected --prompt flag to be present")
        }

        let sanitizedPrompt = arguments[promptFlagIndex + 1]
        XCTAssertEqual(sanitizedPrompt.count, 500)
        XCTAssertFalse(sanitizedPrompt.hasPrefix(" "))
        XCTAssertFalse(sanitizedPrompt.hasSuffix(" "))
        XCTAssertFalse(sanitizedPrompt.contains("\n"))
        XCTAssertFalse(sanitizedPrompt.contains("\t"))
        XCTAssertFalse(sanitizedPrompt.contains("  "))
        XCTAssertTrue(sanitizedPrompt.hasPrefix("Kunde: ACME GmbH "))
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
