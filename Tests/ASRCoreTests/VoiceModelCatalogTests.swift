#if canImport(XCTest)
import XCTest
@testable import ASRCore

final class VoiceModelCatalogTests: XCTestCase {
    func testDefaultSelectionUsesRequiredFirstRunStandardModel() {
        XCTAssertEqual(LocalVoiceModelCatalog.defaultProviderID, VoiceProviderID.whisperCpp.rawValue)
        XCTAssertEqual(LocalVoiceModelCatalog.defaultModelID, "whisper.standard")

        let defaultModel = LocalVoiceModelCatalog.model(id: LocalVoiceModelCatalog.defaultModelID)
        XCTAssertEqual(defaultModel?.displayName, "Standard")
        XCTAssertEqual(defaultModel?.localFileName, "ggml-base.bin")
        XCTAssertEqual(defaultModel?.installState, .requiredFirstRun)
        XCTAssertEqual(defaultModel?.expectedDownloadBytes, LocalVoiceModelCatalog.defaultModelExpectedBytes)
    }

    func testProModelSizeMatchesExpectedDownloadBytes() {
        let proModel = LocalVoiceModelCatalog.model(id: "whisper.pro")
        XCTAssertEqual(proModel?.expectedDownloadBytes, LocalVoiceModelCatalog.proModelExpectedBytes)
        XCTAssertEqual(proModel?.sizeLabel, LocalVoiceModelCatalog.formattedDownloadSize(LocalVoiceModelCatalog.proModelExpectedBytes))
    }

    func testEnglishSpecificModelsDisableTranslation() {
        let model = LocalVoiceModelCatalog.model(id: "whisper.pro.en")

        XCTAssertEqual(model?.languageCode, "en")
        XCTAssertFalse(model?.supportsTranslationToEnglish ?? true)
    }

    func testParakeetProviderIsHiddenWithoutLocalBinary() {
        let providers = LocalVoiceModelCatalog.availableProviders(parakeetBinaryURL: nil)
        XCTAssertFalse(providers.contains(where: { $0.id == VoiceProviderID.nvidiaParakeet.rawValue }))
    }
}
#endif
