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
            sharedDefaults.set(selectedLanguageCode, forKey: SharedDefaultsKeys.languageCode)
        }
    }
    @Published var lastDiagnostics: String = "Ready"
    @Published var licenseInput: String = ""
    @Published var licenseStatusText: String = "No license"
    @Published var licenseValid: Bool = false

    private static let defaultLanguage = "de"

    private let storage = IOSSharedStorage()
    private let sharedDefaults: UserDefaults
    private let licenseStore = LicenseStore(service: "com.wisprlocal.ios.license", account: "primary")
    private let licenseCache: LicenseCache
    private let licenseVerifier: LicenseVerifier?

    init() {
        self.sharedDefaults = storage.sharedDefaults()
        self.selectedLanguageCode = sharedDefaults.string(forKey: SharedDefaultsKeys.languageCode) ?? Self.defaultLanguage
        try? storage.ensureSharedContainer()
        self.licenseCache = LicenseCache(fileURL: storage.sharedContainerURL().appendingPathComponent("ios-license-cache.json"))
        self.licenseVerifier = try? LicenseVerifier()

        reload()
        loadExistingLicense()
    }

    func reload() {
        snippetRules = storage.loadSnippets()
        transcriptHistory = storage.loadTranscriptHistory()
        writeDiagnostic("Shared data loaded")
    }

    func addSnippet(trigger: String, replacement: String) {
        let trimmedTrigger = trigger.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedReplacement = replacement.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTrigger.isEmpty, !trimmedReplacement.isEmpty else {
            writeDiagnostic("Snippet not saved: empty input")
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

        if snippetRules.contains(where: { $0.trigger == trimmedTrigger && $0.replacement == entry.text }) {
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
        case let .valid(payload):
            do {
                try licenseStore.saveLicenseKey(key)
                try licenseCache.write(licenseKey: key)
                licenseValid = true
                licenseStatusText = "Active: \(payload.productTier)"
                storage.appendAudit("license.activate tier=\(payload.productTier)")
            } catch {
                licenseValid = false
                licenseStatusText = "Could not store license"
            }

        case let .invalid(reason):
            licenseValid = false
            licenseStatusText = "Invalid: \(reason.localizedDescription)"
        }
    }

    func deactivateLicense() {
        licenseStore.removeLicenseKey()
        licenseValid = false
        licenseStatusText = "No license"
        storage.appendAudit("license.deactivate")
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
                licenseInput = key
                validateLoadedLicense(key)
                return
            }

            if let cachedKey = try licenseCache.read() {
                licenseInput = cachedKey
                validateLoadedLicense(cachedKey)
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
        case let .valid(payload):
            licenseStatusText = "Active: \(payload.productTier)"
            licenseValid = true
        case let .invalid(reason):
            licenseStatusText = "Invalid: \(reason.localizedDescription)"
            licenseValid = false
        }
    }

    private func writeDiagnostic(_ line: String) {
        lastDiagnostics = line
        storage.appendAudit("diag \(line)")
    }
}
