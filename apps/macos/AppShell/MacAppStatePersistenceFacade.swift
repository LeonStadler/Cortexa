import AppKit
import Foundation
import UniformTypeIdentifiers

protocol DictionaryFileDialogPresenting {
    @MainActor
    func chooseDictionaryImportURL() -> URL?

    @MainActor
    func chooseDictionaryExportURL() -> URL?
}

@MainActor
struct DictionaryFileDialogPresenter: DictionaryFileDialogPresenting {
    func chooseDictionaryImportURL() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }

    func chooseDictionaryExportURL() -> URL? {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "wispr-dictionary.json"
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }
}

@MainActor
final class MacAppStatePersistenceFacade {
    private let loadSnippetsBlock: () -> Void
    private let persistSnippetsBlock: () -> Void
    private let loadHistoryBlock: () -> Void
    private let persistHistoryBlock: () -> Void
    private let loadDictionarySnapshot: () throws -> PersonalDictionarySnapshot
    private let saveDictionarySnapshot: ([DictionaryTerm], [DictionaryReviewCandidate]) throws -> Void
    private let importDictionarySnapshot: (URL) throws -> PersonalDictionarySnapshot
    private let exportDictionarySnapshot: (PersonalDictionarySnapshot, URL) throws -> Void
    private let currentDictionaryTerms: () -> [DictionaryTerm]
    private let setDictionaryTerms: ([DictionaryTerm]) -> Void
    private let currentDictionaryReviewQueue: () -> [DictionaryReviewCandidate]
    private let setDictionaryReviewQueue: ([DictionaryReviewCandidate]) -> Void
    private let appendDiagnostic: (String) -> Void
    private let appendAudit: (String) -> Void
    private let fileDialogPresenter: DictionaryFileDialogPresenting

    init(
        loadSnippets: @escaping () -> Void,
        persistSnippets: @escaping () -> Void,
        loadHistory: @escaping () -> Void,
        persistHistory: @escaping () -> Void,
        loadDictionarySnapshot: @escaping () throws -> PersonalDictionarySnapshot,
        saveDictionarySnapshot: @escaping ([DictionaryTerm], [DictionaryReviewCandidate]) throws -> Void,
        importDictionarySnapshot: @escaping (URL) throws -> PersonalDictionarySnapshot,
        exportDictionarySnapshot: @escaping (PersonalDictionarySnapshot, URL) throws -> Void,
        currentDictionaryTerms: @escaping () -> [DictionaryTerm],
        setDictionaryTerms: @escaping ([DictionaryTerm]) -> Void,
        currentDictionaryReviewQueue: @escaping () -> [DictionaryReviewCandidate],
        setDictionaryReviewQueue: @escaping ([DictionaryReviewCandidate]) -> Void,
        appendDiagnostic: @escaping (String) -> Void,
        appendAudit: @escaping (String) -> Void,
        fileDialogPresenter: DictionaryFileDialogPresenting
    ) {
        self.loadSnippetsBlock = loadSnippets
        self.persistSnippetsBlock = persistSnippets
        self.loadHistoryBlock = loadHistory
        self.persistHistoryBlock = persistHistory
        self.loadDictionarySnapshot = loadDictionarySnapshot
        self.saveDictionarySnapshot = saveDictionarySnapshot
        self.importDictionarySnapshot = importDictionarySnapshot
        self.exportDictionarySnapshot = exportDictionarySnapshot
        self.currentDictionaryTerms = currentDictionaryTerms
        self.setDictionaryTerms = setDictionaryTerms
        self.currentDictionaryReviewQueue = currentDictionaryReviewQueue
        self.setDictionaryReviewQueue = setDictionaryReviewQueue
        self.appendDiagnostic = appendDiagnostic
        self.appendAudit = appendAudit
        self.fileDialogPresenter = fileDialogPresenter
    }

    func loadSnippets() {
        loadSnippetsBlock()
    }

    func persistSnippets() {
        persistSnippetsBlock()
    }

    func loadHistory() {
        loadHistoryBlock()
    }

    func persistHistory() {
        persistHistoryBlock()
    }

    func addDictionaryTerm(
        _ rawTerm: String,
        category: DictionaryTermCategory,
        source: DictionaryTermSource = .manual,
        languageCode: String? = nil
    ) {
        let term = rawTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else {
            appendDiagnostic("Dictionary: Begriff wurde nicht gespeichert (leer).")
            return
        }

        let key = Self.normalizedDictionaryKey(
            term,
            languageCode: languageCode
        )
        let terms = currentDictionaryTerms()
        guard !terms.contains(where: {
            Self.normalizedDictionaryKey(
                $0.term,
                languageCode: $0.languageCode
            ) == key
        }) else {
            appendDiagnostic("Dictionary: Begriff bereits vorhanden.")
            return
        }

        setDictionaryTerms(
            terms + [
                DictionaryTerm(
                    term: term,
                    category: category,
                    source: source,
                    languageCode: languageCode
                )
            ]
        )

        let filteredQueue = currentDictionaryReviewQueue().filter {
            Self.normalizedDictionaryKey(
                $0.proposedTerm,
                languageCode: $0.languageCode
            ) != key
        }
        setDictionaryReviewQueue(filteredQueue)
        persistDictionary()
    }

    func removeDictionaryTerm(termID: UUID) {
        setDictionaryTerms(currentDictionaryTerms().filter { $0.id != termID })
        persistDictionary()
    }

    func queueDictionaryCandidate(
        _ rawTerm: String,
        category: DictionaryTermCategory = .custom,
        languageCode: String? = nil
    ) {
        let term = rawTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return }

        let key = Self.normalizedDictionaryKey(
            term,
            languageCode: languageCode
        )
        guard !currentDictionaryTerms().contains(where: {
            Self.normalizedDictionaryKey(
                $0.term,
                languageCode: $0.languageCode
            ) == key
        }) else { return }
        guard !currentDictionaryReviewQueue().contains(where: {
            Self.normalizedDictionaryKey(
                $0.proposedTerm,
                languageCode: $0.languageCode
            ) == key
        }) else { return }

        setDictionaryReviewQueue(
            [
                DictionaryReviewCandidate(
                    proposedTerm: term,
                    category: category,
                    languageCode: languageCode
                )
            ] + currentDictionaryReviewQueue()
        )
        persistDictionary()
    }

    func approveDictionaryCandidate(_ candidateID: UUID) {
        guard let candidate = currentDictionaryReviewQueue().first(where: { $0.id == candidateID }) else {
            return
        }

        addDictionaryTerm(
            candidate.proposedTerm,
            category: candidate.category,
            source: .auto,
            languageCode: candidate.languageCode
        )
    }

    func rejectDictionaryCandidate(_ candidateID: UUID) {
        setDictionaryReviewQueue(currentDictionaryReviewQueue().filter { $0.id != candidateID })
        persistDictionary()
    }

    func importDictionaryFromJSON() {
        guard let url = fileDialogPresenter.chooseDictionaryImportURL() else { return }

        do {
            let snapshot = try importDictionarySnapshot(url)
            setDictionaryTerms(snapshot.terms)
            setDictionaryReviewQueue(snapshot.reviewQueue)
            appendDiagnostic(
                "Dictionary importiert: \(snapshot.terms.count) Begriffe, \(snapshot.reviewQueue.count) Vorschläge"
            )
            appendAudit("dictionary.import path=\(url.path)")
        } catch {
            appendDiagnostic("Dictionary-Import fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    func exportDictionaryToJSON() {
        guard let url = fileDialogPresenter.chooseDictionaryExportURL() else { return }

        let snapshot = PersonalDictionarySnapshot(
            terms: currentDictionaryTerms(),
            reviewQueue: currentDictionaryReviewQueue()
        )

        do {
            try exportDictionarySnapshot(snapshot, url)
            appendDiagnostic("Dictionary exportiert: \(snapshot.terms.count) Begriffe")
            appendAudit("dictionary.export path=\(url.path)")
        } catch {
            appendDiagnostic("Dictionary-Export fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    func loadDictionary() {
        do {
            let snapshot = try loadDictionarySnapshot()
            setDictionaryTerms(snapshot.terms)
            setDictionaryReviewQueue(snapshot.reviewQueue)
            appendDiagnostic(
                "Dictionary geladen: \(snapshot.terms.count) Begriffe, \(snapshot.reviewQueue.count) Vorschläge"
            )
        } catch {
            appendDiagnostic("Dictionary-Load fehlgeschlagen: \(error.localizedDescription)")
            setDictionaryTerms([])
            setDictionaryReviewQueue([])
        }
    }

    func persistDictionary() {
        let terms = currentDictionaryTerms()
        let reviewQueue = currentDictionaryReviewQueue()

        do {
            try saveDictionarySnapshot(terms, reviewQueue)
            appendAudit("dictionary.save terms=\(terms.count) queue=\(reviewQueue.count)")
        } catch {
            appendDiagnostic("Dictionary-Save fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    private static func normalizedDictionaryKey(_ term: String, languageCode: String?) -> String {
        let base = term
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let language = languageCode?.lowercased() ?? "_"
        return "\(language)::\(base)"
    }
}

extension MacAppState {
    func loadSnippets() {
        persistenceFacade.loadSnippets()
    }

    func persistSnippets() {
        persistenceFacade.persistSnippets()
    }

    func addDictionaryTerm(
        _ rawTerm: String,
        category: DictionaryTermCategory,
        source: DictionaryTermSource = .manual,
        languageCode: String? = nil
    ) {
        persistenceFacade.addDictionaryTerm(
            rawTerm,
            category: category,
            source: source,
            languageCode: languageCode
        )
    }

    func removeDictionaryTerm(termID: UUID) {
        persistenceFacade.removeDictionaryTerm(termID: termID)
    }

    func queueDictionaryCandidate(
        _ rawTerm: String,
        category: DictionaryTermCategory = .custom,
        languageCode: String? = nil
    ) {
        persistenceFacade.queueDictionaryCandidate(
            rawTerm,
            category: category,
            languageCode: languageCode
        )
    }

    func approveDictionaryCandidate(_ candidateID: UUID) {
        persistenceFacade.approveDictionaryCandidate(candidateID)
    }

    func rejectDictionaryCandidate(_ candidateID: UUID) {
        persistenceFacade.rejectDictionaryCandidate(candidateID)
    }

    func importDictionaryFromJSON() {
        persistenceFacade.importDictionaryFromJSON()
    }

    func exportDictionaryToJSON() {
        persistenceFacade.exportDictionaryToJSON()
    }

    func loadHistory() {
        persistenceFacade.loadHistory()
    }

    func persistHistory() {
        persistenceFacade.persistHistory()
    }

    func loadDictionary() {
        persistenceFacade.loadDictionary()
    }

    func persistDictionary() {
        persistenceFacade.persistDictionary()
    }
}
