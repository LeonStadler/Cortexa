import Foundation
import SnippetCore

struct SettingsSearchPresentation {
    let searchText: String
    let transcriptHistory: [TranscriptHistoryEntry]
    let snippetRules: [SnippetRule]
    let diagnosticsText: String
    let capabilitySummary: String
    let updaterStatusText: String

    private var normalizedSearchQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var isSearching: Bool {
        !normalizedSearchQuery.isEmpty
    }

    func matches(_ keywords: [String]) -> Bool {
        guard isSearching else { return true }
        return keywords.contains { $0.lowercased().contains(normalizedSearchQuery) }
    }

    var aboutAppMetadataMatchesSearch: Bool {
        matches([
            "version", "build", "app", "wispr", "wisprlocal", "bundle", "cfbundle",
        ])
    }

    var generalHasMatches: Bool {
        matches([
            "language", "sprache", "menüleiste", "menu bar", "shortcut hints", "compact",
            "kompakt", "dock", "launch on login", "updates", "zugriff", "permissions",
            "berechtigungen", "mikrofon", "accessibility", "bedienungshilfen",
        ])
    }

    var dictationHasMatches: Bool {
        matches([
            "streaming",
            "clipboard",
            "zwischenablage",
            "insert",
            "delivery",
            "paste",
            "auto-send",
            "restore clipboard",
            "keypress",
            "anpassung",
            "anpassungsradius",
            "anpassen",
            "rückwirkung",
            "rückwirkend",
            "rückwirkungsbereich",
            "rueckwirkung",
            "rueckwirkend",
            "rueckwirkungsbereich",
            "rewrite",
            "kontext",
            "retroaktiv",
            "weit zurück",
        ])
    }

    var speechHasMatches: Bool {
        matches([
            "speech",
            "voice",
            "sprache",
            "language",
            "translate",
            "translation",
            "übersetzung",
            "uebersetzung",
            "modell",
            "model",
            "anbieter",
            "provider",
            "whisper",
            "parakeet",
            "qualität",
            "quality",
            "installieren",
            "download",
        ])
    }

    var shortcutsHasMatches: Bool {
        matches([
            "shortcut", "kurzbefehl", "hold", "dictation", "diktat", "cancel", "abbrechen",
            "mode", "modus",
        ])
    }

    var aiHasMatches: Bool {
        matches([
            "ai",
            "processing",
            "modell",
            "model",
            "rewrite",
            "stil",
            "style",
            "ton",
            "tone",
            "anrede",
            "formal",
            "informal",
            "apple intelligence",
            "api",
            "openrouter",
            "provider",
            "anbieter",
            "key",
            "api key",
        ])
    }

    var historyHasMatches: Bool {
        matches([
            "history", "verlauf", "transkript", "dictation", "diktat", "retention",
            "aufbewahrung", "storage", "folder",
        ]) || !filteredHistory.isEmpty
    }

    var aboutHasMatches: Bool {
        matches([
            "about", "über", "ueber", "leon", "stadler", "website", "webseite", "proprietär",
            "proprietary", "lizenz", "intermedia", "design", "fotografie", "vorarlberg",
            "changelog", "neuigkeiten", "release", "release notes", "änderungen", "aenderungen",
        ])
    }

    var snippetsHasMatches: Bool {
        matches([
            "snippet", "textbaustein", "replacement", "trigger", "json", "import", "export",
            "importieren", "exportieren",
        ]) || !filteredSnippets.isEmpty
    }

    var advancedHasMatches: Bool {
        matches([
            "update", "updates", "aktualisierung", "diagnose", "diagnostics", "capability",
            "audit", "storage", "folder", "app support", "logs", "protokolle", "voice", "modell",
            "model", "warm", "dauer", "duration", "laufzeit", "speicher halten", "runtime",
            "version", "build", "app", "wispr", "wisprlocal", "bundle", "cfbundle",
        ]) || diagnosticsText.lowercased().contains(normalizedSearchQuery)
            || capabilitySummary.lowercased().contains(normalizedSearchQuery)
            || updaterStatusText.lowercased().contains(normalizedSearchQuery)
    }

    var soundHasMatches: Bool {
        matches([
            "sound", "audio", "mikrofon", "volume", "loudness", "silence", "normalization",
            "normalisierung", "verstärkung", "gain", "feedback",
        ])
    }

    var filteredHistory: [TranscriptHistoryEntry] {
        guard isSearching else {
            return transcriptHistory
        }
        return transcriptHistory.filter {
            $0.text.lowercased().contains(normalizedSearchQuery)
                || $0.languageCode.lowercased().contains(normalizedSearchQuery)
                || $0.mode.lowercased().contains(normalizedSearchQuery)
        }
    }

    func compactHistoryEntries(limit: Int = 12) -> [TranscriptHistoryEntry] {
        if isSearching {
            return filteredHistory
        }
        return Array(filteredHistory.prefix(limit))
    }

    var filteredSnippets: [SnippetRule] {
        guard isSearching else {
            return snippetRules
        }
        return snippetRules.filter {
            $0.trigger.lowercased().contains(normalizedSearchQuery)
                || $0.replacement.lowercased().contains(normalizedSearchQuery)
        }
    }
}
