#if canImport(XCTest)
import Foundation
import CryptoKit
import XCTest
@testable import ASRCore

final class NemoSpeechRuntimeManagerTests: XCTestCase {
    func testPinnedArchiveChecksumAcceptsOnlyMatchingBytes() {
        let archive = Data("release archive".utf8)
        let digest = SHA256.hash(data: archive).map { String(format: "%02x", $0) }.joined()

        XCTAssertTrue(NemoSpeechRuntimeManager.archiveMatchesChecksum(archive, expectedSHA256: digest))
        XCTAssertFalse(NemoSpeechRuntimeManager.archiveMatchesChecksum(archive, expectedSHA256: String(repeating: "0", count: 64)))
    }

    func testArchivePathValidationRejectsTraversalAndAbsolutePaths() {
        XCTAssertTrue(NemoSpeechRuntimeManager.safeArchivePath("nemo-speech/bin/nemo-speech"))
        XCTAssertFalse(NemoSpeechRuntimeManager.safeArchivePath("../outside"))
        XCTAssertFalse(NemoSpeechRuntimeManager.safeArchivePath("/absolute/path"))
    }

    func testOnlyCortexaMarkedRuntimeCanBeValidatedAndRemoved() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let managed = root.appendingPathComponent("managed", isDirectory: true)
        let external = root.appendingPathComponent("external", isDirectory: true)
        let cache = root.appendingPathComponent("models", isDirectory: true)
        try FileManager.default.createDirectory(at: managed.appendingPathComponent("bin"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: external, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let executable = managed.appendingPathComponent("bin/nemo-speech")
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
        let marker = "\"managedBy\":\"Cortexa\",\"runtimeID\":\"nemo-speech\",\"version\":\"0.1.0\",\"archiveSHA256\":\"\(NemoSpeechRuntimeManager.expectedSHA256)\",\"binaryRelativePath\":\"bin/nemo-speech\""
        try Data("{\(marker)}".utf8).write(to: managed.appendingPathComponent("cortexa-runtime.json"))
        XCTAssertEqual(NemoSpeechRuntimeManager.validatedManagedCLI(in: managed, fileManager: .default), executable)

        let externalMarker = external.appendingPathComponent("nemo-speech")
        try Data("external".utf8).write(to: externalMarker)
        try NemoSpeechRuntimeManager.removeManagedRuntimeIfUnused(
            runtimeDirectory: managed,
            modelCacheDirectory: cache,
            fileManager: .default
        )
        XCTAssertFalse(FileManager.default.fileExists(atPath: managed.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: externalMarker.path))
    }

    func testRuntimeCleanupKeepsRuntimeForDependentModel() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let managed = root.appendingPathComponent("managed", isDirectory: true)
        let cache = root.appendingPathComponent("models", isDirectory: true)
        try FileManager.default.createDirectory(at: managed.appendingPathComponent("bin"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let executable = managed.appendingPathComponent("bin/nemo-speech")
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
        let marker = "\"managedBy\":\"Cortexa\",\"runtimeID\":\"nemo-speech\",\"version\":\"0.1.0\",\"archiveSHA256\":\"\(NemoSpeechRuntimeManager.expectedSHA256)\",\"binaryRelativePath\":\"bin/nemo-speech\""
        try Data("{\(marker)}".utf8).write(to: managed.appendingPathComponent("cortexa-runtime.json"))
        try Data("GGUF".utf8).write(to: cache.appendingPathComponent("parakeet-tdt-0.6b-v3.q8_0.gguf"))

        try NemoSpeechRuntimeManager.removeManagedRuntimeIfUnused(
            runtimeDirectory: managed,
            modelCacheDirectory: cache,
            fileManager: .default
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: managed.path))
    }

    func testRuntimeCleanupWaitsForActiveSubprocessLease() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let managed = root.appendingPathComponent("managed", isDirectory: true)
        try FileManager.default.createDirectory(at: managed.appendingPathComponent("bin"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let executable = managed.appendingPathComponent("bin/nemo-speech")
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
        let marker = "\"managedBy\":\"Cortexa\",\"runtimeID\":\"nemo-speech\",\"version\":\"0.1.0\",\"archiveSHA256\":\"\(NemoSpeechRuntimeManager.expectedSHA256)\",\"binaryRelativePath\":\"bin/nemo-speech\""
        try Data("{\(marker)}".utf8).write(to: managed.appendingPathComponent("cortexa-runtime.json"))

        let attemptedCleanup = DispatchSemaphore(value: 0)
        let cleanupCompleted = DispatchSemaphore(value: 0)
        NemoRuntimeAccess.lock.lock()
        DispatchQueue.global().async {
            attemptedCleanup.signal()
            try? NemoSpeechRuntimeManager.removeManagedRuntimeIfUnused(
                runtimeDirectory: managed,
                modelCacheDirectory: nil,
                fileManager: .default
            )
            cleanupCompleted.signal()
        }
        XCTAssertEqual(attemptedCleanup.wait(timeout: .now() + 1), .success)
        XCTAssertEqual(cleanupCompleted.wait(timeout: .now() + 0.05), .timedOut)
        NemoRuntimeAccess.lock.unlock()
        XCTAssertEqual(cleanupCompleted.wait(timeout: .now() + 1), .success)
        XCTAssertFalse(FileManager.default.fileExists(atPath: managed.path))
    }
}
#endif
