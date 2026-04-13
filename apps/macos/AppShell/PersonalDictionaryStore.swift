import Foundation
import SnippetCore
import UniformTypeIdentifiers

enum DictionaryTermCategory: String, Codable, CaseIterable, Identifiable {
    case personalTerm
    case personName
    case companyJargon
    case clientName
    case industryLanguage
    case custom

    var id: String { rawValue }

    func localizedDisplayName(interfaceLanguageCode: String) -> String {
        switch (interfaceLanguageCode, self) {
        case ("en", .personalTerm):
            return "Personal term"
        case ("en", .personName):
            return "Person name"
        case ("en", .companyJargon):
            return "Company jargon"
        case ("en", .clientName):
            return "Client name"
        case ("en", .industryLanguage):
            return "Industry language"
        case ("en", .custom):
            return "Custom"
        case (_, .personalTerm):
            return "Persönlicher Begriff"
        case (_, .personName):
            return "Personenname"
        case (_, .companyJargon):
            return "Firmenjargon"
        case (_, .clientName):
            return "Kundenname"
        case (_, .industryLanguage):
            return "Branchensprache"
        case (_, .custom):
            return "Benutzerdefiniert"
        }
    }
}

enum DictionaryTermSource: String, Codable, CaseIterable, Identifiable {
    case manual
    case auto

    var id: String { rawValue }
}

struct DictionaryTerm: Identifiable, Codable, Equatable {
    let id: UUID
    let term: String
    let category: DictionaryTermCategory
    let source: DictionaryTermSource
    let languageCode: String?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        term: String,
        category: DictionaryTermCategory,
        source: DictionaryTermSource,
        languageCode: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.term = term
        self.category = category
        self.source = source
        self.languageCode = languageCode
        self.createdAt = createdAt
    }
}

struct DictionaryReviewCandidate: Identifiable, Codable, Equatable {
    let id: UUID
    let proposedTerm: String
    let category: DictionaryTermCategory
    let languageCode: String?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        proposedTerm: String,
        category: DictionaryTermCategory = .custom,
        languageCode: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.proposedTerm = proposedTerm
        self.category = category
        self.languageCode = languageCode
        self.createdAt = createdAt
    }
}

struct PersonalDictionarySnapshot: Codable, Equatable {
    var terms: [DictionaryTerm]
    var reviewQueue: [DictionaryReviewCandidate]
}

protocol PersonalDictionaryStoring {
    func load() throws -> PersonalDictionarySnapshot
    func save(terms: [DictionaryTerm], reviewQueue: [DictionaryReviewCandidate]) throws
    func importSnapshot(from sourceURL: URL) throws -> PersonalDictionarySnapshot
    func exportSnapshot(_ snapshot: PersonalDictionarySnapshot, to destinationURL: URL) throws
}

struct PersonalDictionaryStore: PersonalDictionaryStoring {
    let fileURL: URL
    private let fileManager: FileManager

    init(fileURL: URL, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager
    }

    func load() throws -> PersonalDictionarySnapshot {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return PersonalDictionarySnapshot(terms: [], reviewQueue: [])
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let snapshot = try JSONDecoder().decode(PersonalDictionarySnapshot.self, from: data)
            return deduped(snapshot: snapshot)
        } catch {
            quarantineCorruptedDictionary(reason: "corrupt")
            return PersonalDictionarySnapshot(terms: [], reviewQueue: [])
        }
    }

    func save(terms: [DictionaryTerm], reviewQueue: [DictionaryReviewCandidate]) throws {
        let snapshot = deduped(
            snapshot: PersonalDictionarySnapshot(terms: terms, reviewQueue: reviewQueue)
        )
        let data = try JSONEncoder().encode(snapshot)
        try SecurePersistence.writeData(data, to: fileURL, fileManager: fileManager)
    }

    func importSnapshot(from sourceURL: URL) throws -> PersonalDictionarySnapshot {
        let data = try Data(contentsOf: sourceURL)
        let decoded = try JSONDecoder().decode(PersonalDictionarySnapshot.self, from: data)
        let snapshot = deduped(snapshot: decoded)
        try save(terms: snapshot.terms, reviewQueue: snapshot.reviewQueue)
        return snapshot
    }

    func exportSnapshot(_ snapshot: PersonalDictionarySnapshot, to destinationURL: URL) throws {
        let normalized = deduped(snapshot: snapshot)
        let data = try JSONEncoder().encode(normalized)
        try SecurePersistence.ensureParentDirectory(for: destinationURL, fileManager: fileManager)
        try data.write(to: destinationURL, options: [.atomic])
    }

    private func deduped(snapshot: PersonalDictionarySnapshot) -> PersonalDictionarySnapshot {
        var seenTerms = Set<String>()
        var terms: [DictionaryTerm] = []
        terms.reserveCapacity(snapshot.terms.count)

        for term in snapshot.terms {
            let key = normalizedKey(term.term, languageCode: term.languageCode)
            guard !key.isEmpty, !seenTerms.contains(key) else { continue }
            seenTerms.insert(key)
            terms.append(term)
        }

        var seenCandidates = Set<String>()
        var reviewQueue: [DictionaryReviewCandidate] = []
        reviewQueue.reserveCapacity(snapshot.reviewQueue.count)

        for candidate in snapshot.reviewQueue {
            let key = normalizedKey(candidate.proposedTerm, languageCode: candidate.languageCode)
            guard !key.isEmpty else { continue }
            guard !seenTerms.contains(key), !seenCandidates.contains(key) else { continue }
            seenCandidates.insert(key)
            reviewQueue.append(candidate)
        }

        return PersonalDictionarySnapshot(terms: terms, reviewQueue: reviewQueue)
    }

    private func normalizedKey(_ value: String, languageCode: String?) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let folded = trimmed.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: .current
        )
        let normalizedLanguage = languageCode?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? "*"
        return "\(normalizedLanguage)|\(folded)"
    }

    private func quarantineCorruptedDictionary(reason: String) {
        guard fileManager.fileExists(atPath: fileURL.path) else { return }

        let parent = fileURL.deletingLastPathComponent()
        let timestamp = Int(Date().timeIntervalSince1970)
        let quarantineURL = parent.appendingPathComponent(
            "\(fileURL.lastPathComponent).corrupt-\(reason)-\(timestamp)-\(UUID().uuidString)"
        )

        do {
            try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
            if fileManager.fileExists(atPath: quarantineURL.path) {
                try fileManager.removeItem(at: quarantineURL)
            }
            try fileManager.moveItem(at: fileURL, to: quarantineURL)
            try SecurePersistence.hardenFileIfPresent(at: quarantineURL, fileManager: fileManager)
        } catch {
            // Best effort only.
        }
    }
}
