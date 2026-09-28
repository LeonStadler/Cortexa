import Foundation

enum SettingsTab: String, Hashable, CaseIterable {
    case general
    case speech
    case dictation
    case sound
    case shortcuts
    case ai
    case history
    case dictionary
    case snippets
    case about
    case licenses
    case advanced

    enum Group: CaseIterable, Hashable {
        case general
        case writing
        case system
        case about

        func title(language: AppLanguage) -> String {
        switch self {
            case .general: return language.text("App", "App")
            case .writing: return language.text("Text & Verarbeitung", "Text & Processing")
            case .system: return language.text("Daten & System", "Data & System")
            case .about: return language.text("Über Cortexa", "About Cortexa")
            }
        }
    }

    var persistenceID: String { rawValue }

    var group: Group {
        switch self {
        case .general, .speech, .dictation, .sound, .shortcuts:
            return .general
        case .ai, .dictionary, .snippets:
            return .writing
        case .history, .advanced:
            return .system
        case .about, .licenses:
            return .about
        }
    }

    static func tabs(in group: Group) -> [SettingsTab] {
        allCases.filter { $0.group == group }
    }

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
        case .licenses: return "doc.text"
        case .dictionary: return "text.book.closed"
        case .snippets: return "text.badge.plus"
        case .advanced: return "wrench.and.screwdriver"
        }
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .general:
            return language.text("Allgemein", "General")
        case .speech:
            return language.text("Sprache & Erkennung", "Speech & Recognition")
        case .dictation:
            return language.text("Diktat", "Dictation")
        case .sound:
            return language.text("Audio", "Audio")
        case .shortcuts:
            return language.text("Kurzbefehle", "Shortcuts")
        case .ai:
            return language.text("KI", "AI")
        case .history:
            return language.text("Verlauf", "History")
        case .about:
            return language.text("Über Cortexa", "About Cortexa")
        case .licenses:
            return language.text("Lizenzen", "Licenses")
        case .dictionary:
            return language.text("Wörterbuch", "Dictionary")
        case .snippets:
            return language.text("Textbausteine", "Snippets")
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
                "Wähle ein lokales Whisper-Modell, lade fehlende Modelle bei Bedarf nach und passe Sprache, Qualität und Übersetzung an die Modellfähigkeiten an.",
                "Choose a local Whisper model, download missing models when needed, and align language, quality, and translation with model capabilities."
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
        case .licenses:
            return language.text(
                "Cortexas Lizenz und erforderliche Hinweise zu verwendeten Drittanbieter-Komponenten ansehen.",
                "View Cortexa's license and required notices for third-party components."
            )
        case .dictionary:
            return language.text(
                "Persönliche Begriffe, Namen und Fachsprache für ASR und AI pflegen.",
                "Manage personal terms, names, and jargon for ASR and AI."
            )
        case .snippets:
            return language.text(
                "Textbausteine für automatische Ersetzungen erstellen und pflegen.",
                "Create and manage snippets for automatic replacements."
            )
        case .advanced:
            return language.text(
                "Hier liegen Laufzeitoptionen, Speicherort, Updates und technische Diagnose. Nur ändern, wenn du weißt, warum du es brauchst.",
                "Model runtime, storage location, updates, and technical diagnostics live here. Change these only when you know why you need them."
            )
        }
    }
}
