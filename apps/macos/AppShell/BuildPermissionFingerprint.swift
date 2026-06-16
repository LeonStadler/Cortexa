import Foundation

/// Identifiziert den laufenden Debug-/Dev-Build für TCC-Abgleich (Rebuild = neue Signatur/Pfad).
struct BuildPermissionFingerprint: Codable, Equatable, Sendable {
    let bundlePath: String
    let bundleVersion: String
    let executablePath: String
    let executableModificationTime: TimeInterval

    static func current(bundle: Bundle = .main) -> BuildPermissionFingerprint? {
        guard let bundlePath = bundle.bundleURL.path.nilIfEmpty,
            let executableURL = bundle.executableURL
        else {
            return nil
        }

        let version =
            (bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
            ?? "0"

        let attributes = try? FileManager.default.attributesOfItem(atPath: executableURL.path)
        let modificationDate = attributes?[.modificationDate] as? Date

        return BuildPermissionFingerprint(
            bundlePath: bundlePath,
            bundleVersion: version,
            executablePath: executableURL.path,
            executableModificationTime: modificationDate?.timeIntervalSince1970 ?? 0
        )
    }
}

/// Merkt sich den zuletzt vertrauenswürdigen Build pro Berechtigung — Abweichung = typischer TCC-Mismatch nach Rebuild.
final class BuildPermissionFingerprintStore {
    static let shared = BuildPermissionFingerprintStore()

    private let defaults: UserDefaults
    private let bundle: Bundle
    private let accessibilityKey = "wispr.permissions.lastTrustedAccessibilityBuild"
    private let microphoneKey = "wispr.permissions.lastTrustedMicrophoneBuild"
    private let accessibilityEverGrantedKey = "wispr.permissions.accessibilityEverGranted"
    private let microphoneEverGrantedKey = "wispr.permissions.microphoneEverGranted"

    init(defaults: UserDefaults = .standard, bundle: Bundle = .main) {
        self.defaults = defaults
        self.bundle = bundle
    }

    func currentFingerprint() -> BuildPermissionFingerprint? {
        BuildPermissionFingerprint.current(bundle: bundle)
    }

    func recordTrustedAccessibility() {
        guard let fingerprint = currentFingerprint() else { return }
        save(fingerprint, key: accessibilityKey)
        defaults.set(true, forKey: accessibilityEverGrantedKey)
    }

    func recordTrustedMicrophone() {
        guard let fingerprint = currentFingerprint() else { return }
        save(fingerprint, key: microphoneKey)
        defaults.set(true, forKey: microphoneEverGrantedKey)
    }

    func isAccessibilityStale(currentlyTrusted: Bool) -> Bool {
        guard !currentlyTrusted else { return false }
        if staleAfterRebuild(currentlyGranted: currentlyTrusted, key: accessibilityKey) {
            return true
        }
        return defaults.bool(forKey: accessibilityEverGrantedKey)
    }

    func isMicrophoneStale(currentlyTrusted: Bool) -> Bool {
        guard !currentlyTrusted else { return false }
        if staleAfterRebuild(currentlyGranted: currentlyTrusted, key: microphoneKey) {
            return true
        }
        return defaults.bool(forKey: microphoneEverGrantedKey)
    }

    func clearTrustedAccessibility() {
        defaults.removeObject(forKey: accessibilityKey)
        defaults.removeObject(forKey: accessibilityEverGrantedKey)
    }

    func clearTrustedMicrophone() {
        defaults.removeObject(forKey: microphoneKey)
        defaults.removeObject(forKey: microphoneEverGrantedKey)
    }

    private func staleAfterRebuild(currentlyGranted: Bool, key: String) -> Bool {
        guard !currentlyGranted else { return false }
        guard let current = currentFingerprint(),
            let lastTrusted = load(key: key)
        else {
            return false
        }
        return current != lastTrusted
    }

    private func load(key: String) -> BuildPermissionFingerprint? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(BuildPermissionFingerprint.self, from: data)
    }

    private func save(_ fingerprint: BuildPermissionFingerprint, key: String) {
        guard let data = try? JSONEncoder().encode(fingerprint) else { return }
        defaults.set(data, forKey: key)
    }
}

extension String {
    fileprivate var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
