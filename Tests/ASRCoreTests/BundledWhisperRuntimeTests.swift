#if canImport(XCTest)
import Foundation
import XCTest
@testable import ASRCore

final class BundledWhisperRuntimeTests: XCTestCase {
    func testInstallRuntimeCopiesCLIAndModels() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("runtime_test_\(UUID().uuidString)")
        let sourceRuntime = root.appendingPathComponent("source/Runtime", isDirectory: true)
        let sourceModels = sourceRuntime.appendingPathComponent("models", isDirectory: true)
        let destinationRuntime = root.appendingPathComponent("destination/Runtime", isDirectory: true)

        defer { try? fm.removeItem(at: root) }

        try fm.createDirectory(at: sourceModels, withIntermediateDirectories: true)

        let sourceCLI = sourceRuntime.appendingPathComponent("whisper-cli")
        try Data("#!/bin/sh\necho test\n".utf8).write(to: sourceCLI)

        #if os(macOS)
        try fm.setAttributes([.posixPermissions: NSNumber(value: 0o755)], ofItemAtPath: sourceCLI.path)
        #endif

        let modelFile = sourceModels.appendingPathComponent("ggml-base.bin")
        try Data([0x01, 0x02, 0x03]).write(to: modelFile)

        let runtime = try BundledWhisperRuntimeInstaller.installRuntime(
            from: sourceRuntime,
            destinationRuntimeDirectory: destinationRuntime,
            appName: "WisprLocalTest"
        )

        XCTAssertTrue(fm.fileExists(atPath: runtime.cliURL.path))
        XCTAssertTrue(fm.fileExists(atPath: runtime.modelsDirectoryURL.appendingPathComponent("ggml-base.bin").path))
        XCTAssertTrue(fm.isExecutableFile(atPath: runtime.cliURL.path))
    }
}
#endif
