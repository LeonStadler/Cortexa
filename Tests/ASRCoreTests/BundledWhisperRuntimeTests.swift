#if canImport(XCTest)
import CryptoKit
import Foundation
import XCTest
@testable import ASRCore

final class BundledWhisperRuntimeTests: XCTestCase {
    #if os(macOS)
    func testValidateRuntimeCLIRejectsLaunchFailure() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(
            "runtime_probe_test_\(UUID().uuidString)",
            isDirectory: true
        )
        let cliURL = root.appendingPathComponent("whisper-cli")

        defer { try? fm.removeItem(at: root) }

        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("#!/bin/sh\necho 'Library not loaded: @rpath/libwhisper.1.dylib' >&2\nexit 6\n".utf8)
            .write(to: cliURL)
        try fm.setAttributes(
            [.posixPermissions: NSNumber(value: 0o755)],
            ofItemAtPath: cliURL.path
        )

        XCTAssertThrowsError(
            try BundledWhisperRuntimeInstaller.validateRuntimeCLI(at: cliURL, timeout: 2)
        ) { error in
            guard case let BundledWhisperRuntimeError.cliLaunchProbeFailed(
                failedURL,
                status,
                reason
            ) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(failedURL, cliURL)
            XCTAssertEqual(status, 6)
            XCTAssertTrue(reason.contains("@rpath/libwhisper.1.dylib"))
        }
    }
    #endif

    func testBundledRuntimeDirectorySupportsFlatResourceLayout() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("runtime_flat_test_\(UUID().uuidString)")
        let resources = root.appendingPathComponent("Resources", isDirectory: true)
        let models = resources.appendingPathComponent("models", isDirectory: true)

        defer { try? fm.removeItem(at: root) }

        try fm.createDirectory(at: models, withIntermediateDirectories: true)
        try Data("#!/bin/sh\necho test\n".utf8).write(to: resources.appendingPathComponent("whisper-cli"))
        try Data([0x01]).write(to: models.appendingPathComponent("ggml-base.bin"))

        let bundle = Bundle(url: root)!
        let detected = BundledWhisperRuntimeInstaller.bundledRuntimeDirectory(in: bundle)

        XCTAssertEqual(detected?.standardizedFileURL, resources.standardizedFileURL)
    }

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
        XCTAssertEqual(runtime.defaultModelFileName, "ggml-base.bin")
        XCTAssertEqual(runtime.availableModelFileNames, ["ggml-base.bin"])
    }

    func testInstallRuntimeFallsBackToAvailableModelWhenBaseModelMissing() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("runtime_fallback_test_\(UUID().uuidString)")
        let sourceRuntime = root.appendingPathComponent("source/Runtime", isDirectory: true)
        let sourceModels = sourceRuntime.appendingPathComponent("models", isDirectory: true)
        let destinationRuntime = root.appendingPathComponent("destination/Runtime", isDirectory: true)

        defer { try? fm.removeItem(at: root) }

        try fm.createDirectory(at: sourceModels, withIntermediateDirectories: true)
        try Data("#!/bin/sh\necho test\n".utf8).write(to: sourceRuntime.appendingPathComponent("whisper-cli"))
        try Data([0x01]).write(to: sourceModels.appendingPathComponent("ggml-small.bin"))

        let runtime = try BundledWhisperRuntimeInstaller.installRuntime(
            from: sourceRuntime,
            destinationRuntimeDirectory: destinationRuntime,
            appName: "WisprLocalTest"
        )

        XCTAssertEqual(runtime.defaultModelFileName, "ggml-small.bin")
        XCTAssertEqual(runtime.availableModelFileNames, ["ggml-small.bin"])
    }

    func testInstallRuntimeUsesManifestDefaultModelWhenPresent() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("runtime_manifest_test_\(UUID().uuidString)")
        let sourceRuntime = root.appendingPathComponent("source/Runtime", isDirectory: true)
        let sourceModels = sourceRuntime.appendingPathComponent("models", isDirectory: true)
        let destinationRuntime = root.appendingPathComponent("destination/Runtime", isDirectory: true)
        let destinationModels = destinationRuntime.appendingPathComponent("models", isDirectory: true)

        defer { try? fm.removeItem(at: root) }

        try fm.createDirectory(at: sourceModels, withIntermediateDirectories: true)
        try Data("#!/bin/sh\necho test\n".utf8).write(to: sourceRuntime.appendingPathComponent("whisper-cli"))
        try Data([0x01]).write(to: sourceModels.appendingPathComponent("ggml-base.bin"))
        try Data([0x02]).write(to: sourceModels.appendingPathComponent("ggml-small.bin"))

        let manifest = BundledWhisperRuntimeManifest(
            defaultModelFileName: "ggml-small.bin",
            modelFileNames: ["ggml-base.bin", "ggml-small.bin"]
        )
        let manifestData = try JSONEncoder().encode(manifest)
        try manifestData.write(to: sourceRuntime.appendingPathComponent("runtime-manifest.json"))

        let runtime = try BundledWhisperRuntimeInstaller.installRuntime(
            from: sourceRuntime,
            destinationRuntimeDirectory: destinationRuntime,
            appName: "WisprLocalTest"
        )

        XCTAssertEqual(runtime.defaultModelFileName, "ggml-small.bin")
        XCTAssertEqual(runtime.manifest, manifest)
        XCTAssertTrue(fm.fileExists(atPath: destinationRuntime.appendingPathComponent("runtime-manifest.json").path))
        XCTAssertTrue(fm.fileExists(atPath: destinationModels.appendingPathComponent("ggml-base.bin").path))
        XCTAssertTrue(fm.fileExists(atPath: destinationModels.appendingPathComponent("ggml-small.bin").path))
    }

    func testInstallRuntimeOnlySyncsDefaultModelWhenExtraModelsPresentWithoutManifest() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("runtime_default_only_test_\(UUID().uuidString)")
        let sourceRuntime = root.appendingPathComponent("source/Runtime", isDirectory: true)
        let sourceModels = sourceRuntime.appendingPathComponent("models", isDirectory: true)
        let destinationRuntime = root.appendingPathComponent("destination/Runtime", isDirectory: true)
        let destinationModels = destinationRuntime.appendingPathComponent("models", isDirectory: true)

        defer { try? fm.removeItem(at: root) }

        try fm.createDirectory(at: sourceModels, withIntermediateDirectories: true)
        try Data("#!/bin/sh\necho test\n".utf8).write(to: sourceRuntime.appendingPathComponent("whisper-cli"))
        try Data([0x01]).write(to: sourceModels.appendingPathComponent("ggml-base.bin"))
        try Data([0x02]).write(to: sourceModels.appendingPathComponent("ggml-small.bin"))

        let runtime = try BundledWhisperRuntimeInstaller.installRuntime(
            from: sourceRuntime,
            destinationRuntimeDirectory: destinationRuntime,
            appName: "WisprLocalTest"
        )

        XCTAssertEqual(runtime.defaultModelFileName, "ggml-base.bin")
        XCTAssertEqual(runtime.availableModelFileNames, ["ggml-base.bin"])
        XCTAssertTrue(fm.fileExists(atPath: destinationModels.appendingPathComponent("ggml-base.bin").path))
        XCTAssertFalse(fm.fileExists(atPath: destinationModels.appendingPathComponent("ggml-small.bin").path))
    }

    func testInstallRuntimeSkipsSuppressedBundledModelAndRemovesExistingCopy() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("runtime_suppressed_test_\(UUID().uuidString)")
        let sourceRuntime = root.appendingPathComponent("source/Runtime", isDirectory: true)
        let sourceModels = sourceRuntime.appendingPathComponent("models", isDirectory: true)
        let destinationRuntime = root.appendingPathComponent("destination/Runtime", isDirectory: true)
        let destinationModels = destinationRuntime.appendingPathComponent("models", isDirectory: true)

        defer { try? fm.removeItem(at: root) }

        try fm.createDirectory(at: sourceModels, withIntermediateDirectories: true)
        try fm.createDirectory(at: destinationModels, withIntermediateDirectories: true)
        try Data("#!/bin/sh\necho test\n".utf8).write(to: sourceRuntime.appendingPathComponent("whisper-cli"))
        try Data([0x01]).write(to: sourceModels.appendingPathComponent("ggml-base.bin"))
        try Data([0x02]).write(to: sourceModels.appendingPathComponent("ggml-small.bin"))
        try Data([0x99]).write(to: destinationModels.appendingPathComponent("ggml-small.bin"))

        let manifest = BundledWhisperRuntimeManifest(
            defaultModelFileName: "ggml-base.bin",
            modelFileNames: ["ggml-base.bin", "ggml-small.bin"]
        )
        try JSONEncoder().encode(manifest).write(to: sourceRuntime.appendingPathComponent("runtime-manifest.json"))

        let runtime = try BundledWhisperRuntimeInstaller.installRuntime(
            from: sourceRuntime,
            destinationRuntimeDirectory: destinationRuntime,
            appName: "WisprLocalTest",
            suppressedBundledModelFileNames: ["ggml-small.bin"]
        )

        XCTAssertEqual(runtime.availableModelFileNames, ["ggml-base.bin"])
        XCTAssertFalse(fm.fileExists(atPath: destinationModels.appendingPathComponent("ggml-small.bin").path))
    }

    func testInstallRuntimeVerifiesManifestChecksumsWhenPresent() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("runtime_checksum_test_\(UUID().uuidString)")
        let sourceRuntime = root.appendingPathComponent("source/Runtime", isDirectory: true)
        let sourceModels = sourceRuntime.appendingPathComponent("models", isDirectory: true)
        let destinationRuntime = root.appendingPathComponent("destination/Runtime", isDirectory: true)

        defer { try? fm.removeItem(at: root) }

        try fm.createDirectory(at: sourceModels, withIntermediateDirectories: true)

        let sourceCLI = sourceRuntime.appendingPathComponent("whisper-cli")
        let cliData = Data("#!/bin/sh\necho test\n".utf8)
        try cliData.write(to: sourceCLI)

        let modelData = Data([0x01, 0x02, 0x03, 0x04])
        let modelFile = sourceModels.appendingPathComponent("ggml-base.bin")
        try modelData.write(to: modelFile)

        let manifest = BundledWhisperRuntimeManifest(
            defaultModelFileName: "ggml-base.bin",
            modelFileNames: ["ggml-base.bin"],
            cliChecksumSHA256: sha256Hex(of: cliData),
            modelChecksumsSHA256: ["ggml-base.bin": sha256Hex(of: modelData)]
        )
        try JSONEncoder().encode(manifest).write(to: sourceRuntime.appendingPathComponent("runtime-manifest.json"))

        let runtime = try BundledWhisperRuntimeInstaller.installRuntime(
            from: sourceRuntime,
            destinationRuntimeDirectory: destinationRuntime,
            appName: "WisprLocalTest"
        )

        XCTAssertEqual(runtime.defaultModelFileName, "ggml-base.bin")
        XCTAssertEqual(runtime.manifest, manifest)
        XCTAssertTrue(fm.fileExists(atPath: destinationRuntime.appendingPathComponent("runtime-manifest.json").path))
    }

    func testInstallRuntimeRejectsManifestModelListMismatch() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("runtime_model_list_mismatch_test_\(UUID().uuidString)")
        let sourceRuntime = root.appendingPathComponent("source/Runtime", isDirectory: true)
        let sourceModels = sourceRuntime.appendingPathComponent("models", isDirectory: true)

        defer { try? fm.removeItem(at: root) }

        try fm.createDirectory(at: sourceModels, withIntermediateDirectories: true)
        try Data("#!/bin/sh\necho test\n".utf8).write(to: sourceRuntime.appendingPathComponent("whisper-cli"))
        try Data([0x01]).write(to: sourceModels.appendingPathComponent("ggml-base.bin"))

        let manifest = BundledWhisperRuntimeManifest(
            defaultModelFileName: "ggml-base.bin",
            modelFileNames: ["ggml-base.bin", "ggml-small.bin"]
        )
        try JSONEncoder().encode(manifest).write(to: sourceRuntime.appendingPathComponent("runtime-manifest.json"))

        XCTAssertThrowsError(
            try BundledWhisperRuntimeInstaller.installRuntime(from: sourceRuntime, appName: "WisprLocalTest")
        ) { error in
            guard case BundledWhisperRuntimeError.manifestModelFileNamesMismatch(_, _, _) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testInstallRuntimeRejectsManifestDefaultThatDoesNotExist() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("runtime_invalid_manifest_test_\(UUID().uuidString)")
        let sourceRuntime = root.appendingPathComponent("source/Runtime", isDirectory: true)
        let sourceModels = sourceRuntime.appendingPathComponent("models", isDirectory: true)

        defer { try? fm.removeItem(at: root) }

        try fm.createDirectory(at: sourceModels, withIntermediateDirectories: true)
        try Data("#!/bin/sh\necho test\n".utf8).write(to: sourceRuntime.appendingPathComponent("whisper-cli"))
        try Data([0x01]).write(to: sourceModels.appendingPathComponent("ggml-small.bin"))

        let manifest = BundledWhisperRuntimeManifest(defaultModelFileName: "ggml-base.bin")
        try JSONEncoder().encode(manifest).write(to: sourceRuntime.appendingPathComponent("runtime-manifest.json"))

        XCTAssertThrowsError(
            try BundledWhisperRuntimeInstaller.installRuntime(from: sourceRuntime, appName: "WisprLocalTest")
        ) { error in
            guard case BundledWhisperRuntimeError.manifestDefaultModelMissing = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testInstallRuntimeRejectsManifestChecksumMismatch() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("runtime_checksum_mismatch_test_\(UUID().uuidString)")
        let sourceRuntime = root.appendingPathComponent("source/Runtime", isDirectory: true)
        let sourceModels = sourceRuntime.appendingPathComponent("models", isDirectory: true)

        defer { try? fm.removeItem(at: root) }

        try fm.createDirectory(at: sourceModels, withIntermediateDirectories: true)
        try Data("#!/bin/sh\necho test\n".utf8).write(to: sourceRuntime.appendingPathComponent("whisper-cli"))
        try Data([0x01, 0x02, 0x03]).write(to: sourceModels.appendingPathComponent("ggml-base.bin"))

        let manifest = BundledWhisperRuntimeManifest(
            defaultModelFileName: "ggml-base.bin",
            modelFileNames: ["ggml-base.bin"],
            modelChecksumsSHA256: ["ggml-base.bin": "deadbeef"]
        )
        try JSONEncoder().encode(manifest).write(to: sourceRuntime.appendingPathComponent("runtime-manifest.json"))

        XCTAssertThrowsError(
            try BundledWhisperRuntimeInstaller.installRuntime(from: sourceRuntime, appName: "WisprLocalTest")
        ) { error in
            guard case BundledWhisperRuntimeError.manifestChecksumMismatch(_, _) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testInstallRuntimeCLIOnlySyncsCLIWithoutBundledModels() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("runtime_cli_only_test_\(UUID().uuidString)")
        let sourceRuntime = root.appendingPathComponent("source/Runtime", isDirectory: true)
        let sourceModels = sourceRuntime.appendingPathComponent("models", isDirectory: true)
        let destinationRuntime = root.appendingPathComponent("destination/Runtime", isDirectory: true)
        let destinationModels = destinationRuntime.appendingPathComponent("models", isDirectory: true)

        defer { try? fm.removeItem(at: root) }

        try fm.createDirectory(at: sourceModels, withIntermediateDirectories: true)
        try fm.createDirectory(at: destinationModels, withIntermediateDirectories: true)
        try Data("#!/bin/sh\necho test\n".utf8).write(to: sourceRuntime.appendingPathComponent("whisper-cli"))

        let manifest = BundledWhisperRuntimeManifest(
            defaultModelFileName: "ggml-base.bin",
            modelFileNames: []
        )
        try JSONEncoder().encode(manifest).write(to: sourceRuntime.appendingPathComponent("runtime-manifest.json"))
        try Data([0x99]).write(to: destinationModels.appendingPathComponent("ggml-base.bin"))

        let runtime = try BundledWhisperRuntimeInstaller.installRuntime(
            from: sourceRuntime,
            destinationRuntimeDirectory: destinationRuntime,
            appName: "WisprLocalTest",
            syncModels: false
        )

        XCTAssertTrue(fm.fileExists(atPath: runtime.cliURL.path))
        XCTAssertEqual(runtime.defaultModelFileName, "ggml-base.bin")
        XCTAssertEqual(runtime.availableModelFileNames, ["ggml-base.bin"])
        XCTAssertFalse(fm.fileExists(atPath: sourceModels.appendingPathComponent("ggml-base.bin").path))
    }

    func testInstallRuntimePrunesStaleDestinationModels() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("runtime_prune_test_\(UUID().uuidString)")
        let sourceRuntime = root.appendingPathComponent("source/Runtime", isDirectory: true)
        let sourceModels = sourceRuntime.appendingPathComponent("models", isDirectory: true)
        let destinationRuntime = root.appendingPathComponent("destination/Runtime", isDirectory: true)
        let destinationModels = destinationRuntime.appendingPathComponent("models", isDirectory: true)

        defer { try? fm.removeItem(at: root) }

        try fm.createDirectory(at: sourceModels, withIntermediateDirectories: true)
        try fm.createDirectory(at: destinationModels, withIntermediateDirectories: true)

        try Data("#!/bin/sh\necho test\n".utf8).write(to: sourceRuntime.appendingPathComponent("whisper-cli"))
        try Data([0x01]).write(to: sourceModels.appendingPathComponent("ggml-small.bin"))
        try Data([0x09]).write(to: destinationModels.appendingPathComponent("ggml-old.bin"))
        try Data("stale".utf8).write(to: destinationRuntime.appendingPathComponent("runtime-manifest.json"))

        let runtime = try BundledWhisperRuntimeInstaller.installRuntime(
            from: sourceRuntime,
            destinationRuntimeDirectory: destinationRuntime,
            appName: "WisprLocalTest"
        )

        XCTAssertEqual(runtime.availableModelFileNames, ["ggml-small.bin"])
        XCTAssertFalse(fm.fileExists(atPath: destinationModels.appendingPathComponent("ggml-old.bin").path))
        XCTAssertFalse(fm.fileExists(atPath: destinationRuntime.appendingPathComponent("runtime-manifest.json").path))
    }

    func testInstallBundledRuntimePreservesAdditionalInstalledModelsWhenRequested() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("runtime_preserve_models_test_\(UUID().uuidString)")
        let sourceRuntime = root.appendingPathComponent("source/Runtime", isDirectory: true)
        let sourceModels = sourceRuntime.appendingPathComponent("models", isDirectory: true)
        let destinationRuntime = root.appendingPathComponent("destination/Runtime", isDirectory: true)
        let destinationModels = destinationRuntime.appendingPathComponent("models", isDirectory: true)

        defer { try? fm.removeItem(at: root) }

        try fm.createDirectory(at: sourceModels, withIntermediateDirectories: true)
        try fm.createDirectory(at: destinationModels, withIntermediateDirectories: true)

        try Data("#!/bin/sh\necho test\n".utf8).write(to: sourceRuntime.appendingPathComponent("whisper-cli"))
        try Data([0x01]).write(to: sourceModels.appendingPathComponent("ggml-base.bin"))
        try Data([0x09]).write(to: destinationModels.appendingPathComponent("ggml-large-v3.bin"))

        let runtime = try BundledWhisperRuntimeInstaller.installRuntime(
            from: sourceRuntime,
            destinationRuntimeDirectory: destinationRuntime,
            appName: "WisprLocalTest",
            preserveAdditionalModels: true
        )

        XCTAssertEqual(runtime.availableModelFileNames, ["ggml-base.bin", "ggml-large-v3.bin"])
        XCTAssertTrue(fm.fileExists(atPath: destinationModels.appendingPathComponent("ggml-large-v3.bin").path))
    }

    private func sha256Hex(of data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
#endif
