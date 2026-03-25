import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case german = "de"
    case english = "en"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .german:
            return "Deutsch"
        case .english:
            return "English"
        }
    }

    func text(_ german: String, _ english: String) -> String {
        switch self {
        case .german:
            return german
        case .english:
            return english
        }
    }
}
