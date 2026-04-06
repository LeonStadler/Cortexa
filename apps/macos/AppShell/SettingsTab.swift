import Foundation

enum SettingsTab: Hashable, CaseIterable {
    case general
    case speech
    case dictation
    case sound
    case shortcuts
    case ai
    case history
    case about
    case snippets
    case advanced

    var symbolName: String {
        switch self {
        case .general: return "gearshape"
        case .speech: return "waveform.badge.mic"
        case .dictation: return "mic"
        case .sound: return "speaker.wave.2"
        case .shortcuts: return "command"
        case .ai: return "sparkles"
        case .history: return "clock.arrow.circlepath"
        case .about: return "person.crop.circle"
        case .snippets: return "text.badge.plus"
        case .advanced: return "wrench.and.screwdriver"
        }
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .general:
            return language.text("Allgemein", "General")
        case .speech:
            return language.text("Speech", "Speech")
        case .dictation:
            return language.text("Diktat", "Dictation")
        case .sound:
            return language.text("Sound", "Sound")
        case .shortcuts:
            return language.text("Kurzbefehle", "Shortcuts")
        case .ai:
            return "AI"
        case .history:
            return language.text("Verlauf", "History")
        case .about:
            return language.text("About", "About")
        case .snippets:
            return language.text("Snippets", "Snippets")
        case .advanced:
            return language.text("Erweitert", "Advanced")
        }
    }

    func details(language: AppLanguage) -> String {
        switch self {
        case .general:
            return language.text(
                "Grundlegende App-, Menüleisten- und Zugriffsoptionen.",
                "Core app, menu bar, and access settings."
            )
        case .speech:
            return language.text(
                "Anbieter, Modelle, Sprachen und Sprachqualität konfigurieren.",
                "Configure providers, models, languages, and speech quality."
            )
        case .dictation:
            return language.text(
                "Verhalten beim Diktieren, Einfügen und Nachbearbeiten steuern.",
                "Control dictation behavior, insertion, and rewrite handling."
            )
        case .sound:
            return language.text(
                "Audioeingang, Pegel und signalbezogene Optionen anpassen.",
                "Adjust audio input, levels, and signal-related options."
            )
        case .shortcuts:
            return language.text(
                "Tastenkürzel für Start, Moduswechsel und Aktionen verwalten.",
                "Manage keyboard shortcuts for start, mode switching, and actions."
            )
        case .ai:
            return language.text(
                "KI-Anbieter, Schlüssel und Textverarbeitungsprofile verwalten.",
                "Manage AI providers, keys, and text processing profiles."
            )
        case .history:
            return language.text(
                "Gespeicherte Diktate durchsuchen und Aufbewahrung prüfen.",
                "Search saved dictations and review retention behavior."
            )
        case .about:
            return language.text(
                "Produktinformationen, Credits und Versionsdetails ansehen.",
                "View product information, credits, and version details."
            )
        case .snippets:
            return language.text(
                "Textbausteine für automatische Ersetzungen erstellen und pflegen.",
                "Create and manage snippets for automatic replacements."
            )
        case .advanced:
            return language.text(
                "Diagnose, Statusinformationen und erweiterte Systemoptionen.",
                "Inspect diagnostics, status details, and advanced system options."
            )
        }
    }
}
