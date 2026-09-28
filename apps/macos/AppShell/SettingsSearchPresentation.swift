import Foundation

struct SettingsSearchDestination: Hashable, Identifiable {
    let tab: SettingsTab
    let sectionID: String
    let title: String
    let subtitle: String
    let keywords: [String]

    var id: String { "\(tab.persistenceID).\(sectionID)" }
}

struct SettingsSearchPresentation {
    let searchText: String
    let language: AppLanguage

    private var query: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var isSearching: Bool { !query.isEmpty }

    var results: [SettingsSearchDestination] {
        guard isSearching else { return [] }
        return destinations.filter { destination in
            ([destination.title, destination.subtitle] + destination.keywords)
                .contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    func matches(_ keywords: [String]) -> Bool {
        guard isSearching else { return true }
        return keywords.contains { $0.localizedCaseInsensitiveContains(query) }
    }

    func hasResults(in tab: SettingsTab) -> Bool {
        !isSearching || results.contains { $0.tab == tab }
    }

    private var destinations: [SettingsSearchDestination] {
        [
            destination(.general, "app", "App", "Sprache und Startverhalten", ["language", "sprache", "menüleiste", "menu bar", "dock"]),
            destination(.general, "access", "Berechtigungen", "Mikrofon und Bedienungshilfen", ["permissions", "zugriff", "mikrofon", "accessibility", "bedienungshilfen"]),
            destination(.speech, "model", "Modell", "Lokale Spracherkennung", ["speech", "whisper", "parakeet", "download", "installieren"]),
            destination(.speech, "language", "Sprache", "Erkennungssprache", ["language", "speech", "voice"]),
            destination(.speech, "translation", "Übersetzung", "Sprachübersetzung", ["translation", "translate", "übersetzen"]),
            destination(.dictation, "live-rewrite", "Live-Anpassung", "Verarbeitung während des Diktats", ["streaming", "rewrite", "anpassung", "kontext"]),
            destination(.dictation, "text-input", "Texteingabe", "Einfügen und Zwischenablage", ["clipboard", "paste", "insert", "delivery", "auto-send"]),
            destination(.sound, "input", "Audioeingang", "Mikrofon und Pegel", ["sound", "audio", "volume", "gain", "normalisierung"]),
            destination(.shortcuts, "start-stop", "Kurzbefehle", "Diktat steuern", ["shortcut", "hotkey", "start", "stop", "abbrechen"]),
            destination(.ai, "processing", "KI-Verarbeitung", "Text nachbearbeiten", ["ai", "ki", "processing", "stil", "tone"]),
            destination(.ai, "providers", "KI-Anbieter", "API und lokale Server", ["api", "provider", "anbieter", "openrouter", "ollama"]),
            destination(.ai, "models", "KI-Modelle", "Modellauswahl", ["model", "modell"]),
            destination(.history, "retention", "Aufbewahrung", "Diktatverlauf verwalten", ["history", "verlauf", "retention", "aufbewahrung"]),
            destination(.dictionary, "saved-terms", "Wörterbuch", "Eigene Begriffe verwalten", ["dictionary", "wörterbuch", "begriffe", "jargon"]),
            destination(.snippets, "saved-snippets", "Textbausteine", "Ersetzungen verwalten", ["snippets", "snippet", "textbaustein", "replacement"]),
            destination(.advanced, "updates", "Updates", "Aktualisierungen", ["update", "aktualisierung", "release"]),
            destination(.advanced, "diagnostics", "Diagnose", "Technische Informationen", ["diagnostics", "diagnose", "logs", "protokolle"]),
            destination(.advanced, "uninstall", "Deinstallation", "App und lokale Daten entfernen", ["deinstall", "deinstallieren", "uninstall", "remove", "löschen", "modelle"]),
            destination(.licenses, "licenses", "Lizenzen", "Cortexa und Drittanbieter", ["license", "lizenz", "lizenzen", "mit", "apache", "cc-by", "sparkle", "whisper", "nvidia", "parakeet"]),
        ]
    }

    private func destination(_ tab: SettingsTab, _ sectionID: String, _ title: String, _ subtitle: String, _ keywords: [String]) -> SettingsSearchDestination {
        SettingsSearchDestination(tab: tab, sectionID: sectionID, title: title, subtitle: subtitle, keywords: keywords)
    }
}
