import CryptoKit
import Foundation

public struct WhisperModelInfo: Sendable, Codable, Equatable {
    public let id: String
    public let language: String?
    public let quantization: String
    public let checksumSHA256: String
    public let relativePath: String

    public init(id: String, language: String?, quantization: String, checksumSHA256: String, relativePath: String) {
        self.id = id
        self.language = language
        self.quantization = quantization
        self.checksumSHA256 = checksumSHA256
        self.relativePath = relativePath
    }
}

public final class ModelRegistry {
    private let modelsDirectory: URL
    private let indexURL: URL
    private let fileManager: FileManager

    public init(baseDirectory: URL, fileManager: FileManager = .default) throws {
        self.fileManager = fileManager
        self.modelsDirectory = baseDirectory.appendingPathComponent("models", isDirectory: true)
        self.indexURL = modelsDirectory.appendingPathComponent("index.json")

        if !fileManager.fileExists(atPath: modelsDirectory.path) {
            try fileManager.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        }

        if !fileManager.fileExists(atPath: indexURL.path) {
            try Data("[]".utf8).write(to: indexURL)
        }
    }

    public func allModels() throws -> [WhisperModelInfo] {
        let data = try Data(contentsOf: indexURL)
        return try JSONDecoder().decode([WhisperModelInfo].self, from: data)
    }

    public func resolveModelPath(modelID: String) throws -> URL? {
        let model = try allModels().first(where: { $0.id == modelID })
        guard let model else { return nil }
        return modelsDirectory.appendingPathComponent(model.relativePath)
    }

    public func importModel(from sourceURL: URL, metadata: WhisperModelInfo) throws {
        let destination = modelsDirectory.appendingPathComponent(metadata.relativePath)
        let destinationParent = destination.deletingLastPathComponent()

        if !fileManager.fileExists(atPath: destinationParent.path) {
            try fileManager.createDirectory(at: destinationParent, withIntermediateDirectories: true)
        }

        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }

        try fileManager.copyItem(at: sourceURL, to: destination)
        do {
            try validateChecksum(of: destination, expectedSHA256: metadata.checksumSHA256)
        } catch {
            try? fileManager.removeItem(at: destination)
            throw error
        }

        var models = try allModels().filter { $0.id != metadata.id }
        models.append(metadata)

        let data = try JSONEncoder().encode(models.sorted(by: { $0.id < $1.id }))
        try data.write(to: indexURL, options: [.atomic])
    }

    public func validateChecksum(of modelFile: URL, expectedSHA256: String) throws {
        let data = try Data(contentsOf: modelFile)
        let digest = SHA256.hash(data: data)
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        guard hex.lowercased() == expectedSHA256.lowercased() else {
            throw NSError(domain: "ModelRegistry", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Model checksum mismatch"]) 
        }
    }
}
