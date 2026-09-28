import AppKit
import ASRCore
import Foundation
import Security
import ServiceManagement
import Darwin

struct AppUninstallPaths {
    let appSupportDirectory: URL
    let appCacheDirectory: URL
    let nemoModelsDirectory: URL
    let managedNemoRuntimeDirectory: URL
    let temporaryDirectory: URL
    let appBundleURL: URL
    let bundleIdentifier: String

    static func current(
        fileManager: FileManager,
        appBundleURL: URL,
        bundleIdentifier: String
    ) throws -> AppUninstallPaths {
        let applicationSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        let caches = try fileManager.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        let temporaryDirectory = fileManager.temporaryDirectory

        guard appBundleURL.pathExtension == "app",
              Bundle(url: appBundleURL)?.bundleIdentifier == bundleIdentifier
        else {
            throw AppUninstallerError.invalidAppBundle(appBundleURL)
        }

        return AppUninstallPaths(
            appSupportDirectory: AppShellStoragePaths.appSupportDirectory(
                fileManager: fileManager
            ),
            appCacheDirectory: caches.appendingPathComponent("WisprLocal", isDirectory: true),
            nemoModelsDirectory: caches
                .appendingPathComponent("NeMoSpeech", isDirectory: true)
                .appendingPathComponent("models", isDirectory: true),
            managedNemoRuntimeDirectory: applicationSupport
                .appendingPathComponent("Cortexa/Runtime/NeMo-Speech", isDirectory: true),
            temporaryDirectory: temporaryDirectory,
            appBundleURL: appBundleURL,
            bundleIdentifier: bundleIdentifier
        )
    }

    init(
        appSupportDirectory: URL,
        appCacheDirectory: URL,
        nemoModelsDirectory: URL,
        managedNemoRuntimeDirectory: URL,
        temporaryDirectory: URL,
        appBundleURL: URL,
        bundleIdentifier: String
    ) {
        self.appSupportDirectory = appSupportDirectory
        self.appCacheDirectory = appCacheDirectory
        self.nemoModelsDirectory = nemoModelsDirectory
        self.managedNemoRuntimeDirectory = managedNemoRuntimeDirectory
        self.temporaryDirectory = temporaryDirectory
        self.appBundleURL = appBundleURL
        self.bundleIdentifier = bundleIdentifier
    }
}

struct AppUninstallFailure: Equatable {
    let step: String
    let message: String
}

enum AppUninstallerError: LocalizedError {
    case invalidAppBundle(URL)
    case missingExecutable
    case loginItemCleanupFailed(String)
    case helperLaunchFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidAppBundle(let url):
            return "Cortexa konnte das installierte App-Bundle nicht sicher bestimmen: \(url.path)"
        case .missingExecutable:
            return "Der Cortexa-App-Executable für den Deinstallationshelfer wurde nicht gefunden."
        case .loginItemCleanupFailed(let reason):
            return "Der automatische Anmeldestart konnte nicht deaktiviert werden: \(reason)"
        case .helperLaunchFailed(let reason):
            return "Der Deinstallationshelfer konnte nicht sicher gestartet werden: \(reason)"
        }
    }
}

struct AppUninstallCleanup {
    static let keychainService = "com.wisprlocal.ai.remote-provider"
    static let microphonePrivacyService = "Microphone"
    static let accessibilityPrivacyService = "Accessibility"
    static let temporaryDirectoryPrefixes = [
        "cortexa-voice-model-download-",
        "voice-model-download-",
    ]
    static let parakeetProviderID = "nvidia.parakeet"

    let fileManager: FileManager
    let defaults: UserDefaults
    let removeItem: (URL) throws -> Void
    let deleteKeychainItems: () throws -> Void
    let resetPrivacyService: (String) throws -> Void

    func perform(paths: AppUninstallPaths) -> [AppUninstallFailure] {
        var failures: [AppUninstallFailure] = []

        attempt("App-Daten", failures: &failures) {
            try removeIfPresent(paths.appSupportDirectory)
        }
        attempt("App-Cache", failures: &failures) {
            try removeIfPresent(paths.appCacheDirectory)
        }
        attempt("NeMo-Modellcache", failures: &failures) {
            try removeKnownParakeetModels(in: paths.nemoModelsDirectory)
        }
        attempt("Cortexa-verwaltete NeMo-Runtime", failures: &failures) {
            try removeManagedNemoRuntimes(in: paths.managedNemoRuntimeDirectory)
        }
        attempt("temporäre Modelldownloads", failures: &failures) {
            try removeTemporaryDownloadDirectories(in: paths.temporaryDirectory)
        }
        attempt("Einstellungen", failures: &failures) {
            defaults.removePersistentDomain(forName: paths.bundleIdentifier)
        }
        attempt("gespeicherte API-Schlüssel", failures: &failures, operation: deleteKeychainItems)
        attempt("Mikrofonfreigabe", failures: &failures) {
            try resetPrivacyService(Self.microphonePrivacyService)
        }
        attempt("Bedienungshilfenfreigabe", failures: &failures) {
            try resetPrivacyService(Self.accessibilityPrivacyService)
        }

        return failures
    }

    private func removeIfPresent(_ url: URL) throws {
        guard fileManager.fileExists(atPath: url.path) else { return }
        try removeItem(url)
    }

    private func removeKnownParakeetModels(in directory: URL) throws {
        let modelFileNames = LocalVoiceModelCatalog.availableModels()
            .filter { $0.providerID == Self.parakeetProviderID }
            .compactMap(\.localFileName)

        for fileName in modelFileNames {
            try removeIfPresent(directory.appendingPathComponent(fileName))
            try removeIfPresent(
                directory.appendingPathComponent(".cortexa-model-download-\(fileName).partial")
            )
        }

        try removeDirectoryIfEmpty(directory)
        try removeDirectoryIfEmpty(directory.deletingLastPathComponent())
    }

    private func removeManagedNemoRuntimes(in directory: URL) throws {
        guard fileManager.fileExists(atPath: directory.path) else { return }

        let entries = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        for entry in entries {
            guard isManagedNemoRuntime(entry) else { continue }
            try removeItem(entry)
        }

        try removeDirectoryIfEmpty(directory)
        try removeDirectoryIfEmpty(directory.deletingLastPathComponent())
        try removeDirectoryIfEmpty(directory.deletingLastPathComponent().deletingLastPathComponent())
    }

    private func isManagedNemoRuntime(_ directory: URL) -> Bool {
        let manifestURL = directory.appendingPathComponent("cortexa-runtime.json")
        guard let data = try? Data(contentsOf: manifestURL),
              let manifest = try? JSONDecoder().decode(ManagedNemoRuntimeManifest.self, from: data)
        else {
            return false
        }
        return manifest.managedBy == "Cortexa"
            && manifest.runtimeID == "nemo-speech"
            && manifest.version == directory.lastPathComponent
    }

    private func removeTemporaryDownloadDirectories(in directory: URL) throws {
        guard fileManager.fileExists(atPath: directory.path) else { return }
        let entries = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        for entry in entries where Self.temporaryDirectoryPrefixes.contains(where: {
            entry.lastPathComponent.hasPrefix($0)
        }) {
            let values = try entry.resourceValues(forKeys: [.isDirectoryKey])
            guard values.isDirectory == true else { continue }
            try removeItem(entry)
        }
    }

    private func removeDirectoryIfEmpty(_ directory: URL) throws {
        guard fileManager.fileExists(atPath: directory.path) else { return }
        let contents = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: []
        )
        guard contents.isEmpty else { return }
        try removeItem(directory)
    }

    private func attempt(
        _ step: String,
        failures: inout [AppUninstallFailure],
        operation: () throws -> Void
    ) {
        do {
            try operation()
        } catch {
            failures.append(AppUninstallFailure(step: step, message: error.localizedDescription))
        }
    }
}

private struct ManagedNemoRuntimeManifest: Decodable {
    let managedBy: String
    let runtimeID: String
    let version: String
}

enum AppUninstaller {
    static let helperArgument = "--cortexa-uninstall-helper"

    @MainActor
    static func begin() throws {
        guard #available(macOS 13.0, *) else {
            throw AppUninstallerError.loginItemCleanupFailed("macOS 13 oder neuer wird benötigt.")
        }

        do {
            let loginServiceStatus = SMAppService.mainApp.status
            if loginServiceStatus == .enabled || loginServiceStatus == .requiresApproval {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            throw AppUninstallerError.loginItemCleanupFailed(error.localizedDescription)
        }

        guard let executableURL = Bundle.main.executableURL else {
            throw AppUninstallerError.missingExecutable
        }
        let helper = Process()
        helper.executableURL = executableURL
        helper.arguments = [Self.helperArgument, String(ProcessInfo.processInfo.processIdentifier)]
        let readinessPipe = Pipe()
        helper.standardOutput = readinessPipe
        do {
            try helper.run()
            let readiness = readinessPipe.fileHandleForReading.availableData
            guard String(data: readiness, encoding: .utf8) == "READY\n" else {
                throw AppUninstallerError.helperLaunchFailed(
                    String(data: readiness, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                        ?? "Der Prozess konnte nicht verifiziert werden."
                )
            }
        } catch {
            var reason = error.localizedDescription
            if SMAppService.mainApp.status != .enabled {
                do {
                    try SMAppService.mainApp.register()
                } catch {
                    reason += " Die vorherige Anmeldeoption konnte ebenfalls nicht wiederhergestellt werden: \(error.localizedDescription)"
                }
            }
            throw AppUninstallerError.helperLaunchFailed(reason)
        }

        DispatchQueue.main.async {
            NSApplication.shared.terminate(nil)
        }
    }
}

enum AppUninstallHelperMode {
    static func runIfRequested(arguments: [String]) -> Bool {
        guard let helperIndex = arguments.firstIndex(of: AppUninstaller.helperArgument) else {
            return false
        }
        guard arguments.indices.contains(helperIndex + 1),
              let parentProcessIdentifier = pid_t(arguments[helperIndex + 1])
        else {
            writeReadiness("ERROR:Der Deinstallationshelfer hat keine gültige Prozess-ID erhalten.\n")
            return true
        }
        guard isAuthorizedParent(parentProcessIdentifier) else {
            writeReadiness("ERROR:Der Deinstallationshelfer wurde nicht von der laufenden Cortexa-App gestartet.\n")
            return true
        }
        writeReadiness("READY\n")
        run(parentProcessIdentifier: parentProcessIdentifier)
        return true
    }

    private static func isAuthorizedParent(_ processIdentifier: pid_t) -> Bool {
        guard let parent = NSRunningApplication(processIdentifier: processIdentifier),
              parent.bundleIdentifier == "com.wisprlocal.mac",
              parent.executableURL?.standardizedFileURL == Bundle.main.executableURL?.standardizedFileURL
        else {
            return false
        }
        return true
    }

    private static func writeReadiness(_ message: String) {
        FileHandle.standardOutput.write(Data(message.utf8))
    }

    private static func run(parentProcessIdentifier: pid_t) {
        waitForParentToExit(parentProcessIdentifier)
        let fileManager = FileManager.default
        let bundleURL = Bundle.main.bundleURL
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            showResult(
                title: "Deinstallation fehlgeschlagen",
                message: "Die Bundle-ID der App konnte nicht ermittelt werden."
            )
            return
        }

        do {
            let paths = try AppUninstallPaths.current(
                fileManager: fileManager,
                appBundleURL: bundleURL,
                bundleIdentifier: bundleIdentifier
            )
            let cleanup = AppUninstallCleanup(
                fileManager: fileManager,
                defaults: .standard,
                removeItem: { try fileManager.removeItem(at: $0) },
                deleteKeychainItems: deleteRemoteProviderSecrets,
                resetPrivacyService: resetPrivacyService
            )
            let failures = cleanup.perform(paths: paths)
            guard failures.isEmpty else {
                showResult(
                    title: "Deinstallation nicht abgeschlossen",
                    message: failures.map { "\($0.step): \($0.message)" }.joined(separator: "\n")
                        + "\n\nCortexa bleibt installiert. Bitte behebe die Fehler und versuche es erneut."
                )
                return
            }

            do {
                try fileManager.trashItem(at: paths.appBundleURL, resultingItemURL: nil)
            } catch {
                showResult(
                    title: "Daten gelöscht, App noch installiert",
                    message: "Cortexas Daten wurden gelöscht, aber die App konnte nicht in den Papierkorb verschoben werden: \(error.localizedDescription)\n\nBitte verschiebe Cortexa.app manuell in den Papierkorb."
                )
                return
            }

            showResult(
                title: "Cortexa wurde deinstalliert",
                message: "Die App wurde in den Papierkorb verschoben. Leere den Papierkorb, um die App-Datei endgültig zu entfernen."
            )
        } catch {
            showResult(
                title: "Deinstallation fehlgeschlagen",
                message: error.localizedDescription
            )
        }
    }

    private static func waitForParentToExit(_ processIdentifier: pid_t) {
        guard processIdentifier > 1 else { return }
        while kill(processIdentifier, 0) == 0 || errno == EPERM {
            Thread.sleep(forTimeInterval: 0.1)
        }
    }

    private static func deleteRemoteProviderSecrets() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: AppUninstallCleanup.keychainService,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw NSError(
                domain: "AppUninstaller.Keychain",
                code: Int(status),
                userInfo: [NSLocalizedDescriptionKey: "Keychain-Löschung fehlgeschlagen (Status \(status))."]
            )
        }
    }

    private static func resetPrivacyService(_ service: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        process.arguments = ["reset", service, "com.wisprlocal.mac"]
        let errorPipe = Pipe()
        process.standardError = errorPipe
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let output = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let reason = String(data: output, encoding: .utf8) ?? "Unbekannter Systemfehler."
            throw NSError(
                domain: "AppUninstaller.Privacy",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: "tccutil konnte \(service) nicht zurücksetzen: \(reason)"]
            )
        }
    }

    private static func showResult(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        NSApplication.shared.setActivationPolicy(.accessory)
        NSApplication.shared.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
