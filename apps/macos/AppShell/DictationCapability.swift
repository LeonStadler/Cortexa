import Foundation

enum DictationCapability: Equatable {
    case unavailable
    case limitedTranscription
    case fullSystemInsertion

    var canStartRecording: Bool {
        self != .unavailable
    }

    var allowsDirectInsertion: Bool {
        self == .fullSystemInsertion
    }

    var localizedSummary: String {
        switch self {
        case .unavailable:
            return "Mikrofonzugriff fehlt. Aufnahme kann nicht gestartet werden."
        case .limitedTranscription:
            return "Eingeschränkter Modus: Aufnahme ist möglich, direktes Einfügen erfordert Bedienungshilfen."
        case .fullSystemInsertion:
            return "Alle Berechtigungen vorhanden. Direktes Einfügen ist verfügbar."
        }
    }
}
