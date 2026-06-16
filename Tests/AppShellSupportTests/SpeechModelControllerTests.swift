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
                voiceLanguageOverrides: [
                    VoiceLanguageOverride(languageCode: "de", modelID: "missing")
                ],
                voiceProviders: [],
                voiceModels: [],
                installedVoiceModelFileNames: ["ggml-base.en.bin"],
                voiceModelOperationStates: [:]
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
                voiceModelOperationStates: [:]
            )

            let controller = makeController(state: state)

            controller.assignSelectedVoiceModelToCurrentLanguage()

            XCTAssertEqual(
                state.voiceLanguageOverrides,
                [
                    VoiceLanguageOverride(
                        languageCode: "de", modelID: LocalVoiceModelCatalog.defaultModelID)
                ]
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
                    VoiceLanguageOverride(
                        languageCode: "de", modelID: LocalVoiceModelCatalog.defaultModelID),
                    VoiceLanguageOverride(languageCode: "en", modelID: "whisper.standard.en"),
                ],
                voiceProviders: LocalVoiceModelCatalog.availableProviders(),
                voiceModels: LocalVoiceModelCatalog.availableModels(includeParakeet: false),
                installedVoiceModelFileNames: ["ggml-base.bin", "ggml-base.en.bin"],
                voiceModelOperationStates: [:]
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
                voiceModelOperationStates: [
                    englishModel.id: .installing(
                        VoiceModelInstallProgress(phase: .downloading, fractionCompleted: 0.42))
                ]
            )

            let controller = makeController(state: state)

            XCTAssertFalse(controller.canUseVoiceModel(englishModel, for: .german))
            XCTAssertFalse(controller.isVoiceModelInstalled(englishModel))
            XCTAssertTrue(controller.isVoiceModelBusy(englishModel))
            XCTAssertEqual(
                controller.voiceModelOperationState(for: englishModel),
                .installing(VoiceModelInstallProgress(phase: .downloading, fractionCompleted: 0.42))
            )

            state.installedVoiceModelFileNames = ["ggml-base.en.bin"]
            state.voiceModelOperationStates = [:]

            XCTAssertTrue(controller.isVoiceModelInstalled(englishModel))
            XCTAssertTrue(controller.canUseVoiceModel(englishModel, for: .english))
            XCTAssertTrue(controller.canUseVoiceModel(englishModel, for: .auto))
        }

        func testIsVoiceModelInstalledReturnsFalseWithoutFileOnDisk() {
            let state = SpeechModelControllerState(
                selectedLanguage: .auto,
                translationOutputMode: .original,
                selectedVoiceProviderID: LocalVoiceModelCatalog.defaultProviderID,
                selectedVoiceModelID: LocalVoiceModelCatalog.defaultModelID,
                voiceLanguageOverrides: [],
                voiceProviders: LocalVoiceModelCatalog.availableProviders(),
                voiceModels: LocalVoiceModelCatalog.availableModels(includeParakeet: false),
                installedVoiceModelFileNames: [],
                voiceModelOperationStates: [:]
            )

            let controller = makeController(state: state)
            let standardModel = LocalVoiceModelCatalog.model(id: LocalVoiceModelCatalog.defaultModelID)!

            XCTAssertFalse(controller.isVoiceModelInstalled(standardModel))
        }

        func testIsVoiceModelInstalledReturnsFalseWhileRemoving() {
            let proModel = LocalVoiceModelCatalog.model(id: "whisper.pro")!
            let state = SpeechModelControllerState(
                selectedLanguage: .auto,
                translationOutputMode: .original,
                selectedVoiceProviderID: LocalVoiceModelCatalog.defaultProviderID,
                selectedVoiceModelID: LocalVoiceModelCatalog.defaultModelID,
                voiceLanguageOverrides: [],
                voiceProviders: LocalVoiceModelCatalog.availableProviders(),
                voiceModels: LocalVoiceModelCatalog.availableModels(includeParakeet: false),
                installedVoiceModelFileNames: ["ggml-base.bin"],
                voiceModelOperationStates: [proModel.id: .removing]
            )

            let controller = makeController(state: state)

            XCTAssertFalse(controller.isVoiceModelInstalled(proModel))
            XCTAssertEqual(controller.voiceModelOperationState(for: proModel), .removing)
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
                currentVoiceModelOperationStates: { state.voiceModelOperationStates },
                setVoiceModelOperationStates: { state.voiceModelOperationStates = $0 },
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
        var voiceModelOperationStates: [String: VoiceModelOperationKind]
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
            voiceModelOperationStates: [String: VoiceModelOperationKind]
        ) {
            self.selectedLanguage = selectedLanguage
            self.translationOutputMode = translationOutputMode
            self.selectedVoiceProviderID = selectedVoiceProviderID
            self.selectedVoiceModelID = selectedVoiceModelID
            self.voiceLanguageOverrides = voiceLanguageOverrides
            self.voiceProviders = voiceProviders
            self.voiceModels = voiceModels
            self.installedVoiceModelFileNames = installedVoiceModelFileNames
            self.voiceModelOperationStates = voiceModelOperationStates
        }
    }
#endif
