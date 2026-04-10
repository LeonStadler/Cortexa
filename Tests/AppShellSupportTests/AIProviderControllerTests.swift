#if canImport(XCTest)
import AIProcessingCore
import Foundation
import XCTest
@testable import AppShellSupport

@MainActor
final class AIProviderControllerTests: XCTestCase {
    func testSelectedRemoteProviderDidChangeLoadsStoredAPIKeyDraft() {
        let state = AIProviderControllerState()
        let secretStore = AppShellTestSecretStore()
        let provider = AIRemoteProviderConfiguration.template(for: .openAI)
        state.remoteProviders = [provider]
        state.selectedRemoteProviderID = provider.id
        secretStore.keys[provider.id] = "stored-key"

        let controller = makeController(state: state, secretStore: secretStore)

        controller.selectedRemoteProviderDidChange()

        XCTAssertEqual(state.remoteProviderAPIKeyDraft, "stored-key")
    }

    func testAddRemoteProviderSelectsNewProviderAndKeepsItDisabled() {
        let state = AIProviderControllerState()
        let controller = makeController(state: state)

        controller.addRemoteProvider(preset: .customOpenAICompatible)

        XCTAssertEqual(state.remoteProviders.count, 1)
        XCTAssertEqual(state.selectedRemoteProviderID, state.remoteProviders.first?.id)
        XCTAssertFalse(state.remoteProviders[0].isEnabled)
        XCTAssertEqual(state.remoteProviders[0].displayName, "Custom API")
    }

    func testSaveSelectedRemoteProviderAPIKeyTrimsAndClearsValues() {
        let state = AIProviderControllerState()
        let secretStore = AppShellTestSecretStore()
        let provider = AIRemoteProviderConfiguration.template(for: .openAI)
        state.remoteProviders = [provider]
        state.selectedRemoteProviderID = provider.id

        let controller = makeController(state: state, secretStore: secretStore)

        state.remoteProviderAPIKeyDraft = "  fresh-key  "
        controller.saveSelectedRemoteProviderAPIKey()
        XCTAssertEqual(secretStore.keys[provider.id], "fresh-key")
        XCTAssertEqual(secretStore.saveCalls.last?.providerID, provider.id)

        state.remoteProviderAPIKeyDraft = ""
        controller.saveSelectedRemoteProviderAPIKey()
        XCTAssertNil(secretStore.keys[provider.id])
        XCTAssertEqual(secretStore.removeCalls.last, provider.id)
    }

    func testRemoveSelectedRemoteProviderClearsSelectionAndKey() {
        let state = AIProviderControllerState()
        let secretStore = AppShellTestSecretStore()
        let first = AIRemoteProviderConfiguration.template(for: .openAI)
        let second = AIRemoteProviderConfiguration.template(for: .ollama)
        state.remoteProviders = [first, second]
        state.selectedRemoteProviderID = first.id
        secretStore.keys[first.id] = "stored-key"

        let controller = makeController(state: state, secretStore: secretStore)

        controller.removeSelectedRemoteProvider()

        XCTAssertEqual(state.remoteProviders.map(\.id), [second.id])
        XCTAssertEqual(state.selectedRemoteProviderID, second.id)
        XCTAssertEqual(secretStore.removeCalls, [first.id])
    }

    private func makeController(
        state: AIProviderControllerState,
        secretStore: AppShellTestSecretStore = AppShellTestSecretStore(),
        runtime: AppShellTestDictationRuntime = AppShellTestDictationRuntime()
    ) -> AIProviderController {
        AIProviderController(
            aiRemoteProviderSecretStore: secretStore,
            dictationRuntime: runtime,
            currentRemoteProviders: { state.remoteProviders },
            setRemoteProviders: { state.remoteProviders = $0 },
            currentSelectedRemoteProviderID: { state.selectedRemoteProviderID },
            setSelectedRemoteProviderID: { state.selectedRemoteProviderID = $0 },
            currentRemoteProviderAPIKeyDraft: { state.remoteProviderAPIKeyDraft },
            setRemoteProviderAPIKeyDraft: { state.remoteProviderAPIKeyDraft = $0 },
            currentSelectedAIModelID: { state.selectedAIModelID },
            setSelectedAIModelID: { state.selectedAIModelID = $0 },
            currentAIProcessingEnabled: { state.aiProcessingEnabled },
            setAIProcessingEnabled: { state.aiProcessingEnabled = $0 },
            setAIModels: { state.aiModels = $0 },
            persistRemoteProviders: { state.persistCallCount += 1 },
            appendDiagnostic: { state.diagnostics.append($0) },
            appendAudit: { state.auditLines.append($0) }
        )
    }
}

private final class AIProviderControllerState {
    var remoteProviders: [AIRemoteProviderConfiguration] = []
    var selectedRemoteProviderID: String?
    var remoteProviderAPIKeyDraft = ""
    var selectedAIModelID: String?
    var aiProcessingEnabled = false
    var aiModels: [AIModelDescriptor] = []
    var persistCallCount = 0
    var diagnostics: [String] = []
    var auditLines: [String] = []
}
#endif
