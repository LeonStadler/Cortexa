import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case german = "de"
    case english = "en"

    var id: String { rawValue }

    static func resolvedFromSystemPreferences() -> AppLanguage {
        let preferred = Locale.preferredLanguages.first ?? "en"
        if preferred.lowercased().hasPrefix("de") {
            return .german
        }
        return .english
    }

    /// Feste UI-Sprache für DE/EN-Strings; `.system` wird aufgerüstet.
    var contentLanguage: AppLanguage {
        switch self {
        case .system:
            return Self.resolvedFromSystemPreferences()
        case .german, .english:
            return self
        }
    }

    func text(_ german: String, _ english: String) -> String {
        contentLanguage == .german ? german : english
    }

    func pickerDisplayName(uiContentLanguage: AppLanguage) -> String {
        let ui = uiContentLanguage.contentLanguage
        switch self {
        case .system:
            return ui.text("Systemsprache", "System")
        case .german:
            return "Deutsch"
        case .english:
            return "English"
        }
    }

    /// Locale für `DateFormatter`, `environment(\.locale)`, …
    var localeForFormatting: Locale {
        switch self {
        case .system:
            return .autoupdatingCurrent
        case .german:
            return Locale(identifier: "de_DE")
        case .english:
            return Locale(identifier: "en_US")
        }
    }

    /// Nur `de` oder `en` — für eingebettete Picker mit `interfaceLanguageCode`.
    var embeddedInterfaceCode: String {
        contentLanguage.rawValue
    }
}
