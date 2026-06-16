#if canImport(XCTest)
    import XCTest
    @testable import AppShellSupport

    final class BuildPermissionFingerprintTests: XCTestCase {
        func testStaleAccessibilityAfterRebuildWhenFingerprintChanged() {
            let defaults = UserDefaults(
                suiteName: "BuildPermissionFingerprintTests.\(UUID().uuidString)")!
            let store = BuildPermissionFingerprintStore(defaults: defaults)

            let trusted = BuildPermissionFingerprint(
                bundlePath: "/tmp/WisprLocalMac-old.app",
                bundleVersion: "100",
                executablePath: "/tmp/WisprLocalMac-old.app/Contents/MacOS/WisprLocalMac",
                executableModificationTime: 1
            )
            let data = try! JSONEncoder().encode(trusted)
            defaults.set(data, forKey: "wispr.permissions.lastTrustedAccessibilityBuild")

            XCTAssertTrue(store.isAccessibilityStale(currentlyTrusted: false))
        }

        func testNotStaleWhenCurrentlyTrusted() {
            let defaults = UserDefaults(
                suiteName: "BuildPermissionFingerprintTests.\(UUID().uuidString)")!
            let store = BuildPermissionFingerprintStore(defaults: defaults)

            store.recordTrustedAccessibility()

            XCTAssertFalse(store.isAccessibilityStale(currentlyTrusted: true))
        }

        func testStaleWhenPreviouslyGrantedButNotCurrentlyTrusted() {
            let defaults = UserDefaults(
                suiteName: "BuildPermissionFingerprintTests.\(UUID().uuidString)")!
            defaults.set(true, forKey: "wispr.permissions.accessibilityEverGranted")
            let store = BuildPermissionFingerprintStore(defaults: defaults)

            XCTAssertTrue(store.isAccessibilityStale(currentlyTrusted: false))
        }
    }
#endif
