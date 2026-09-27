#if canImport(XCTest)
import ASRCore
import XCTest
@testable import AppShellSupport

final class VoiceModelCapabilityPolicyTests: XCTestCase {
    private let policy = VoiceModelCapabilityPolicy()
    private let models = LocalVoiceModelCatalog.availableModels(includeParakeet: true)

    func testEnglishNanoPrefersMultilingualNanoForGermanAndAuto() {
        let englishNano = model("whisper.nano.en")
        for language in [DictationLanguage.german, .auto] {
            let suggestion = policy.suggestedModel(
                for: .language(language), currentModel: englishNano,
                currentLanguage: .english, catalog: models, installedFiles: []
            )
            XCTAssertEqual(suggestion?.id, "whisper.nano")
        }
    }

    func testParakeetOffersInstalledCompatibleModelForFixedLanguageAndFeatures() {
        let parakeet = model("parakeet.multilingual")
        let standard = model("whisper.standard")
        let files: Set<String> = [standard.localFileName!]
        let choices: [VoiceModelCapabilityChoice] = [
            .language(.german), .translation(.english), .liveText, .quality(.accurate)
        ]
        for choice in choices {
            XCTAssertFalse(policy.supports(choice, model: parakeet, currentLanguage: .auto))
            XCTAssertEqual(policy.suggestedModel(
                for: choice, currentModel: parakeet, currentLanguage: .auto,
                catalog: models, installedFiles: files)?.id, standard.id)
        }
    }

    func testSuggestedFeatureModelAlsoSupportsCurrentLanguage() {
        let parakeet = model("parakeet.multilingual")
        let englishNano = model("whisper.nano.en")
        let standard = model("whisper.standard")
        let files: Set<String> = [englishNano.localFileName!, standard.localFileName!]
        XCTAssertEqual(policy.suggestedModel(
            for: .liveText, currentModel: parakeet, currentLanguage: .auto,
            catalog: models, installedFiles: files)?.id, standard.id)
    }

    func testLanguageSuggestionSupportsBothCurrentAndRequestedLanguage() {
        let englishNano = model("whisper.nano.en")
        let standard = model("whisper.standard")
        let germanOnly = VoiceModelDescriptor(
            id: "german-only", providerID: VoiceProviderID.whisperCpp.rawValue,
            displayName: "German only", languageCode: "de", languageScope: .multilingual,
            supportsTranslationToEnglish: false,
            supportsAutomaticLanguageDetection: false,
            speedScore: 9, accuracyScore: 3, sizeLabel: "S",
            installState: .downloadable, localFileName: "german-only.bin"
        )
        XCTAssertEqual(policy.suggestedModel(
            for: .language(.german), currentModel: englishNano,
            currentLanguage: .english, catalog: [englishNano, germanOnly, standard],
            installedFiles: ["german-only.bin"])?.id, standard.id)
    }

    func testEffectiveModelUsesInstalledLanguageOverrideLikeSessionBuilder() {
        let englishNano = model("whisper.nano.en")
        let standard = model("whisper.standard")
        let override = VoiceLanguageOverride(languageCode: "en", modelID: englishNano.id)
        let files: Set<String> = [englishNano.localFileName!, standard.localFileName!]
        XCTAssertEqual(policy.effectiveModel(
            for: .english, selectedModelID: standard.id, overrides: [override],
            catalog: models, installedFiles: files)?.id, englishNano.id)
        XCTAssertEqual(policy.effectiveModel(
            for: .auto, selectedModelID: standard.id, overrides: [override],
            catalog: models, installedFiles: files)?.id, standard.id)
    }

    private func model(_ id: String) -> VoiceModelDescriptor {
        LocalVoiceModelCatalog.model(id: id)!
    }
}
#endif
