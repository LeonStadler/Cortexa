#if canImport(XCTest)
import AIProcessingCore
import ASRCore
import AudioCore
import SnippetCore
import XCTest
@testable import AppShellSupport

final class SessionConfigurationBuilderTests: XCTestCase {
    func testBuildUsesFinalizeModeForClipboardOnlyDelivery() {
        let result = SessionConfigurationBuilder().build(
            from: makeInput(finalResultDeliveryMode: .clipboardOnly)
        )

        XCTAssertEqual(result.mode, DictationMode.finalize)
        XCTAssertEqual(
            result.finalResultDeliveryMode,
            FinalResultDeliveryMode.clipboardOnly
        )
    }

    func testParakeetSelectionUsesFinalizeModeEvenWhenLiveInsertionIsEnabled() {
        let parakeet = VoiceModelDescriptor(
            id: "parakeet.multilingual",
            providerID: VoiceProviderID.nvidiaParakeet.rawValue,
            displayName: "Parakeet TDT v3",
            languageCode: nil,
            languageScope: .multilingual,
            supportsTranslationToEnglish: false,
            supportsLiveTranscription: false,
            supportsAutomaticLanguageDetection: true,
            supportsLanguageSelection: false,
            supportsQualityProfile: false,
            supportedLanguageCodes: ["de", "en", "fr"],
            speedScore: 10,
            accuracyScore: 8,
            sizeLabel: "runtime managed",
            installState: .downloadable,
            localFileName: "parakeet-tdt-0.6b-v3.q8_0.gguf",
            downloadIdentifier: "parakeet-tdt"
        )
        let result = SessionConfigurationBuilder().build(
            from: makeInput(
                selectedLanguage: .auto,
                translationOutputMode: .english,
                performanceProfile: .accurate,
                selectedVoiceProviderID: VoiceProviderID.nvidiaParakeet.rawValue,
                selectedVoiceModelID: parakeet.id,
                voiceModels: [parakeet],
                installedVoiceModelFileNames: ["parakeet-tdt-0.6b-v3.q8_0.gguf"]
            )
        )

        XCTAssertEqual(result.mode, DictationMode.finalize)
        XCTAssertEqual(result.selectedVoiceProviderID, VoiceProviderID.nvidiaParakeet.rawValue)
        XCTAssertEqual(result.selectedVoiceModelID, parakeet.id)
        XCTAssertEqual(result.translationOutput, TranslationOutputMode.original)
        XCTAssertEqual(result.performance, DictationPerformance.auto)
    }

    func testBuildSelectsExpectedModeForEveryStreamingAndDeliveryCombination() {
        let builder = SessionConfigurationBuilder()

        for streamingEnabled in [false, true] {
            for deliveryMode in [FinalResultDeliveryMode.insert, .clipboardOnly] {
                let result = builder.build(
                    from: makeInput(
                        streamingEnabled: streamingEnabled,
                        finalResultDeliveryMode: deliveryMode
                    )
                )

                let expectedMode: DictationMode = streamingEnabled && deliveryMode == .insert
                    ? .streaming
                    : .finalize
                XCTAssertEqual(
                    result.mode,
                    expectedMode,
                    "streamingEnabled=\(streamingEnabled), deliveryMode=\(deliveryMode)"
                )
                XCTAssertEqual(result.finalResultDeliveryMode, deliveryMode)
            }
        }
    }

    func testBuildPrefersLanguageOverrideWhenModelIsInstalled() {
        let overrideModel = VoiceModelDescriptor(
            id: "override-model",
            providerID: VoiceProviderID.whisperCpp.rawValue,
            displayName: "Override",
            languageCode: "en",
            languageScope: .english,
            supportsTranslationToEnglish: true,
            speedScore: 2,
            accuracyScore: 3,
            sizeLabel: "S",
            installState: .downloadable,
            localFileName: "override.bin",
            downloadIdentifier: nil
        )
        let selectedModel = VoiceModelDescriptor(
            id: "selected-model",
            providerID: VoiceProviderID.whisperCpp.rawValue,
            displayName: "Selected",
            languageCode: nil,
            languageScope: .multilingual,
            supportsTranslationToEnglish: true,
            speedScore: 2,
            accuracyScore: 3,
            sizeLabel: "M",
            installState: .downloadable,
            localFileName: "selected.bin",
            downloadIdentifier: nil
        )

        let result = SessionConfigurationBuilder().build(
            from: makeInput(
                selectedLanguage: .english,
                selectedVoiceProviderID: VoiceProviderID.whisperCpp.rawValue,
                selectedVoiceModelID: selectedModel.id,
                voiceLanguageOverrides: [
                    VoiceLanguageOverride(languageCode: "en", modelID: overrideModel.id)
                ],
                voiceModels: [selectedModel, overrideModel],
                installedVoiceModelFileNames: ["selected.bin", "override.bin"]
            )
        )

        XCTAssertEqual(result.selectedVoiceModelID, overrideModel.id)
        XCTAssertEqual(result.selectedVoiceProviderID, overrideModel.providerID)
    }

    func testBuildFallsBackToSelectedModelWhenOverrideIsUnavailable() {
        let selectedModel = VoiceModelDescriptor(
            id: "selected-model",
            providerID: VoiceProviderID.whisperCpp.rawValue,
            displayName: "Selected",
            languageCode: nil,
            languageScope: .multilingual,
            supportsTranslationToEnglish: true,
            speedScore: 2,
            accuracyScore: 3,
            sizeLabel: "M",
            installState: .downloadable,
            localFileName: "selected.bin",
            downloadIdentifier: nil
        )

        let result = SessionConfigurationBuilder().build(
            from: makeInput(
                selectedVoiceProviderID: VoiceProviderID.whisperCpp.rawValue,
                selectedVoiceModelID: selectedModel.id,
                voiceLanguageOverrides: [
                    VoiceLanguageOverride(languageCode: "en", modelID: "missing")
                ],
                voiceModels: [selectedModel],
                installedVoiceModelFileNames: ["selected.bin"]
            )
        )

        XCTAssertEqual(result.selectedVoiceModelID, selectedModel.id)
    }

    func testBuildPassesDictionaryContextAndMediaOptionsThrough() {
        let result = SessionConfigurationBuilder().build(
            from: makeInput(
                muteMusicWhileDictating: true,
                asrInitialPrompt: "Preferred terms: WisprLocal",
                dictionaryTerms: ["WisprLocal", "OpenRouter"],
                liveContextText: "Current sentence context",
                finalContextText: "Longer final context"
            )
        )

        XCTAssertTrue(result.muteMusicWhileDictating)
        XCTAssertEqual(result.asrInitialPrompt, "Preferred terms: WisprLocal")
        XCTAssertEqual(result.dictionaryTerms, ["WisprLocal", "OpenRouter"])
        XCTAssertEqual(result.liveContextText, "Current sentence context")
        XCTAssertEqual(result.finalContextText, "Longer final context")
    }

    private func makeInput(
        streamingEnabled: Bool = true,
        selectedLanguage: DictationLanguage = .german,
        translationOutputMode: TranslationOutputMode = .original,
        performanceProfile: DictationPerformance = .auto,
        finalResultDeliveryMode: FinalResultDeliveryMode = .insert,
        muteMusicWhileDictating: Bool = false,
        asrInitialPrompt: String? = nil,
        dictionaryTerms: [String] = [],
        liveContextText: String? = nil,
        finalContextText: String? = nil,
        selectedVoiceProviderID: String = LocalVoiceModelCatalog.defaultProviderID,
        selectedVoiceModelID: String = LocalVoiceModelCatalog.defaultModelID,
        voiceLanguageOverrides: [VoiceLanguageOverride] = [],
        voiceModels: [VoiceModelDescriptor] = [],
        installedVoiceModelFileNames: Set<String> = []
    ) -> SessionConfigurationInput {
        SessionConfigurationInput(
            streamingEnabled: streamingEnabled,
            selectedLanguage: selectedLanguage,
            translationOutputMode: translationOutputMode,
            performanceProfile: performanceProfile,
            selectedVoiceProviderID: selectedVoiceProviderID,
            selectedVoiceModelID: selectedVoiceModelID,
            voiceLanguageOverrides: voiceLanguageOverrides,
            voiceModels: voiceModels,
            installedVoiceModelFileNames: installedVoiceModelFileNames,
            liveRewriteScope: .currentSentence,
            snippetRules: [],
            finalResultDeliveryMode: finalResultDeliveryMode,
            clipboardFallbackWhenNoTarget: false,
            simulateKeypresses: false,
            restoreClipboardAfterPaste: false,
            autoSendAfterPaste: false,
            muteMusicWhileDictating: muteMusicWhileDictating,
            asrInitialPrompt: asrInitialPrompt,
            dictionaryTerms: dictionaryTerms,
            liveContextText: liveContextText,
            finalContextText: finalContextText,
            aiProcessing: AIProcessingConfiguration(
                enabled: false,
                selectedModelID: nil,
                applyDuringLiveInsertion: false,
                applyToFinalResult: false,
                revisionGoal: .cleanup,
                formattingMode: .asSpoken,
                style: .none,
                salutation: .none,
                cleanupEnabled: true,
                cleanupIntensity: 0.5,
                toneAdjustmentEnabled: false,
                salutationAdjustmentEnabled: false,
                formatAdaptationEnabled: false
            ),
            audioProcessing: AudioProcessingConfiguration(
                inputLevelCompensationEnabled: false,
                silenceRemovalEnabled: false,
                dynamicNormalizationEnabled: false,
                noiseSuppressionLevel: 0
            ),
            soundFeedback: SoundFeedbackConfiguration(
                enabled: false,
                volume: 0
            )
        )
    }
}
#endif
