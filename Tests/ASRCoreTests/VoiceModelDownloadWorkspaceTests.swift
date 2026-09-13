#if canImport(XCTest)
import Foundation
import XCTest
@testable import ASRCore

final class VoiceModelDownloadWorkspaceTests: XCTestCase {
    func testCleanupRemovesInterruptedDownloadArtifactsWithoutTouchingInstalledModels() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent(
            "voice_model_workspace_cleanup_\(UUID().uuidString)",
            isDirectory: true
        )
        let temporaryDirectory = root.appendingPathComponent("temporary", isDirectory: true)
        let modelsDirectory = root.appendingPathComponent("models", isDirectory: true)
        let interruptedDirectory = temporaryDirectory.appendingPathComponent(
            "cortexa-voice-model-download-interrupted",
            isDirectory: true
        )
        let legacyDirectory = temporaryDirectory.appendingPathComponent(
            "voice-model-download-legacy",
            isDirectory: true
        )
        let unrelatedDirectory = temporaryDirectory.appendingPathComponent(
            "unrelated-download",
            isDirectory: true
        )
        let partialModel = modelsDirectory.appendingPathComponent(
            ".cortexa-model-download-ggml-small.bin.partial"
        )
        let installedModel = modelsDirectory.appendingPathComponent("ggml-base.bin")

        defer { try? fileManager.removeItem(at: root) }

        try fileManager.createDirectory(at: interruptedDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: legacyDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: unrelatedDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        try Data("interrupted".utf8).write(to: partialModel)
        try Data("installed".utf8).write(to: installedModel)

        try VoiceModelDownloadWorkspace.removeInterruptedArtifacts(
            in: modelsDirectory,
            temporaryDirectoryURL: temporaryDirectory,
            fileManager: fileManager
        )

        XCTAssertFalse(fileManager.fileExists(atPath: interruptedDirectory.path))
        XCTAssertFalse(fileManager.fileExists(atPath: legacyDirectory.path))
        XCTAssertFalse(fileManager.fileExists(atPath: partialModel.path))
        XCTAssertTrue(fileManager.fileExists(atPath: unrelatedDirectory.path))
        XCTAssertEqual(try Data(contentsOf: installedModel), Data("installed".utf8))
    }

    func testInstallDownloadedModelAtomicallyPromotesStagingFile() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent(
            "voice_model_workspace_promotion_\(UUID().uuidString)",
            isDirectory: true
        )
        let downloadsDirectory = root.appendingPathComponent("downloads", isDirectory: true)
        let modelsDirectory = root.appendingPathComponent("models", isDirectory: true)
        let downloadedModel = downloadsDirectory.appendingPathComponent("ggml-small.bin")
        let targetModel = modelsDirectory.appendingPathComponent("ggml-small.bin")
        let stagingModel = modelsDirectory.appendingPathComponent(
            ".cortexa-model-download-ggml-small.bin.partial"
        )

        defer { try? fileManager.removeItem(at: root) }

        try fileManager.createDirectory(at: downloadsDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        try Data("complete-model".utf8).write(to: downloadedModel)

        try VoiceModelDownloadWorkspace.installDownloadedModel(
            from: downloadedModel,
            named: "ggml-small.bin",
            in: modelsDirectory,
            fileManager: fileManager
        )

        XCTAssertEqual(try Data(contentsOf: targetModel), Data("complete-model".utf8))
        XCTAssertFalse(fileManager.fileExists(atPath: stagingModel.path))
    }

    func testInstallDownloadedModelAtomicallyReplacesAnExistingCompleteModel() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent(
            "voice_model_workspace_replace_\(UUID().uuidString)",
            isDirectory: true
        )
        let downloadsDirectory = root.appendingPathComponent("downloads", isDirectory: true)
        let modelsDirectory = root.appendingPathComponent("models", isDirectory: true)
        let downloadedModel = downloadsDirectory.appendingPathComponent("ggml-small.bin")
        let targetModel = modelsDirectory.appendingPathComponent("ggml-small.bin")
        let stagingModel = modelsDirectory.appendingPathComponent(
            ".cortexa-model-download-ggml-small.bin.partial"
        )

        defer { try? fileManager.removeItem(at: root) }

        try fileManager.createDirectory(at: downloadsDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        try Data("new-complete-model".utf8).write(to: downloadedModel)
        try Data("previous-complete-model".utf8).write(to: targetModel)

        try VoiceModelDownloadWorkspace.installDownloadedModel(
            from: downloadedModel,
            named: "ggml-small.bin",
            in: modelsDirectory,
            fileManager: fileManager
        )

        XCTAssertEqual(try Data(contentsOf: targetModel), Data("new-complete-model".utf8))
        XCTAssertFalse(fileManager.fileExists(atPath: stagingModel.path))
    }

    func testFailedStagingPreservesExistingInstalledModel() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent(
            "voice_model_workspace_failure_\(UUID().uuidString)",
            isDirectory: true
        )
        let modelsDirectory = root.appendingPathComponent("models", isDirectory: true)
        let missingDownload = root.appendingPathComponent("downloads/missing.bin")
        let targetModel = modelsDirectory.appendingPathComponent("ggml-small.bin")
        let stagingModel = modelsDirectory.appendingPathComponent(
            ".cortexa-model-download-ggml-small.bin.partial"
        )

        defer { try? fileManager.removeItem(at: root) }

        try fileManager.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        try Data("previous-complete-model".utf8).write(to: targetModel)
        try Data("interrupted-staging-model".utf8).write(to: stagingModel)

        XCTAssertThrowsError(
            try VoiceModelDownloadWorkspace.installDownloadedModel(
                from: missingDownload,
                named: "ggml-small.bin",
                in: modelsDirectory,
                fileManager: fileManager
            )
        )

        XCTAssertEqual(try Data(contentsOf: targetModel), Data("previous-complete-model".utf8))
        XCTAssertFalse(fileManager.fileExists(atPath: stagingModel.path))
    }
}
#endif
