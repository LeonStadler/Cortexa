import CryptoKit
import XCTest
@testable import ASRCore

final class NativeVoiceModelBundleTests: XCTestCase {
    func testPinnedManifestAndCapabilities() throws {
        for manifest in NativeVoiceModelBundle.all {
            XCTAssertEqual(manifest.revision.count, 40)
            XCTAssertGreaterThan(manifest.expectedBytes, 200_000_000)
            XCTAssertEqual(Set(manifest.files.map(\.path)).count, manifest.files.count)
            XCTAssertTrue(manifest.files.allSatisfy { !$0.path.contains("..") && !$0.path.hasPrefix("/") && $0.sha256.count == 64 })
            let descriptor = try XCTUnwrap(LocalVoiceModelCatalog.model(id: manifest.modelID))
            XCTAssertEqual(descriptor.expectedDownloadBytes, manifest.expectedBytes)
            XCTAssertTrue(descriptor.supportsLiveTranscription)
            XCTAssertFalse(descriptor.supportsTranslationToEnglish)
        }
        XCTAssertEqual(LocalVoiceModelCatalog.model(id: "fermion.phonon2")?.supportedLanguageCodes, ["en"])
        XCTAssertTrue(LocalVoiceModelCatalog.model(id: "moondream.parakeet-redux")!.supportedLanguageCodes!.contains("de"))
    }

    func testBundleRejectsMissingCorruptAndWrongSizedFiles() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let bytes = Data("valid".utf8)
        let digest = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        let bundle = NativeVoiceModelBundle(modelID: "test", repository: "test", revision: "test", bundleName: "test", files: [NativeVoiceModelFile(path: "data", bytes: 5, sha256: digest)])
        XCTAssertThrowsError(try bundle.validate(at: directory))
        let file = directory.appendingPathComponent("data")
        try bytes.write(to: file)
        XCTAssertNoThrow(try bundle.validate(at: directory))
        try Data("wrong".utf8).write(to: file)
        XCTAssertThrowsError(try bundle.validate(at: directory))
        try Data("shorter".utf8).write(to: file)
        XCTAssertThrowsError(try bundle.validate(at: directory))
    }
}
