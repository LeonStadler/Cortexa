#if canImport(XCTest)
    import Foundation
    import XCTest

    final class PermissionRecoveryContractTests: XCTestCase {
        func testPermissionsGuideCoversRebuildRecoveryAndStaleAccessibilityEntries() throws {
            let permissionsGuide = try readRepositoryFile("docs/permissions-macos.md")

            XCTAssertTrue(permissionsGuide.contains("Rebuild"))
            XCTAssertTrue(permissionsGuide.contains("neu hinzufügen"))
            XCTAssertTrue(permissionsGuide.contains("einmal entfernen"))
            XCTAssertTrue(permissionsGuide.contains("frischen Diktatversuch"))
            XCTAssertTrue(permissionsGuide.contains("Smoke-Test"))
        }

        func testReleaseChecklistCoversRebuildAndPermissionRecoveryScenarios() throws {
            let releaseChecklist = try readRepositoryFile("docs/macos-release-checklist.md")

            XCTAssertTrue(releaseChecklist.contains("Rebuild"))
            XCTAssertTrue(releaseChecklist.contains("Bedienungshilfen"))
            XCTAssertTrue(releaseChecklist.contains("codesign -dvvv"))
            XCTAssertTrue(releaseChecklist.contains("AX-Recht entziehen"))
            XCTAssertTrue(releaseChecklist.contains("WisprLocalMac"))
        }

        func testSettingsCopyMentionsRebuildRecoveryForAccessibility() throws {
            let settingsView = try readRepositoryFile("apps/macos/AppShell/SettingsView.swift")
            let generalSections = try readRepositoryFile(
                "apps/macos/AppShell/SettingsViewGeneralSections.swift"
            )

            XCTAssertTrue(settingsView.contains("generalPermissionsContent"))
            XCTAssertTrue(generalSections.contains("Nach einem Rebuild"))
            XCTAssertTrue(generalSections.contains("Neu verknüpfen"))
            XCTAssertTrue(generalSections.contains("Bedienungshilfen"))
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
                domain: "PermissionRecoveryContractTests",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "Unable to locate repository root from test file path."
                ]
            )
        }
    }
#endif
