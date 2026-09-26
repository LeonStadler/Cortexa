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

    func testParakeetProviderRemainsVisibleButUnavailableWithoutLocalBinary() {
        let providers = LocalVoiceModelCatalog.availableProviders(parakeetBinaryURL: nil)
        let parakeet = providers.first(where: { $0.id == VoiceProviderID.nvidiaParakeet.rawValue })
        XCTAssertNotNil(parakeet)
        XCTAssertFalse(parakeet?.isAvailable ?? true)
    }

    func testParakeetProviderIsVisibleWithExecutableRuntime() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let executable = directory.appendingPathComponent("nemo-speech")
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)

        let providers = LocalVoiceModelCatalog.availableProviders(parakeetBinaryURL: executable)
        XCTAssertTrue(providers.contains(where: { $0.id == VoiceProviderID.nvidiaParakeet.rawValue }))
    }

    func testParakeetTDTModelIsMultilingualAndOfflineOnly() {
        let model = LocalVoiceModelCatalog.model(id: "parakeet.multilingual")
        XCTAssertEqual(model?.providerID, VoiceProviderID.nvidiaParakeet.rawValue)
        XCTAssertEqual(model?.languageScope, .multilingual)
        XCTAssertFalse(model?.supportsTranslationToEnglish ?? true)
        XCTAssertFalse(model?.supportsLiveTranscription ?? true)
        XCTAssertTrue(model?.supportsAutomaticLanguageDetection ?? false)
        XCTAssertFalse(model?.supportsLanguageSelection ?? true)
        XCTAssertEqual(model?.localFileName, "parakeet-tdt-0.6b-v3.q8_0.gguf")
        XCTAssertEqual(model?.expectedDownloadBytes, LocalVoiceModelCatalog.parakeetExpectedBytes)
        XCTAssertEqual(model?.supportedLanguageCodes?.count, 25)
        XCTAssertEqual(model?.installState, .downloadable)
        XCTAssertEqual(model?.runtimeID, "nemo-speech")
    }
}
#endif
