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
    }
}
#endif
