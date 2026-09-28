#if canImport(XCTest)
import ASRCore
import Foundation
import XCTest
@testable import AppShellSupport

final class AppUninstallerTests: XCTestCase {
    func testCommandRunnerCapturesStandardOutputAndErrorOnFailure() throws {
        let result = try AppUninstallCommandRunner.run(
            executableURL: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", "printf 'stdout diagnostic'; printf 'stderr diagnostic' >&2; exit 17"]
        )

        XCTAssertEqual(result.terminationStatus, 17)
        XCTAssertTrue(result.output.contains("stdout diagnostic"))
        XCTAssertTrue(result.output.contains("stderr diagnostic"))
    }

    func testPrivacyResetFailureIncludesExitCodeAndFallbackDiagnostic() {
        let error = AppUninstallerError.privacyResetFailed(
            service: "Microphone",
            bundleIdentifier: "com.wisprlocal.mac",
            exitCode: 70,
            output: ""
        )

        XCTAssertEqual(
            error.errorDescription,
            "tccutil konnte Microphone für com.wisprlocal.mac nicht zurücksetzen (Exit-Code 70): tccutil hat keine Diagnoseausgabe geliefert."
        )
    }

    func testCleanupRemovesOnlyCortexaManagedModelAndRuntimeFiles() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let support = root.appendingPathComponent("Application Support/WisprLocal", isDirectory: true)
        let appCache = root.appendingPathComponent("Caches/WisprLocal", isDirectory: true)
        let modelCache = root.appendingPathComponent("Caches/NeMoSpeech/models", isDirectory: true)
        let runtimeRoot = root.appendingPathComponent(
            "Application Support/Cortexa/Runtime/NeMo-Speech", isDirectory: true
        )
        let temporary = root.appendingPathComponent("Temporary", isDirectory: true)
        let unmanagedRuntime = root.appendingPathComponent("External/nemo-speech", isDirectory: true)
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: appCache, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: modelCache, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: unmanagedRuntime, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let transcript = support.appendingPathComponent("transcript-history.json")
        let appDebugLog = appCache.appendingPathComponent("debug.log")
        let parakeetModel = modelCache.appendingPathComponent("parakeet-tdt-0.6b-v3.q8_0.gguf")
        let unrelatedModel = modelCache.appendingPathComponent("other-model.gguf")
        let partialDownload = modelCache.appendingPathComponent(
            ".cortexa-model-download-parakeet-tdt-0.6b-v3.q8_0.gguf.partial"
        )
        let cortexaTemporary = temporary.appendingPathComponent(
            "cortexa-voice-model-download-interrupted", isDirectory: true
        )
        let unrelatedTemporary = temporary.appendingPathComponent("another-app", isDirectory: true)
        try Data("history".utf8).write(to: transcript)
        try Data("log".utf8).write(to: appDebugLog)
        try Data("model".utf8).write(to: parakeetModel)
        try Data("other".utf8).write(to: unrelatedModel)
        try Data("partial".utf8).write(to: partialDownload)
        try FileManager.default.createDirectory(at: cortexaTemporary, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: unrelatedTemporary, withIntermediateDirectories: true)

        let managedRuntime = runtimeRoot.appendingPathComponent("0.1.0", isDirectory: true)
        try FileManager.default.createDirectory(at: managedRuntime, withIntermediateDirectories: true)
        let manifest = """
        {"managedBy":"Cortexa","runtimeID":"nemo-speech","version":"0.1.0"}
        """
        try Data(manifest.utf8).write(
            to: managedRuntime.appendingPathComponent("cortexa-runtime.json")
        )
        let externalMarker = unmanagedRuntime.appendingPathComponent("keep.txt")
        try Data("keep".utf8).write(to: externalMarker)

        let preferencesDomain = "AppUninstallerTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: preferencesDomain))
        defaults.set("saved", forKey: "preference")
        var deletedKeychain = false
        var resetServices: [String] = []
        let cleanup = AppUninstallCleanup(
            fileManager: .default,
            defaults: defaults,
            removeItem: { try FileManager.default.removeItem(at: $0) },
            deleteKeychainItems: { deletedKeychain = true },
            resetPrivacyService: { resetServices.append($0) }
        )
        let paths = makePaths(
            root: root,
            appSupportDirectory: support,
            appCacheDirectory: appCache,
            nemoModelsDirectory: modelCache,
            managedNemoRuntimeDirectory: runtimeRoot,
            temporaryDirectory: temporary,
            preferencesDomain: preferencesDomain
        )

        let failures = cleanup.perform(paths: paths)

        XCTAssertTrue(failures.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: support.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: appCache.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: parakeetModel.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: partialDownload.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: managedRuntime.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: cortexaTemporary.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: unrelatedModel.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: unrelatedTemporary.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: externalMarker.path))
        XCTAssertNil(defaults.string(forKey: "preference"))
        XCTAssertTrue(deletedKeychain)
        XCTAssertEqual(
            resetServices,
            [AppUninstallCleanup.microphonePrivacyService, AppUninstallCleanup.accessibilityPrivacyService]
        )
    }

    func testCleanupReportsFailuresAndContinuesOtherSteps() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let support = root.appendingPathComponent("Application Support/WisprLocal", isDirectory: true)
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        var resetServices: [String] = []
        let preferencesDomain = "AppUninstallerFailures.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: preferencesDomain))
        let cleanup = AppUninstallCleanup(
            fileManager: .default,
            defaults: defaults,
            removeItem: { url in
                if url == support {
                    throw TestUninstallFailure.fileAccess
                }
                try FileManager.default.removeItem(at: url)
            },
            deleteKeychainItems: { throw TestUninstallFailure.keychain },
            resetPrivacyService: { service in
                resetServices.append(service)
                if service == AppUninstallCleanup.accessibilityPrivacyService {
                    throw TestUninstallFailure.privacy
                }
            }
        )
        let paths = makePaths(
            root: root,
            appSupportDirectory: support,
            appCacheDirectory: root.appendingPathComponent("missing-cache", isDirectory: true),
            nemoModelsDirectory: root.appendingPathComponent("missing-models", isDirectory: true),
            managedNemoRuntimeDirectory: root.appendingPathComponent("missing-runtime", isDirectory: true),
            temporaryDirectory: root.appendingPathComponent("missing-temp", isDirectory: true),
            preferencesDomain: preferencesDomain
        )

        let failures = cleanup.perform(paths: paths)

        XCTAssertTrue(FileManager.default.fileExists(atPath: support.path))
        XCTAssertEqual(
            failures.map(\.step),
            ["App-Daten", "gespeicherte API-Schlüssel", "Bedienungshilfenfreigabe"]
        )
        XCTAssertEqual(resetServices, ["Microphone", "Accessibility"])
    }

    private func makePaths(
        root: URL,
        appSupportDirectory: URL,
        appCacheDirectory: URL,
        nemoModelsDirectory: URL,
        managedNemoRuntimeDirectory: URL,
        temporaryDirectory: URL,
        preferencesDomain: String
    ) -> AppUninstallPaths {
        AppUninstallPaths(
            appSupportDirectory: appSupportDirectory,
            appCacheDirectory: appCacheDirectory,
            nemoModelsDirectory: nemoModelsDirectory,
            managedNemoRuntimeDirectory: managedNemoRuntimeDirectory,
            temporaryDirectory: temporaryDirectory,
            appBundleURL: root.appendingPathComponent("Cortexa.app", isDirectory: true),
            bundleIdentifier: preferencesDomain
        )
    }
}

private enum TestUninstallFailure: Error {
    case fileAccess
    case keychain
    case privacy
}
#endif
