import Foundation

struct MacAppConfiguration {
    let sparkleFeedURL: URL?
    let sparklePublicEDKey: String?

    var isUpdaterConfigured: Bool {
        sparkleFeedURL != nil && !(sparklePublicEDKey?.isEmpty ?? true)
    }

    var sparkleFeedDisplayText: String {
        guard let sparkleFeedURL else { return "" }

        let sourceLabel = sparkleFeedSourceLabel
        if sourceLabel.isEmpty {
            return sparkleFeedURL.absoluteString
        }

        return "\(sourceLabel): \(sparkleFeedURL.absoluteString)"
    }

    static func load(bundle: Bundle = .main) -> MacAppConfiguration {
        let info = bundle.infoDictionary ?? [:]

        let rawFeedURL = (info["SUFeedURL"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let rawSparkleKey = (info["SUPublicEDKey"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return MacAppConfiguration(
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

    private var sparkleFeedSourceLabel: String {
        guard let sparkleFeedURL else { return "" }

        let host = sparkleFeedURL.host?.lowercased() ?? ""
        let path = sparkleFeedURL.path.lowercased()
        if host.contains("github.com") || host.contains("githubusercontent.com") || path.contains("releases") {
            return "GitHub Releases Appcast"
        }

        return "Appcast"
    }
}
