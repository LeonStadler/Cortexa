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
        let ciWorkflow = try readRepositoryFile(".github/workflows/ci.yml")

        XCTAssertTrue(licensing.contains("keine Open-Source-Software"))
        XCTAssertTrue(licensing.contains("keine lokale Lizenzschlüssel-Aktivierung"))
        XCTAssertFalse(readme.contains("WISPR_LICENSE_PUBLIC_KEY_BASE64"))
        XCTAssertFalse(ciWorkflow.contains("WISPR_LICENSE_PUBLIC_KEY_BASE64"))
        XCTAssertTrue(readme.contains("permanent sichtbarem manuellen Check"))
    }

    func testVersionFileMatchesCurrentRepositoryVersion() throws {
        let version = try readRepositoryFile("VERSION").trimmingCharacters(
            in: .whitespacesAndNewlines)
        XCTAssertEqual(version, "0.32.3")
    }

    func testDMGBuilderStoresFinderBackgroundAndLayoutWithoutAppleScript() throws {
        let background = try readRepositoryFile(
            "apps/macos/AppShell/Resources/CortexaInstallerBackground.svg")
        let dmgScript = try readRepositoryFile("scripts/create_macos_dmg.sh")
        let settings = try readRepositoryFile("scripts/macos_dmg_settings.py")
        let requirements = try readRepositoryFile("scripts/requirements-macos-dmg.txt")

        XCTAssertTrue(background.contains("width=\"800\" height=\"500\" viewBox=\"0 0 800 500\""))
        XCTAssertTrue(dmgScript.contains("sips -s format png"))
        XCTAssertTrue(dmgScript.contains("dmgbuild-venv"))
        XCTAssertFalse(dmgScript.contains("osascript"))
        XCTAssertTrue(settings.contains("background = defines[\"background\"]"))
        XCTAssertTrue(settings.contains("window_rect = ((120, 120), (800, 500))"))
        XCTAssertTrue(settings.contains("app_path.name: (190, 260)"))
        XCTAssertTrue(settings.contains("\"Applications\": (610, 260)"))
        XCTAssertEqual(requirements.trimmingCharacters(in: .whitespacesAndNewlines), "dmgbuild==1.6.7")
    }

    func testMacOSCortexaBrandingAssetsAreWired() throws {
        let project = try readRepositoryFile("apps/macos/WisprLocalMac/project.yml")
        let iconComposer = try readRepositoryFile("apps/macos/AppShell/Resources/Cortexa.icon/icon.json")
        let horizontalLogo = try readRepositoryFile(
            "apps/macos/AppShell/Resources/Assets.xcassets/CortexaLogoHorizontal.imageset/Contents.json")
        let stackedLogo = try readRepositoryFile(
            "apps/macos/AppShell/Resources/Assets.xcassets/CortexaLogoStacked.imageset/Contents.json")

        XCTAssertTrue(project.contains("path: ../AppShell/Resources/Cortexa.icon"))
        XCTAssertTrue(project.contains("ASSETCATALOG_COMPILER_APPICON_NAME: Cortexa"))
        XCTAssertTrue(iconComposer.contains("\"fill\" : \"automatic\""))
        XCTAssertTrue(iconComposer.contains("\"translucency\""))
        XCTAssertTrue(iconComposer.contains("\"hidden-specializations\""))
        XCTAssertTrue(iconComposer.contains("Logo 5 Dark.svg"))
        XCTAssertTrue(horizontalLogo.contains("CortexaLogoHorizontal.svg"))
        XCTAssertTrue(stackedLogo.contains("CortexaLogoStacked.svg"))
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
