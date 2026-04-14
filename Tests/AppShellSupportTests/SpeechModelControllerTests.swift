#if canImport(XCTest)
import ASRCore
import Foundation
import XCTest
@testable import AppShellSupport

@MainActor
final class SpeechModelControllerTests: XCTestCase {
    func testSanitizeSpeechModelSelectionsFallsBackToValidDefaultsAndResetsTranslation() {
        let state = SpeechModelControllerState(
            selectedLanguage: .german,
            translationOutputMode: .english,
            selectedVoiceProviderID: "invalid-provider",
            selectedVoiceModelID: "invalid-model",
            voiceLanguageOverrides: [VoiceLanguageOverride(languageCode: "de", modelID: "missing")],
            voiceProviders: [],
            voiceModels: [],
            installedVoiceModelFileNames: ["ggml-base.en.bin"],
            voiceModelOperationInFlightIDs: []
        )

        let controller = makeController(state: state)

        controller.sanitizeSpeechModelSelections()

        XCTAssertEqual(state.selectedVoiceProviderID, LocalVoiceModelCatalog.defaultProviderID)
        XCTAssertEqual(state.selectedVoiceModelID, LocalVoiceModelCatalog.defaultModelID)
        XCTAssertEqual(state.selectedLanguage, .german)
        XCTAssertEqual(state.translationOutputMode, .english)
        XCTAssertTrue(state.voiceLanguageOverrides.isEmpty)
        XCTAssertFalse(state.voiceProviders.isEmpty)
        XCTAssertFalse(state.voiceModels.isEmpty)
    }

    func testAssignSelectedVoiceModelToCurrentLanguageAddsOverrideAndLogsDiagnostic() {
        let state = SpeechModelControllerState(
            selectedLanguage: .german,
            translationOutputMode: .original,
            selectedVoiceProviderID: LocalVoiceModelCatalog.defaultProviderID,
            selectedVoiceModelID: LocalVoiceModelCatalog.defaultModelID,
            voiceLanguageOverrides: [],
            voiceProviders: LocalVoiceModelCatalog.availableProviders(),
            voiceModels: LocalVoiceModelCatalog.availableModels(includeParakeet: false),
            installedVoiceModelFileNames: ["ggml-base.bin"],
            voiceModelOperationInFlightIDs: []
        )

        let controller = makeController(state: state)

        controller.assignSelectedVoiceModelToCurrentLanguage()

        XCTAssertEqual(
            state.voiceLanguageOverrides,
            [VoiceLanguageOverride(languageCode: "de", modelID: LocalVoiceModelCatalog.defaultModelID)]
        )
        XCTAssertTrue(state.diagnostics.contains(where: { $0.contains("Deutsch") }))
    }

    func testClearSelectedLanguageVoiceOverrideRemovesOnlyCurrentLanguageEntry() {
        let state = SpeechModelControllerState(
            selectedLanguage: .german,
            translationOutputMode: .original,
            selectedVoiceProviderID: LocalVoiceModelCatalog.defaultProviderID,
            selectedVoiceModelID: LocalVoiceModelCatalog.defaultModelID,
            voiceLanguageOverrides: [
                VoiceLanguageOverride(languageCode: "de", modelID: LocalVoiceModelCatalog.defaultModelID),
                VoiceLanguageOverride(languageCode: "en", modelID: "whisper.standard.en"),
            ],
            voiceProviders: LocalVoiceModelCatalog.availableProviders(),
            voiceModels: LocalVoiceModelCatalog.availableModels(includeParakeet: false),
            installedVoiceModelFileNames: ["ggml-base.bin", "ggml-base.en.bin"],
            voiceModelOperationInFlightIDs: []
        )

        let controller = makeController(state: state)

        controller.clearSelectedLanguageVoiceOverride()

        XCTAssertEqual(
            state.voiceLanguageOverrides,
            [VoiceLanguageOverride(languageCode: "en", modelID: "whisper.standard.en")]
        )
    }

    func testCanUseVoiceModelRequiresInstalledWhisperModelAndMatchingLanguage() {
        let englishModel = LocalVoiceModelCatalog.model(id: "whisper.standard.en")!
        let state = SpeechModelControllerState(
            selectedLanguage: .auto,
            translationOutputMode: .original,
            selectedVoiceProviderID: LocalVoiceModelCatalog.defaultProviderID,
            selectedVoiceModelID: englishModel.id,
            voiceLanguageOverrides: [],
            voiceProviders: LocalVoiceModelCatalog.availableProviders(),
            voiceModels: LocalVoiceModelCatalog.availableModels(includeParakeet: false),
            installedVoiceModelFileNames: [],
            voiceModelOperationInFlightIDs: [englishModel.id]
        )

        let controller = makeController(state: state)

        XCTAssertFalse(controller.canUseVoiceModel(englishModel, for: .german))
        XCTAssertFalse(controller.isVoiceModelInstalled(englishModel))
        XCTAssertTrue(controller.isVoiceModelBusy(englishModel))

        state.installedVoiceModelFileNames = ["ggml-base.en.bin"]

        XCTAssertTrue(controller.isVoiceModelInstalled(englishModel))
        XCTAssertTrue(controller.canUseVoiceModel(englishModel, for: .english))
        XCTAssertTrue(controller.canUseVoiceModel(englishModel, for: .auto))
    }

    private func makeController(state: SpeechModelControllerState) -> SpeechModelController {
        SpeechModelController(
            voiceModelInstaller: VoiceModelInstaller(),
            currentSelectedLanguage: { state.selectedLanguage },
            setSelectedLanguage: { state.selectedLanguage = $0 },
            currentTranslationOutputMode: { state.translationOutputMode },
            setTranslationOutputMode: { state.translationOutputMode = $0 },
            currentSelectedVoiceProviderID: { state.selectedVoiceProviderID },
            setSelectedVoiceProviderID: { state.selectedVoiceProviderID = $0 },
            currentSelectedVoiceModelID: { state.selectedVoiceModelID },
            setSelectedVoiceModelID: { state.selectedVoiceModelID = $0 },
            currentVoiceLanguageOverrides: { state.voiceLanguageOverrides },
            setVoiceLanguageOverrides: { state.voiceLanguageOverrides = $0 },
            currentVoiceProviders: { state.voiceProviders },
            setVoiceProviders: { state.voiceProviders = $0 },
            currentVoiceModels: { state.voiceModels },
            setVoiceModels: { state.voiceModels = $0 },
            currentInstalledVoiceModelFileNames: { state.installedVoiceModelFileNames },
            setInstalledVoiceModelFileNames: { state.installedVoiceModelFileNames = $0 },
            currentVoiceModelOperationInFlightIDs: { state.voiceModelOperationInFlightIDs },
            setVoiceModelOperationInFlightIDs: { state.voiceModelOperationInFlightIDs = $0 },
            appendDiagnostic: { state.diagnostics.append($0) }
        )
    }
}

private final class SpeechModelControllerState {
    var selectedLanguage: DictationLanguage
    var translationOutputMode: TranslationOutputMode
    var selectedVoiceProviderID: String
    var selectedVoiceModelID: String
    var voiceLanguageOverrides: [VoiceLanguageOverride]
    var voiceProviders: [VoiceProviderDescriptor]
    var voiceModels: [VoiceModelDescriptor]
    var installedVoiceModelFileNames: Set<String>
    var voiceModelOperationInFlightIDs: Set<String>
    var diagnostics: [String] = []

    init(
        selectedLanguage: DictationLanguage,
        translationOutputMode: TranslationOutputMode,
        selectedVoiceProviderID: String,
        selectedVoiceModelID: String,
        voiceLanguageOverrides: [VoiceLanguageOverride],
        voiceProviders: [VoiceProviderDescriptor],
        voiceModels: [VoiceModelDescriptor],
        installedVoiceModelFileNames: Set<String>,
        voiceModelOperationInFlightIDs: Set<String>
    ) {
        self.selectedLanguage = selectedLanguage
        self.translationOutputMode = translationOutputMode
        self.selectedVoiceProviderID = selectedVoiceProviderID
        self.selectedVoiceModelID = selectedVoiceModelID
        self.voiceLanguageOverrides = voiceLanguageOverrides
        self.voiceProviders = voiceProviders
        self.voiceModels = voiceModels
        self.installedVoiceModelFileNames = installedVoiceModelFileNames
        self.voiceModelOperationInFlightIDs = voiceModelOperationInFlightIDs
    }
}
#endif
