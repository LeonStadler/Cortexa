#if canImport(XCTest)
import AVFoundation
import AIProcessingCore
import Foundation
import XCTest
@testable import AppShellSupport

@MainActor
final class AppShellCharacterizationTests: XCTestCase {
    func testPermissionStatusMappingMatchesSystemStates() {
        XCTAssertEqual(PermissionStatus.microphone(from: .authorized), .granted)
        XCTAssertEqual(PermissionStatus.microphone(from: .denied), .denied)
        XCTAssertEqual(PermissionStatus.microphone(from: .notDetermined), .notDetermined)
        XCTAssertEqual(PermissionStatus.microphone(from: .restricted), .restricted)
        XCTAssertEqual(PermissionStatus.accessibility(isTrusted: true), .granted)
        XCTAssertEqual(PermissionStatus.accessibility(isTrusted: false), .denied)
    }

    func testPermissionRefreshReflectsAccessibilityDenial() async throws {
        let permissions = StubPermissionController(
            microphone: .granted,
            accessibility: .granted
        )
        let state = makeState(permissionController: permissions)

        XCTAssertEqual(state.accessibilityPermissionStatus, .granted)

        permissions.accessibilityStatusValue = .denied
        state.refreshPermissionStates()

        XCTAssertEqual(state.accessibilityPermissionStatus, .denied)
    }

    func testRequestAccessibilityAccessUsesOnlyTheNativePromptWhenDenied() async throws {
        let permissions = StubPermissionController(
            microphone: .granted,
            accessibility: .denied
        )
        let runtime = StubDictationRuntime()
        let state = makeState(permissionController: permissions, runtime: runtime)

        state.requestAccessibilityAccessFromSettings()

        let prompted = await eventually {
            runtime.promptAccessibilityTrustCallCount == 1
                && runtime.openAccessibilitySettingsCallCount == 0
        }
        XCTAssertTrue(prompted)
    }

    func testToggleTranscriptionUsesFinalizeModeWhenClipboardOnlyIsSelected() {
        let permissions = StubPermissionController(
            microphone: .granted,
            accessibility: .denied
        )
        let runtime = StubDictationRuntime()
        let state = makeState(permissionController: permissions, runtime: runtime)

        state.finalResultDeliveryMode = .clipboardOnly
        state.streamingEnabled = true
        state.toggleTranscriptionFromUI()

        XCTAssertEqual(runtime.toggleCalls.count, 1)
        XCTAssertEqual(runtime.toggleCalls.first?.mode, .finalize)
        XCTAssertEqual(runtime.toggleCalls.first?.finalResultDeliveryMode, .clipboardOnly)
    }

    func testToggleTranscriptionUsesStreamingModeWhenEnabled() {
        let permissions = StubPermissionController(
            microphone: .granted,
            accessibility: .denied
        )
        let runtime = StubDictationRuntime()
        let state = makeState(permissionController: permissions, runtime: runtime)

        state.finalResultDeliveryMode = .insert
        state.streamingEnabled = true
        state.toggleTranscriptionFromUI()

        XCTAssertEqual(runtime.toggleCalls.count, 1)
        XCTAssertEqual(runtime.toggleCalls.first?.mode, .streaming)
    }

    func testHoldToDictateUsesToggleAndReleasesTheSession() async {
        let permissions = StubPermissionController(
            microphone: .granted,
            accessibility: .denied
        )
        let runtime = StubDictationRuntime()
        let state = makeState(permissionController: permissions, runtime: runtime)

        state.holdToDictateEnabled = true
        state.handleHoldShortcutPressed()

        XCTAssertEqual(runtime.toggleCalls.count, 1)
        XCTAssertEqual(runtime.toggleCalls.first?.mode, .streaming)

        runtime.emitSessionActivityChanged(true)
        let becameActive = await eventually {
            state.isSessionActive
        }
        XCTAssertTrue(becameActive)
        state.handleHoldShortcutReleased()

        let released = await eventually {
            runtime.toggleCalls.count == 2
        }
        XCTAssertTrue(released)
        XCTAssertEqual(runtime.toggleCalls.count, 2)
    }

    func testHistoryLoadsAndPrunesAccordingToRetentionPolicy() {
        let oldEntry = TranscriptHistoryEntry(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            createdAt: Date().addingTimeInterval(-10 * 24 * 60 * 60),
            text: "old",
            languageCode: "de",
            mode: "finalize"
        )
        let freshEntry = TranscriptHistoryEntry(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            createdAt: Date(),
            text: "fresh",
            languageCode: "de",
            mode: "finalize"
        )
        let historyStore = MemoryHistoryStore(loadResult: [oldEntry, freshEntry])
        let state = makeState(historyStore: historyStore)

        XCTAssertEqual(state.transcriptHistory, [oldEntry, freshEntry])

        state.historyRetentionPolicy = .sevenDays

        XCTAssertEqual(state.transcriptHistory, [freshEntry])
        XCTAssertEqual(historyStore.savedSnapshots.last, [freshEntry])
    }

    func testFinalTranscriptEventIsPersistedIntoHistory() async {
        let historyStore = MemoryHistoryStore(loadResult: [])
        let runtime = StubDictationRuntime()
        let state = makeState(runtime: runtime, historyStore: historyStore)

        runtime.emitFinalTranscript(
            FinalTranscriptEvent(
                text: "  Hallo Welt  ",
                languageCode: "de",
                mode: .streaming,
                deliveryOutcome: .inserted
            )
        )

        let persisted = await eventually {
            state.transcriptHistory.first?.text == "Hallo Welt"
        }
        XCTAssertTrue(persisted)
        XCTAssertEqual(state.transcriptHistory.first?.text, "Hallo Welt")
        XCTAssertEqual(state.transcriptHistory.first?.mode, "streaming")
        XCTAssertEqual(historyStore.savedSnapshots.last?.first?.text, "Hallo Welt")
    }

    func testMacAppStateConnectsRuntimeThroughInjectedBridge() {
        let permissions = StubPermissionController(
            microphone: .granted,
            accessibility: .granted
        )
        let historyStore = MemoryHistoryStore(loadResult: [])
        let runtime = StubDictationRuntime()
        let bridge = SpyDictationRuntimeEventBridge()
        let state = makeState(
            permissionController: permissions,
            runtime: runtime,
            historyStore: historyStore,
            runtimeEventBridge: bridge
        )

        XCTAssertTrue(bridge.connectedRuntime === runtime)

        bridge.handlers?.handleStatus("Recording")
        XCTAssertEqual(state.recordingStatus, "Recording")

        bridge.handlers?.handleTranscript("Zwischenstand")
        XCTAssertEqual(state.lastTranscript, "Zwischenstand")

        bridge.handlers?.handleFinalTranscript(
            FinalTranscriptEvent(
                text: "Bridge Ergebnis",
                languageCode: "de",
                mode: .finalize,
                deliveryOutcome: .inserted
            )
        )
        XCTAssertEqual(state.transcriptHistory.first?.text, "Bridge Ergebnis")

        permissions.microphoneStatusValue = .denied
        bridge.handlers?.handlePermissionInteractionFinished()
        XCTAssertEqual(state.microphonePermissionStatus, .denied)
    }

    func testHistorySettingsWindowHelpersRouteTabs() {
        let state = makeState()
        var openCount = 0
        state.bindOpenSettingsHandler { openCount += 1 }

        state.openHistorySettingsWindow()
        XCTAssertEqual(state.selectedSettingsTab, .history)

        state.openAISettingsWindow()
        XCTAssertEqual(state.selectedSettingsTab, .ai)
        XCTAssertEqual(openCount, 2)
    }

    func testRemoteProviderSelectionLoadsKeyDraftAndSupportsInPlaceEditing() {
        let provider = AIRemoteProviderConfiguration.template(for: .openAI)
        let secretStore = StubSecretStore()
        secretStore.keys[provider.id] = "stored-key"
        let state = makeState(secretStore: secretStore)

        state.remoteProviders = [provider]
        state.selectedRemoteProviderID = provider.id

        XCTAssertEqual(state.remoteProviderAPIKeyDraft, "stored-key")

        state.updateSelectedRemoteProvider { $0.displayName = "Renamed API" }
        XCTAssertEqual(state.remoteProviders.first?.displayName, "Renamed API")
    }

    func testSavingSelectedRemoteProviderAPIKeyPersistsAndBlankInputClearsIt() {
        let provider = AIRemoteProviderConfiguration.template(for: .openAI)
        let secretStore = StubSecretStore()
        let state = makeState(secretStore: secretStore)

        state.remoteProviders = [provider]
        state.selectedRemoteProviderID = provider.id
        state.remoteProviderAPIKeyDraft = "  fresh-key  "
        state.saveSelectedRemoteProviderAPIKey()

        XCTAssertEqual(secretStore.saveCalls.last?.providerID, provider.id)
        XCTAssertEqual(secretStore.keys[provider.id], "fresh-key")

        state.remoteProviderAPIKeyDraft = ""
        state.saveSelectedRemoteProviderAPIKey()

        XCTAssertEqual(secretStore.removeCalls.last, provider.id)
        XCTAssertNil(secretStore.keys[provider.id])
    }

    func testRemovingSelectedRemoteProviderClearsSelectionAndKey() {
        let provider = AIRemoteProviderConfiguration.template(for: .openAI)
        let secretStore = StubSecretStore()
        secretStore.keys[provider.id] = "stored-key"
        let state = makeState(secretStore: secretStore)

        state.remoteProviders = [provider]
        state.selectedRemoteProviderID = provider.id
        state.removeSelectedRemoteProvider()

        XCTAssertEqual(secretStore.removeCalls, [provider.id])
        XCTAssertTrue(state.remoteProviders.isEmpty)
        XCTAssertNil(state.selectedRemoteProviderID)
    }

    func testApproveDictionaryCandidatePromotesItIntoTheDictionary() {
        let state = makeState()

        state.queueDictionaryCandidate(
            "Leon Stadler",
            category: .personName,
            languageCode: "de"
        )

        guard let candidate = state.dictionaryReviewQueue.first else {
            XCTFail("Expected queued dictionary candidate")
            return
        }

        state.approveDictionaryCandidate(candidate.id)

        XCTAssertEqual(state.dictionaryTerms.count, 1)
        XCTAssertEqual(state.dictionaryTerms.first?.term, "Leon Stadler")
        XCTAssertEqual(state.dictionaryTerms.first?.category, .personName)
        XCTAssertEqual(state.dictionaryTerms.first?.source, .auto)
        XCTAssertEqual(state.dictionaryTerms.first?.languageCode, "de")
        XCTAssertTrue(state.dictionaryReviewQueue.isEmpty)
    }

    func testUpdateDictionaryTermEditsTextCategoryAndLanguageWithoutChangingSource() {
        let state = makeState()

        state.addDictionaryTerm(
            "Cortexa",
            category: .companyJargon,
            source: .auto,
            languageCode: "de"
        )

        guard let term = state.dictionaryTerms.first else {
            XCTFail("Expected dictionary term")
            return
        }

        state.updateDictionaryTerm(
            termID: term.id,
            term: "Cortexa App",
            category: .custom,
            languageCode: "en"
        )

        XCTAssertEqual(state.dictionaryTerms.count, 1)
        XCTAssertEqual(state.dictionaryTerms.first?.id, term.id)
        XCTAssertEqual(state.dictionaryTerms.first?.term, "Cortexa App")
        XCTAssertEqual(state.dictionaryTerms.first?.category, .custom)
        XCTAssertEqual(state.dictionaryTerms.first?.source, .auto)
        XCTAssertEqual(state.dictionaryTerms.first?.languageCode, "en")
    }

    func testRejectDictionaryCandidateRemovesOnlyTheMatchingQueueEntry() {
        let state = makeState()

        state.queueDictionaryCandidate("Leon Stadler", category: .personName, languageCode: "de")
        state.queueDictionaryCandidate("WisprLocal", category: .companyJargon)

        guard let rejectedCandidate = state.dictionaryReviewQueue.first(where: {
            $0.proposedTerm == "WisprLocal"
        }) else {
            XCTFail("Expected queued dictionary candidate")
            return
        }

        state.rejectDictionaryCandidate(rejectedCandidate.id)

        XCTAssertEqual(state.dictionaryReviewQueue.count, 1)
        XCTAssertEqual(state.dictionaryReviewQueue.first?.proposedTerm, "Leon Stadler")
        XCTAssertTrue(state.dictionaryTerms.isEmpty)
    }

    func testAddRemoteProviderReusesExistingPreset() {
        let existing = AIRemoteProviderConfiguration.template(for: .ollama)
        let state = makeState()
        state.remoteProviders = [existing]

        state.addRemoteProvider(preset: .ollama)

        XCTAssertEqual(state.remoteProviders.count, 1)
        XCTAssertEqual(state.selectedRemoteProviderID, existing.id)
    }

    func testMacAppStateWiresHotkeyCallbacksToFacadeActions() async {
        let permissions = StubPermissionController(
            microphone: .granted,
            accessibility: .granted
        )
        let runtime = StubDictationRuntime()
        let hotkeyManager = StubGlobalHotkeyManager()
        let state = makeState(
            permissionController: permissions,
            runtime: runtime,
            hotkeyManager: hotkeyManager
        )

        XCTAssertNotNil(hotkeyManager.onToggle)
        XCTAssertNotNil(hotkeyManager.onHoldPress)
        XCTAssertNotNil(hotkeyManager.onHoldRelease)
        XCTAssertNotNil(hotkeyManager.onCancel)
        XCTAssertNotNil(hotkeyManager.onModeSwitch)

        let togglesBeforeToggleShortcut = runtime.toggleCalls.count
        hotkeyManager.onToggle?()
        XCTAssertEqual(runtime.toggleCalls.count, togglesBeforeToggleShortcut + 1)

        state.holdToDictateEnabled = true
        let togglesBeforeHoldPress = runtime.toggleCalls.count
        hotkeyManager.onHoldPress?()
        XCTAssertEqual(runtime.toggleCalls.count, togglesBeforeHoldPress + 1)
        runtime.emitSessionActivityChanged(true)
        let becameActive = await eventually {
            state.isSessionActive
        }
        XCTAssertTrue(becameActive)
        let togglesBeforeHoldRelease = runtime.toggleCalls.count
        hotkeyManager.onHoldRelease?()
        let released = await eventually {
            runtime.toggleCalls.count == togglesBeforeHoldRelease + 1
        }
        XCTAssertTrue(released)
        XCTAssertEqual(runtime.toggleCalls.count, togglesBeforeHoldRelease + 1)

        let cancelsBefore = runtime.cancelCallCount
        hotkeyManager.onCancel?()
        XCTAssertEqual(runtime.cancelCallCount, cancelsBefore + 1)

        let previousStreaming = state.streamingEnabled
        hotkeyManager.onModeSwitch?()
        XCTAssertEqual(state.streamingEnabled, !previousStreaming)
    }

    private func makeState(
        permissionController: StubPermissionController = StubPermissionController(),
        runtime: StubDictationRuntime = StubDictationRuntime(),
        hotkeyManager: GlobalHotkeyRegistering = StubGlobalHotkeyManager(),
        historyStore: MemoryHistoryStore = MemoryHistoryStore(loadResult: []),
        secretStore: StubSecretStore = StubSecretStore(),
        runtimeEventBridge: DictationRuntimeEventBridging = DictationRuntimeEventBridge()
    ) -> MacAppState {
        let defaultsName = "AppShellSupportTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: defaultsName)!
        userDefaults.removePersistentDomain(forName: defaultsName)
        let fileManager = FileManager.default
        let storageRootDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("AppShellSupportTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? fileManager.createDirectory(
            at: storageRootDirectory,
            withIntermediateDirectories: true
        )
        addTeardownBlock {
            try? fileManager.removeItem(at: storageRootDirectory)
        }

        return MacAppState(
            userDefaults: userDefaults,
            permissionController: permissionController,
            dictationRuntime: runtime,
            runtimeEventBridge: runtimeEventBridge,
            hotkeyManager: hotkeyManager,
            historyStore: historyStore,
            aiRemoteProviderSecretStore: secretStore,
            storageRootDirectory: storageRootDirectory,
            skipStartupSystemHooks: true
        )
    }

    private func eventually(
        timeoutNanoseconds: UInt64 = 1_000_000_000,
        pollNanoseconds: UInt64 = 25_000_000,
        condition: () -> Bool
    ) async -> Bool {
        let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
        while DispatchTime.now().uptimeNanoseconds < deadline {
            if condition() {
                return true
            }
            try? await Task.sleep(nanoseconds: pollNanoseconds)
        }
        return condition()
    }
}

private final class StubPermissionController: PermissionControlling {
    var microphoneStatusValue: PermissionStatus
    var accessibilityStatusValue: PermissionStatus

    init(
        microphone: PermissionStatus = .granted,
        accessibility: PermissionStatus = .granted
    ) {
        self.microphoneStatusValue = microphone
        self.accessibilityStatusValue = accessibility
    }

    func microphoneStatus() -> PermissionStatus {
        microphoneStatusValue
    }

    func accessibilityStatus() -> PermissionStatus {
        accessibilityStatusValue
    }
}

private final class StubDictationRuntime: DictationRuntimeControlling {
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

    func prepareRuntime() {
        prepareRuntimeCallCount += 1
    }

    func prepareRuntimeIfModelAvailable() {
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

    func setAIProcessingService(_ service: AIProcessingService) {}

    func emitSessionActivityChanged(_ isActive: Bool) {
        onSessionActivityChanged?(isActive)
    }

    func emitFinalTranscript(_ event: FinalTranscriptEvent) {
        onFinalTranscript?(event)
    }
}

private final class StubSecretStore: AIRemoteProviderSecretStoring {
    var keys: [String: String] = [:]
    private(set) var saveCalls: [(providerID: String, key: String)] = []
    private(set) var removeCalls: [String] = []

    func saveAPIKey(_ key: String, providerID: String) throws {
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

private final class MemoryHistoryStore: TranscriptHistoryStoring {
    var loadResult: [TranscriptHistoryEntry]
    private(set) var savedSnapshots: [[TranscriptHistoryEntry]] = []

    init(loadResult: [TranscriptHistoryEntry]) {
        self.loadResult = loadResult
    }

    func load() throws -> [TranscriptHistoryEntry] {
        loadResult
    }

    func save(_ entries: [TranscriptHistoryEntry]) throws {
        savedSnapshots.append(entries)
    }

    func exportText(entries: [TranscriptHistoryEntry], to destinationURL: URL) throws {
        let output = entries.reversed().map { $0.text }.joined(separator: "\n")
        try output.write(to: destinationURL, atomically: true, encoding: .utf8)
    }
}

private final class SpyDictationRuntimeEventBridge: DictationRuntimeEventBridging {
    private(set) weak var connectedRuntime: DictationRuntimeControlling?
    private(set) var handlers: DictationRuntimeEventHandlers?

    func connect(
        runtime: DictationRuntimeControlling,
        handlers: DictationRuntimeEventHandlers
    ) {
        connectedRuntime = runtime
        self.handlers = handlers
    }
}

private final class StubGlobalHotkeyManager: GlobalHotkeyRegistering {
    var onToggle: (() -> Void)?
    var onHoldPress: (() -> Void)?
    var onHoldRelease: (() -> Void)?
    var onCancel: (() -> Void)?
    var onModeSwitch: (() -> Void)?

    @discardableResult
    func register(
        shortcut: HotkeyBinding,
        shortcutEnabled: Bool,
        holdShortcut: HotkeyBinding?,
        holdEnabled: Bool,
        cancelShortcut: HotkeyBinding?,
        cancelEnabled: Bool,
        modeShortcut: HotkeyBinding?,
        modeEnabled: Bool,
        force: Bool
    ) -> Bool {
        true
    }
}
#endif
