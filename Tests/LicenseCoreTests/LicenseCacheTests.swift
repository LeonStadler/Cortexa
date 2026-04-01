#if canImport(XCTest)
import Foundation
import XCTest
@testable import LicenseCore

final class LicenseCacheTests: XCTestCase {
    func testWriteAndReadRestoresLicenseKey() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("license_cache_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }

        let fileURL = directory.appendingPathComponent("cache.json")
        let cache = LicenseCache(fileURL: fileURL)

        let expectedKey = "LICENSE-123"
        try cache.write(licenseKey: expectedKey)

        XCTAssertEqual(try cache.read(), expectedKey)
    }

    func testClearRemovesCachedLicenseKey() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("license_cache_clear_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }

        let fileURL = directory.appendingPathComponent("cache.json")
        let cache = LicenseCache(fileURL: fileURL)

        try cache.write(licenseKey: "LICENSE-789")
        try cache.clear()

        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
        XCTAssertNil(try cache.read())
    }

    func testReadReturnsNilWhenIntegrityFails() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("license_cache_tamper_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }

        let fileURL = directory.appendingPathComponent("cache.json")
        let cache = LicenseCache(fileURL: fileURL)

        try cache.write(licenseKey: "LICENSE-456")

        let data = try Data(contentsOf: fileURL)
        let entry = try JSONDecoder().decode(LicenseCacheEntry.self, from: data)
        let tampered = LicenseCacheEntry(licenseKey: entry.licenseKey, cachedAt: entry.cachedAt, nonce: entry.nonce, integrityTag: "bad-tag")
        let tamperedData = try JSONEncoder().encode(tampered)
        try tamperedData.write(to: fileURL, options: [.atomic])

        XCTAssertNil(try cache.read())
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))

        let quarantineFiles = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("cache.json.corrupt-") }
        XCTAssertEqual(quarantineFiles.count, 1)
    }

    func testReadQuarantinesCorruptedCacheAndReturnsNil() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("license_cache_corrupt_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }

        let fileURL = directory.appendingPathComponent("cache.json")
        let cache = LicenseCache(fileURL: fileURL)

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not-json".utf8).write(to: fileURL, options: [.atomic])

        XCTAssertNil(try cache.read())
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))

        let quarantineFiles = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("cache.json.corrupt-") }
        XCTAssertEqual(quarantineFiles.count, 1)
    }
}
#endif
