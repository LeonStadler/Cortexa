import Foundation
import LicenseCore
import SnippetCore
import SwiftUI

@MainActor
final class IOSAppState: ObservableObject {
    @Published var snippetRules: [SnippetRule] = []
    @Published var transcriptHistory: [IOSTranscriptHistoryEntry] = []
    @Published var selectedLanguageCode: String {
        didSet {
            sharedDefaults?.set(selectedLanguageCode, forKey: SharedDefaultsKeys.languageCode)
        }
    }
    @Published var lastDiagnostics: String = "Ready"
    @Published var licenseInput: String = ""
    @Published var storedLicenseSummary: String?
    @Published var licenseStatusText: String = "No license"
    @Published var licenseValid: Bool = false

    private static let defaultLanguage = "de"

    private let storage = IOSSharedStorage()
    private let sharedDefaults: UserDefaults?
    private let licenseStore = LicenseStore(
        service: "com.wisprlocal.ios.license", account: "primary")
    private let licenseVerifier: LicenseVerifier?

    init() {
        self.sharedDefaults = try? storage.sharedDefaults()
        self.selectedLanguageCode =
            self.sharedDefaults?.string(forKey: SharedDefaultsKeys.languageCode)
            ?? Self.defaultLanguage
        self.licenseVerifier = try? LicenseVerifier()

        do {
            try storage.ensureSharedContainer()
            try storage.clearLicenseCache()
        } catch {
            self.lastDiagnostics = "Shared App Group unavailable: \(error.localizedDescription)"
        }

        reload()
        loadExistingLicense()
    }

    func reload() {
        var loadedAnyData = false

        do {
            let loadedSnippets = try storage.loadSnippets()
            snippetRules = loadedSnippets
            loadedAnyData = true
        } catch {
            writeDiagnostic("Snippet storage unavailable: \(error.localizedDescription)")
        }

        do {
            let loadedHistory = try storage.loadTranscriptHistory()
            transcriptHistory = loadedHistory
            loadedAnyData = true
        } catch {
            writeDiagnostic("Transcript storage unavailable: \(error.localizedDescription)")
        }

        if loadedAnyData {
            writeDiagnostic("Shared data loaded")
        }
    }

    func addSnippet(trigger: String, replacement: String) {
        let trimmedTrigger = trigger.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedReplacement = replacement.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTrigger.isEmpty, !trimmedReplacement.isEmpty else {
            writeDiagnostic("Snippet not saved: empty input")
            return
        }

        if snippetRules.contains(where: { rule in
            rule.caseSensitive
                ? rule.trigger == trimmedTrigger
                : rule.trigger.lowercased() == trimmedTrigger.lowercased()
        }) {
            writeDiagnostic("Snippet not saved: trigger already exists")
            return
        }

        snippetRules.append(
            SnippetRule(
                trigger: trimmedTrigger,
                replacement: trimmedReplacement,
                caseSensitive: false,
                localeIdentifier: selectedLanguageCode
            )
        )

        persistSnippets()
    }

    func removeSnippet(id: UUID) {
        snippetRules.removeAll { $0.id == id }
        persistSnippets()
    }

    func promoteTranscriptToSnippet(_ entry: IOSTranscriptHistoryEntry) {
        let trimmedTrigger = entry.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTrigger.isEmpty else {
            writeDiagnostic("Transcript snippet skipped: empty text")
            return
        }

        if snippetRules.contains(where: {
            $0.trigger == trimmedTrigger && $0.replacement == entry.text
        }) {
            writeDiagnostic("Transcript already exists as snippet")
            return
        }

        snippetRules.insert(
            SnippetRule(
                trigger: trimmedTrigger,
                replacement: entry.text,
                caseSensitive: false,
                localeIdentifier: entry.languageCode
            ),
            at: 0
        )
        persistSnippets()
    }

    func addTranscript(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        transcriptHistory.insert(
            IOSTranscriptHistoryEntry(text: trimmed, languageCode: selectedLanguageCode),
            at: 0
        )
        if transcriptHistory.count > 200 {
            transcriptHistory = Array(transcriptHistory.prefix(200))
        }

        persistTranscriptHistory()
    }

    func removeTranscript(id: UUID) {
        transcriptHistory.removeAll { $0.id == id }
        persistTranscriptHistory()
    }

    func clearTranscriptHistory() {
        transcriptHistory.removeAll()
        persistTranscriptHistory()
    }

    func activateLicense() {
        if EmbeddedLicenseKeys.isPlaceholderConfigured {
            licenseStatusText = "Development build: configure real public key first."
            licenseValid = false
            return
        }

        let key = licenseInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            licenseStatusText = "License key is empty"
            licenseValid = false
            return
        }

        guard let licenseVerifier else {
            licenseStatusText = "License verifier unavailable"
            licenseValid = false
            return
        }

        switch licenseVerifier.verify(key) {
        case .valid(let payload):
            do {
                try licenseStore.saveLicenseKey(key)
                try storage.clearLicenseCache()
                licenseValid = true
                licenseStatusText = "Active: \(payload.productTier)"
                storedLicenseSummary = Self.maskedLicense(key)
                licenseInput = ""
                try? storage.appendAudit("license.activate tier=\(payload.productTier)")
            } catch {
                licenseValid = false
                licenseStatusText = "Could not store license"
            }

        case .invalid(let reason):
            licenseValid = false
            licenseStatusText = "Invalid: \(reason.localizedDescription)"
        }
    }

    func deactivateLicense() {
        licenseStore.removeLicenseKey()
        licenseValid = false
        licenseStatusText = "No license"
        storedLicenseSummary = nil
        licenseInput = ""
        try? storage.clearLicenseCache()
        try? storage.appendAudit("license.deactivate")
    }

    private func persistSnippets() {
        do {
            try storage.saveSnippets(snippetRules)
            writeDiagnostic("Snippets saved: \(snippetRules.count)")
        } catch {
            writeDiagnostic("Snippet save failed: \(error.localizedDescription)")
        }
    }

    private func persistTranscriptHistory() {
        do {
            try storage.saveTranscriptHistory(transcriptHistory)
            try syncKeyboardInsertionState()
            writeDiagnostic("Transcript history saved: \(transcriptHistory.count)")
        } catch {
            writeDiagnostic("Transcript history save failed: \(error.localizedDescription)")
        }
    }

    private func loadExistingLicense() {
        if EmbeddedLicenseKeys.isPlaceholderConfigured {
            licenseStatusText = "Development build: placeholder public key configured."
            licenseValid = false
            return
        }

        do {
            if let key = try licenseStore.loadLicenseKey() {
                try? storage.clearLicenseCache()
                validateLoadedLicense(key)
                return
            }
        } catch {
            licenseStatusText = "License load failed"
            licenseValid = false
        }
    }

    private func validateLoadedLicense(_ key: String) {
        guard let licenseVerifier else {
            licenseStatusText = "License verifier unavailable"
            licenseValid = false
            return
        }

        switch licenseVerifier.verify(key) {
        case .valid(let payload):
            licenseStatusText = "Active: \(payload.productTier)"
            licenseValid = true
            storedLicenseSummary = Self.maskedLicense(key)
        case .invalid(let reason):
            licenseStatusText = "Invalid: \(reason.localizedDescription)"
            licenseValid = false
            storedLicenseSummary = Self.maskedLicense(key)
        }
    }

    private func writeDiagnostic(_ line: String) {
        lastDiagnostics = line
        try? storage.appendAudit("diag \(line)")
    }

    private func syncKeyboardInsertionState() throws {
        if let latest = transcriptHistory.first {
            try storage.saveKeyboardInsertionState(
                IOSKeyboardInsertionState(
                    text: latest.text,
                    languageCode: latest.languageCode,
                    updatedAt: latest.createdAt
                )
            )
        } else {
            try storage.clearKeyboardInsertionState()
        }
    }

    private static func maskedLicense(_ key: String) -> String {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 8 else {
            return String(repeating: "•", count: max(trimmed.count, 4))
        }

        return "\(trimmed.prefix(4))••••\(trimmed.suffix(4))"
    }
}
