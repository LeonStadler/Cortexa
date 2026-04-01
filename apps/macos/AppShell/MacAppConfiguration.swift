import Foundation
import LicenseCore

struct MacAppConfiguration {
    let licensePublicKeyBase64: String?
    let sparkleFeedURL: URL?
    let sparklePublicEDKey: String?

    var isLicenseConfigured: Bool {
        guard let licensePublicKeyBase64 else { return false }
        let trimmed = licensePublicKeyBase64.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return trimmed != EmbeddedLicenseKeys.placeholderPublicKeyBase64
    }

    var isUpdaterConfigured: Bool {
        sparkleFeedURL != nil && !(sparklePublicEDKey?.isEmpty ?? true)
    }

    static func load(bundle: Bundle = .main) -> MacAppConfiguration {
        let info = bundle.infoDictionary ?? [:]

        let rawLicenseKey = (info["WLMLicensePublicKeyBase64"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let rawFeedURL = (info["SUFeedURL"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let rawSparkleKey = (info["SUPublicEDKey"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return MacAppConfiguration(
            licensePublicKeyBase64: rawLicenseKey?.isEmpty == true ? nil : rawLicenseKey,
            sparkleFeedURL: validatedUpdaterFeedURL(rawFeedURL),
            sparklePublicEDKey: rawSparkleKey?.isEmpty == true ? nil : rawSparkleKey
        )
    }

    private static func validatedUpdaterFeedURL(_ rawFeedURL: String?) -> URL? {
        guard let rawFeedURL else { return nil }

        let trimmed = rawFeedURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed) else {
            return nil
        }

        guard url.scheme?.lowercased() == "https" else {
            return nil
        }

        return url
    }
}
