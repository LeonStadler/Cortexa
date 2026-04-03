#if canImport(XCTest)
import Foundation
import XCTest

final class DocsContractTests: XCTestCase {
    func testApiDesignDocumentsCurrentDictationOptions() throws {
        let apiDesign = try readRepositoryFile("docs/api-design.md")

        XCTAssertTrue(apiDesign.contains("translationOutput"))
        XCTAssertTrue(apiDesign.contains("aiProcessing"))
        XCTAssertTrue(apiDesign.contains("AIProcessingConfiguration"))
        XCTAssertTrue(apiDesign.contains("AIRemoteProviderConfiguration"))
        XCTAssertTrue(apiDesign.contains("case openAI"))
        XCTAssertTrue(apiDesign.contains("requiresAPIKey"))
        XCTAssertTrue(apiDesign.contains("providerID::modelID"))
        XCTAssertTrue(apiDesign.contains("liveRewriteScope"))
        XCTAssertTrue(apiDesign.contains("finalResultDeliveryMode"))
        XCTAssertTrue(apiDesign.contains("clipboardFallbackWhenNoTarget"))
        XCTAssertTrue(apiDesign.contains("bounded mutable tail"))
        XCTAssertTrue(apiDesign.contains("raw Whisper transcript"))
    }

    func testSystemDesignDescribesMutableTailAndLiveRewriteScope() throws {
        let systemDesign = try readRepositoryFile("docs/system-design.md")

        XCTAssertTrue(systemDesign.contains("mutable tail"))
        XCTAssertTrue(systemDesign.contains("live rewrite scope"))
        XCTAssertTrue(systemDesign.contains("Transcription -> optional Translation -> optional AI Processing"))
        XCTAssertTrue(systemDesign.contains("Auto language detection controls recognition only and never implies translation"))
        XCTAssertTrue(systemDesign.contains("dynamic remote API catalogs"))
        XCTAssertTrue(systemDesign.contains("OpenAI, Groq, Mistral, DeepSeek"))
    }

    func testLicensingAndReadmeMatchDeactivateAndUpdateBehavior() throws {
        let licensing = try readRepositoryFile("docs/licensing.md")
        let readme = try readRepositoryFile("README.md")

        XCTAssertTrue(licensing.contains("no plaintext disk fallback for raw license keys"))
        XCTAssertTrue(licensing.contains("removes any legacy plaintext cache file left by older builds"))
        XCTAssertTrue(readme.contains("Keychain-only secret persistence with legacy cache cleanup"))
        XCTAssertTrue(readme.contains("permanent sichtbarem manuellen Check"))
    }

    func testVersionFileUsesSemanticThreePartFormat() throws {
        let version = try readRepositoryFile("VERSION").trimmingCharacters(in: .whitespacesAndNewlines)
        let versionPattern = #"^\d+\.\d+\.\d+$"#

        XCTAssertFalse(version.isEmpty)
        XCTAssertNotNil(version.range(of: versionPattern, options: .regularExpression))
        XCTAssertEqual(version, "0.31.2")
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
               fileManager.fileExists(atPath: versionURL.path) {
                return current
            }

            current.deleteLastPathComponent()
        }

        throw NSError(
            domain: "DocsContractTests",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Unable to locate repository root from test file path."]
        )
    }
}
#endif
