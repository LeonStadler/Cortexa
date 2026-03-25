#if canImport(XCTest)
import Foundation
import XCTest
@testable import ASRCore

final class ModelRegistryTests: XCTestCase {
    func testImportModelRemovesDestinationOnChecksumFailure() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent("model_registry_\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: root) }

        let registry = try ModelRegistry(baseDirectory: root, fileManager: fileManager)
        let source = root.appendingPathComponent("source.bin")
        try Data([0x01, 0x02, 0x03]).write(to: source)

        let metadata = WhisperModelInfo(
            id: "base-q5",
            language: "de",
            quantization: "q5",
            checksumSHA256: String(repeating: "0", count: 64),
            relativePath: "ggml-base-q5.bin"
        )

        XCTAssertThrowsError(try registry.importModel(from: source, metadata: metadata))

        let destination = root.appendingPathComponent("models/ggml-base-q5.bin")
        XCTAssertFalse(fileManager.fileExists(atPath: destination.path))
    }
}
#endif
