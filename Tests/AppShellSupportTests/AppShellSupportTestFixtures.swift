#if canImport(XCTest)
import AIProcessingCore
import ASRCore
import AppKit
import AudioCore
import Foundation
import SnippetCore
import XCTest
@testable import AppShellSupport

final class AppShellTestPermissionController: PermissionControlling {
    var microphoneStatusValue: PermissionStatus = .granted
    var accessibilityStatusValue: PermissionStatus = .granted

    func microphoneStatus() -> PermissionStatus {
        microphoneStatusValue
    }

    func accessibilityStatus() -> PermissionStatus {
        accessibilityStatusValue
    }
}

final class AppShellTestDictationRuntime: DictationRuntimeControlling {
    var onStatus: ((String) -> Void)?
    var onDiagnostic: ((String) -> Void)?
    var onDebugEvent: ((String) -> Void)?
    var onTranscript: ((String) -> Void)?
    var onFinalTranscript: ((FinalTranscriptEvent) -> Void)?
    var onSessionActivityChanged: ((Bool) -> Void)?
    var onPermissionInteractionFinished: (() -> Void)?

    private(set) var prepareRuntimeCallCount = 0
    private(set) var setVoiceModelActiveDurationCalls: [VoiceModelActiveDuration] = []
    private(set) var startCalls: [DictationStartOptions] = []
    private(set) var toggleCalls: [DictationStartOptions] = []
    private(set) var cancelCallCount = 0
    private(set) var openMicrophoneSettingsCallCount = 0
    private(set) var openAccessibilitySettingsCallCount = 0
    private(set) var promptAccessibilityTrustCallCount = 0
    private(set) var aiProcessingServiceCount = 0

    func prepareRuntime() {
        prepareRuntimeCallCount += 1
    }

    func setVoiceModelActiveDuration(_ duration: VoiceModelActiveDuration) {
        setVoiceModelActiveDurationCalls.append(duration)
    }

    func toggle(options: DictationStartOptions) {
        toggleCalls.append(options)
    }

    func cancel() {
        cancelCallCount += 1
    }

    func start(options: DictationStartOptions) {
        startCalls.append(options)
    }

    func openMicrophoneSettings() {
        openMicrophoneSettingsCallCount += 1
    }

    func openAccessibilitySettings() {
        openAccessibilitySettingsCallCount += 1
    }

    func promptAccessibilityTrustFromUser() {
        promptAccessibilityTrustCallCount += 1
    }

    func setAIProcessingService(_ service: AIProcessingService) {
        aiProcessingServiceCount += 1
    }

    func emitSessionActivityChanged(_ isActive: Bool) {
        onSessionActivityChanged?(isActive)
    }

    func emitFinalTranscript(_ event: FinalTranscriptEvent) {
        onFinalTranscript?(event)
    }
}

enum AppShellTestHistoryStoreError: Error {
    case loadFailed
    case saveFailed
}

final class AppShellTestHistoryStore: TranscriptHistoryStoring {
    var loadResult: [TranscriptHistoryEntry]
    var loadError: Error?
    var saveError: Error?
    private(set) var savedSnapshots: [[TranscriptHistoryEntry]] = []
    private(set) var exportedSnapshots: [(entries: [TranscriptHistoryEntry], destinationURL: URL)] = []

    init(loadResult: [TranscriptHistoryEntry]) {
        self.loadResult = loadResult
    }

    func load() throws -> [TranscriptHistoryEntry] {
        if let loadError {
            throw loadError
        }
        return loadResult
    }

    func save(_ entries: [TranscriptHistoryEntry]) throws {
        if let saveError {
            throw saveError
        }
        savedSnapshots.append(entries)
    }

    func exportText(entries: [TranscriptHistoryEntry], to destinationURL: URL) throws {
        exportedSnapshots.append((entries: entries, destinationURL: destinationURL))
        let output = entries
            .reversed()
            .map { "[\($0.mode)] [\($0.languageCode)] \($0.text)" }
            .joined(separator: "\n")
        try output.write(to: destinationURL, atomically: true, encoding: .utf8)
    }
}

final class AppShellTestSecretStore: AIRemoteProviderSecretStoring {
    var keys: [String: String] = [:]
    var saveError: Error?
    private(set) var saveCalls: [(providerID: String, key: String)] = []
    private(set) var removeCalls: [String] = []

    func saveAPIKey(_ key: String, providerID: String) throws {
        if let saveError {
            throw saveError
        }
        keys[providerID] = key
        saveCalls.append((providerID: providerID, key: key))
    }

    func loadAPIKey(providerID: String) -> String? {
        keys[providerID]
    }

    func removeAPIKey(providerID: String) {
        keys.removeValue(forKey: providerID)
        removeCalls.append(providerID)
    }
}

final class AppShellTestAuditLogger: AuditLogging {
    let fileURL: URL
    private(set) var appendedLines: [String] = []
    private(set) var exportCalls: [URL] = []
    var exportError: Error?

    init(fileURL: URL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)) {
        self.fileURL = fileURL
    }

    func append(_ line: String) {
        appendedLines.append(line)
    }

    func export(to destinationURL: URL) throws {
        if let exportError {
            throw exportError
        }
        exportCalls.append(destinationURL)
    }
}
#endif
