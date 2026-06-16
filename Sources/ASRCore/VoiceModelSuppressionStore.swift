import Foundation

/// Merkt sich vom Nutzer entfernte optionale Speech-Modelle, damit sie nicht erneut aus dem App-Bundle synchronisiert werden.
public final class VoiceModelSuppressionStore: @unchecked Sendable {
    public static let shared = VoiceModelSuppressionStore()

    private let defaults: UserDefaults
    private let key = "wispr.voiceModels.suppressedFileNames"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func suppressedFileNames() -> Set<String> {
        Set(defaults.stringArray(forKey: key) ?? [])
    }

    public func suppress(_ fileName: String) {
        var names = suppressedFileNames()
        names.insert(fileName)
        defaults.set(Array(names).sorted(), forKey: key)
    }

    public func clearSuppression(for fileName: String) {
        var names = suppressedFileNames()
        names.remove(fileName)
        if names.isEmpty {
            defaults.removeObject(forKey: key)
        } else {
            defaults.set(Array(names).sorted(), forKey: key)
        }
    }
}
