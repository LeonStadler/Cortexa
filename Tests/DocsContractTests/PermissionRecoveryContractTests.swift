#if canImport(XCTest)
    import Foundation
    import XCTest

    final class PermissionRecoveryContractTests: XCTestCase {
        func testPermissionsGuideCoversStableSigningAndExplicitAccessibilityConsent() throws {
            let permissionsGuide = try readRepositoryFile("docs/permissions-macos.md")

            XCTAssertTrue(permissionsGuide.contains("AXIsProcessTrustedWithOptions"))
            XCTAssertTrue(permissionsGuide.contains("explizit"))
            XCTAssertTrue(permissionsGuide.contains("Developer ID Application"))
            XCTAssertTrue(permissionsGuide.contains("nicht der normale Ablauf"))
        }

        func testReleaseChecklistCoversStableSigningAndPermissionScenarios() throws {
            let releaseChecklist = try readRepositoryFile("docs/macos-release-checklist.md")

            XCTAssertTrue(releaseChecklist.contains("Developer ID Application"))
            XCTAssertTrue(releaseChecklist.contains("Bedienungshilfen"))
            XCTAssertTrue(releaseChecklist.contains("codesign -dvvv"))
            XCTAssertTrue(releaseChecklist.contains("AX-Recht entziehen"))
            XCTAssertTrue(releaseChecklist.contains("TeamIdentifier"))
        }

        func testSettingsCopyUsesOneExplicitAccessibilityGrantAction() throws {
            let settingsView = try readRepositoryFile("apps/macos/AppShell/SettingsView.swift")
            let generalSections = try readRepositoryFile(
                "apps/macos/AppShell/SettingsViewGeneralSections.swift"
            )

            XCTAssertTrue(settingsView.contains("generalPermissionsContent"))
            XCTAssertTrue(generalSections.contains("Freigabe anfragen"))
            XCTAssertTrue(generalSections.contains("macOS-Hinweis"))
            XCTAssertTrue(generalSections.contains("Bedienungshilfen"))
            XCTAssertFalse(generalSections.contains("Neu verknüpfen"))
        }

        func testArchiveScriptRejectsAdHocUpdateArtifacts() throws {
            let archiveScript = try readRepositoryFile("scripts/archive_macos_release.sh")

            XCTAssertTrue(archiveScript.contains("persistent CODE_SIGN_IDENTITY"))
            XCTAssertTrue(archiveScript.contains("refusing to create an ad-hoc archive"))
            XCTAssertTrue(archiveScript.contains("TeamIdentifier"))
            XCTAssertFalse(archiveScript.contains("--sign -"))
        }

        func testDMGScriptAllowsAdHocAppsOnlyForOpenSourceRelease() throws {
            let dmgScript = try readRepositoryFile("scripts/create_macos_dmg.sh")

            XCTAssertTrue(dmgScript.contains("CORTEXA_ALLOW_ADHOC"))
            XCTAssertTrue(dmgScript.contains("Ad-hoc signed apps are accepted only for the open-source release path"))
            XCTAssertTrue(dmgScript.contains("persistent Apple signature without a TeamIdentifier"))
            XCTAssertTrue(dmgScript.contains("codesign --verify --deep --strict"))
        }

        func testOpenSourceReleaseBuildDoesNotRequireAppleSigningCredentials() throws {
            let releaseScript = try readRepositoryFile("scripts/build_macos_open_source_release.sh")

            XCTAssertTrue(releaseScript.contains("CODE_SIGNING_ALLOWED=NO"))
            XCTAssertTrue(releaseScript.contains("ARCHS=arm64"))
            XCTAssertTrue(releaseScript.contains("codesign --force --deep --sign -"))
            XCTAssertTrue(releaseScript.contains("CORTEXA_ALLOW_ADHOC=1"))
            XCTAssertTrue(releaseScript.contains("Cortexa-${APP_VERSION}.dmg"))
            XCTAssertTrue(releaseScript.contains("hdiutil verify"))
        }

        func testDictationStartDoesNotPromptForAccessibility() throws {
            let runtime = try readRepositoryFile("apps/macos/AppShell/DictationRuntime.swift")
            let permissionCoordinator = try readRepositoryFile(
                "apps/macos/AppShell/PermissionCoordinator.swift"
            )

            XCTAssertTrue(runtime.contains("promptIfNeeded: false"))
            XCTAssertTrue(permissionCoordinator.contains("promptAccessibilityTrustFromUser()"))
            XCTAssertFalse(permissionCoordinator.contains("self.dictationRuntime.openAccessibilitySettings()"))
        }

        func testDebugSmokeDoesNotClaimAdHocSigningCanVerifyPermissionContinuity() throws {
            let smokeScript = try readRepositoryFile("scripts/smoke_test_macos_app.sh")

            XCTAssertTrue(smokeScript.contains("non-persistent local signature"))
            XCTAssertTrue(smokeScript.contains("not a permission-continuity check"))
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
