import Foundation
import LicenseCore

struct LicenseStatusSnapshot {
    enum Status: Equatable {
        case notConfigured
        case notSet
        case active(tier: String)
        case invalid(reason: String)
    }

    let status: Status
    let maskedKey: String?

    var isValid: Bool {
        if case .active = status {
            return true
        }
        return false
    }
}

final class LicenseController {
    private let configuration: MacAppConfiguration
    private let store: LicenseStore
    private let cache: LicenseCache
    private let verifier: LicenseVerifier?

    init(
        configuration: MacAppConfiguration,
        store: LicenseStore = LicenseStore(),
        cacheFileURL: URL
    ) {
        self.configuration = configuration
        self.store = store
        self.cache = LicenseCache(fileURL: cacheFileURL)

        if let configuredKey = configuration.licensePublicKeyBase64,
           !configuredKey.isEmpty {
            self.verifier = try? LicenseVerifier(defaultEmbeddedKeyBase64: configuredKey)
        } else {
            self.verifier = try? LicenseVerifier()
        }
    }

    func activate(licenseKey: String) -> LicenseStatusSnapshot {
        guard configuration.isLicenseConfigured else {
            return LicenseStatusSnapshot(status: .notConfigured, maskedKey: nil)
        }

        let trimmedKey = licenseKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            return LicenseStatusSnapshot(status: .invalid(reason: "Lizenzschlüssel leer"), maskedKey: nil)
        }

        guard let verifier else {
            return LicenseStatusSnapshot(status: .notConfigured, maskedKey: nil)
        }

        switch verifier.verify(trimmedKey) {
        case let .valid(payload):
            do {
                try store.saveLicenseKey(trimmedKey)
                try cache.write(licenseKey: trimmedKey)
                return LicenseStatusSnapshot(
                    status: .active(tier: payload.productTier),
                    maskedKey: Self.maskedKey(trimmedKey)
                )
            } catch {
                return LicenseStatusSnapshot(
                    status: .invalid(reason: "Lizenz konnte nicht gespeichert werden"),
                    maskedKey: nil
                )
            }

        case let .invalid(reason):
            return LicenseStatusSnapshot(
                status: .invalid(reason: reason.localizedDescription),
                maskedKey: nil
            )
        }
    }

    func deactivate() {
        store.removeLicenseKey()
        try? cache.clear()
    }

    func loadExistingStatus() -> LicenseStatusSnapshot {
        guard configuration.isLicenseConfigured else {
            return LicenseStatusSnapshot(status: .notConfigured, maskedKey: nil)
        }

        do {
            if let storedKey = try store.loadLicenseKey() {
                return validateStoredKey(storedKey)
            }

            if let cachedKey = try cache.read() {
                return validateStoredKey(cachedKey)
            }

            return LicenseStatusSnapshot(status: .notSet, maskedKey: nil)
        } catch {
            return LicenseStatusSnapshot(status: .invalid(reason: "Lizenz konnte nicht geladen werden"), maskedKey: nil)
        }
    }

    private func validateStoredKey(_ key: String) -> LicenseStatusSnapshot {
        guard let verifier else {
            return LicenseStatusSnapshot(status: .notConfigured, maskedKey: nil)
        }

        switch verifier.verify(key) {
        case let .valid(payload):
            return LicenseStatusSnapshot(
                status: .active(tier: payload.productTier),
                maskedKey: Self.maskedKey(key)
            )
        case let .invalid(reason):
            return LicenseStatusSnapshot(
                status: .invalid(reason: reason.localizedDescription),
                maskedKey: Self.maskedKey(key)
            )
        }
    }

    private static func maskedKey(_ key: String) -> String {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 8 else {
            return String(repeating: "•", count: max(trimmed.count, 4))
        }

        let prefix = trimmed.prefix(4)
        let suffix = trimmed.suffix(4)
        return "\(prefix)••••\(suffix)"
    }
}
