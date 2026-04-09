import AppKit
import Foundation

@MainActor
final class TranscriptHistoryController {
    private let historyStore: TranscriptHistoryStoring
    private let currentTranscriptHistory: () -> [TranscriptHistoryEntry]
    private let setTranscriptHistory: ([TranscriptHistoryEntry]) -> Void
    private let currentHistoryRetentionPolicy: () -> HistoryRetentionPolicy
    private let appendDiagnostic: (String) -> Void
    private let appendAudit: (String) -> Void

    init(
        historyStore: TranscriptHistoryStoring,
        currentTranscriptHistory: @escaping () -> [TranscriptHistoryEntry],
        setTranscriptHistory: @escaping ([TranscriptHistoryEntry]) -> Void,
        currentHistoryRetentionPolicy: @escaping () -> HistoryRetentionPolicy,
        appendDiagnostic: @escaping (String) -> Void,
        appendAudit: @escaping (String) -> Void
    ) {
        self.historyStore = historyStore
        self.currentTranscriptHistory = currentTranscriptHistory
        self.setTranscriptHistory = setTranscriptHistory
        self.currentHistoryRetentionPolicy = currentHistoryRetentionPolicy
        self.appendDiagnostic = appendDiagnostic
        self.appendAudit = appendAudit
    }

    func loadHistory() {
        do {
            setTranscriptHistory(try historyStore.load())
            pruneHistoryIfNeeded()
            appendDiagnostic("History geladen: \(currentTranscriptHistory().count)")
        } catch {
            appendDiagnostic("History-Load fehlgeschlagen: \(error.localizedDescription)")
            setTranscriptHistory([])
        }
    }

    func persistHistory() {
        do {
            try historyStore.save(currentTranscriptHistory())
        } catch {
            appendDiagnostic("History-Save fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    func pruneHistoryIfNeeded() {
        guard let retainedDays = currentHistoryRetentionPolicy().retainedDays else { return }
        let cutoff =
            Calendar.current.date(byAdding: .day, value: -retainedDays, to: Date()) ?? .distantPast
        var entries = currentTranscriptHistory()
        let originalCount = entries.count
        entries.removeAll { $0.createdAt < cutoff }
        if entries.count != originalCount {
            setTranscriptHistory(entries)
            persistHistory()
            appendDiagnostic(
                "History aufgrund der Aufbewahrungsrichtlinie bereinigt: \(entries.count) Einträge"
            )
        }
    }

    func handleFinalTranscript(_ event: FinalTranscriptEvent) {
        let trimmed = event.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let entry = TranscriptHistoryEntry(
            text: trimmed,
            languageCode: event.languageCode,
            mode: event.mode == .streaming ? "streaming" : "finalize"
        )

        var entries = currentTranscriptHistory()
        entries.insert(entry, at: 0)
        setTranscriptHistory(entries)
        pruneHistoryIfNeeded()
        if currentTranscriptHistory().count > 500 {
            setTranscriptHistory(Array(currentTranscriptHistory().prefix(500)))
        }
        persistHistory()
        appendDiagnostic("History gespeichert (\(currentTranscriptHistory().count) Einträge)")
        switch event.deliveryOutcome {
        case .inserted:
            appendDiagnostic("Finales Transkript eingefügt.")
        case .copiedToClipboard:
            appendDiagnostic("Finales Transkript in die Zwischenablage kopiert.")
        case .historyOnlyNoTarget:
            appendDiagnostic("Finales Transkript ohne Ziel nur in der History gespeichert.")
        case .failed(let reason):
            appendDiagnostic("Finales Transkript konnte nicht zugestellt werden: \(reason)")
        }
        appendAudit(
            "transcript.final language=\(event.languageCode) mode=\(entry.mode) chars=\(trimmed.count)"
        )
    }

    func copyHistoryEntry(_ entry: TranscriptHistoryEntry) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(entry.text, forType: .string)
        appendDiagnostic("History-Eintrag kopiert: \(entry.id.uuidString.prefix(8))")
    }

    func copyAllHistoryToClipboard() {
        let joined =
            currentTranscriptHistory()
            .reversed()
            .map {
                "[\(Self.displayDate($0.createdAt))] [\($0.mode)] [\($0.languageCode)] \($0.text)"
            }
            .joined(separator: "\n")

        guard !joined.isEmpty else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(joined, forType: .string)
        appendDiagnostic("Gesamte History in Zwischenablage kopiert")
    }

    func exportHistoryAsText() {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "wispr-transcript-history.txt"
        Self.configureSavePanel(panel, titleKey: "filepanel.export.history.title")

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try historyStore.exportText(entries: currentTranscriptHistory(), to: url)
            appendDiagnostic("History exportiert")
            appendAudit("history.export path=\(url.path)")
        } catch {
            appendDiagnostic("History-Export fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    func removeHistoryEntry(_ entryID: UUID) {
        setTranscriptHistory(currentTranscriptHistory().filter { $0.id != entryID })
        persistHistory()
    }

    func clearHistory() {
        setTranscriptHistory([])
        persistHistory()
        appendDiagnostic("History geleert")
        appendAudit("history.clear")
    }

    private static func displayDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }

    private static func localizedFilePanelString(_ key: String) -> String {
        Bundle.main.localizedString(forKey: key, value: key, table: nil)
    }

    private static func configureSavePanel(_ panel: NSSavePanel, titleKey: String) {
        panel.title = localizedFilePanelString(titleKey)
        panel.prompt = localizedFilePanelString("filepanel.save.prompt")
    }
}
