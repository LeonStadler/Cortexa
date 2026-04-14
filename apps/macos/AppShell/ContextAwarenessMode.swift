import Foundation

enum ContextAwarenessMode: String, Codable, CaseIterable, Identifiable {
    case off
    case finalOnly
    case liveOnly
    case liveAndFinal

    var id: String { rawValue }

    var appliesToLive: Bool {
        switch self {
        case .liveOnly, .liveAndFinal:
            return true
        case .off, .finalOnly:
            return false
        }
    }

    var appliesToFinal: Bool {
        switch self {
        case .finalOnly, .liveAndFinal:
            return true
        case .off, .liveOnly:
            return false
        }
    }

    func localizedDisplayName(interfaceLanguageCode: String) -> String {
        switch (interfaceLanguageCode, self) {
        case ("en", .off):
            return "Off"
        case ("en", .finalOnly):
            return "Final result only"
        case ("en", .liveOnly):
            return "Live text only"
        case ("en", .liveAndFinal):
            return "Live + final result"
        case (_, .off):
            return "Aus"
        case (_, .finalOnly):
            return "Nur Endergebnis"
        case (_, .liveOnly):
            return "Nur Live-Text"
        case (_, .liveAndFinal):
            return "Live + Endergebnis"
        }
    }
}
