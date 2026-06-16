#if canImport(XCTest)
import Foundation
import XCTest

final class DocsContractTests: XCTestCase {
    func testApiDesignDocumentsCurrentDictationOptions() throws {
        let apiDesign = try readRepositoryFile("docs/api-design.md")

        XCTAssertTrue(apiDesign.contains("liveRewriteScope"))
        XCTAssertTrue(apiDesign.contains("finalResultDeliveryMode"))
        XCTAssertTrue(apiDesign.contains("clipboardFallbackWhenNoTarget"))
        XCTAssertTrue(apiDesign.contains("bounded mutable tail"))
    }

    func testSystemDesignDescribesMutableTailAndLiveRewriteScope() throws {
        let systemDesign = try readRepositoryFile("docs/system-design.md")

        XCTAssertTrue(systemDesign.contains("mutable tail"))
        XCTAssertTrue(systemDesign.contains("live rewrite scope"))
    }

    func testLicensingAndReadmeMatchDistributionAndUpdateBehavior() throws {
        let licensing = try readRepositoryFile("docs/licensing.md")
        let readme = try readRepositoryFile("README.md")

        XCTAssertTrue(licensing.contains("keine Open-Source-Software"))
        XCTAssertTrue(licensing.contains("keine lokale Lizenzschlüssel-Aktivierung"))
        XCTAssertFalse(readme.contains("WISPR_LICENSE_PUBLIC_KEY_BASE64"))
        XCTAssertTrue(readme.contains("permanent sichtbarem manuellen Check"))
    }

    func testVersionFileMatchesCurrentRepositoryVersion() throws {
        let version = try readRepositoryFile("VERSION").trimmingCharacters(
            in: .whitespacesAndNewlines)
        XCTAssertEqual(version, "0.25.0")
    }

    private func readRepositoryFile(_ relativePath: String) throws -> String {
        let repositoryRoot = try locateRepositoryRoot()
        let fileURL = repositoryRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: fileURL, encoding: .utf8)
    }

    private func locateRepositoryRoot() throws -> URL {
        var current = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let fileManager = FileManager.default
        while current.path != "/" {
            let docsURL = current.appendingPathComponent("docs")
            let versionURL = current.appendingPathComponent("VERSION")

            if fileManager.fileExists(atPath: docsURL.path),
                fileManager.fileExists(atPath: versionURL.path)
            {
                return current
            }

            current.deleteLastPathComponent()
        }

        throw NSError(
            domain: "DocsContractTests",
            code: 1,
            userInfo: [
                NSLocalizedDescriptionKey: "Unable to locate repository root from test file path."
            ]
        )
    }
}
#endif
