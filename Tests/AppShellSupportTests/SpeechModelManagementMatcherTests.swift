#if canImport(XCTest)
import ASRCore
import XCTest
@testable import AppShellSupport

final class SpeechModelManagementMatcherTests: XCTestCase {
    private let providers = LocalVoiceModelCatalog.availableProviders()

    func testProviderLanguageAndDetailsCanBeCombined() throws {
        let parakeet = try XCTUnwrap(LocalVoiceModelCatalog.model(id: "parakeet.multilingual"))
        let provider = providers.first { $0.id == parakeet.providerID }

        XCTAssertTrue(SpeechModelManagementMatcher.matches(
            "NVIDIA Deutsch nemo", model: parakeet, provider: provider
        ))
        XCTAssertTrue(SpeechModelManagementMatcher.matches(
            "nvidia german", model: parakeet, provider: provider
        ))
        XCTAssertFalse(SpeechModelManagementMatcher.matches(
            "NVIDIA Chinesisch", model: parakeet, provider: provider
        ))
        XCTAssertFalse(SpeechModelManagementMatcher.matches(
            "NVIDIA live", model: parakeet, provider: provider
        ))
    }

    func testLanguageCodeAndFilterRespectModelLimits() throws {
        let english = try XCTUnwrap(LocalVoiceModelCatalog.model(id: "whisper.nano.en"))
        let multilingual = try XCTUnwrap(LocalVoiceModelCatalog.model(id: "whisper.nano"))
        let parakeet = try XCTUnwrap(LocalVoiceModelCatalog.model(id: "parakeet.multilingual"))

        XCTAssertTrue(SpeechModelManagementMatcher.matches("en", model: english, provider: nil))
        XCTAssertFalse(SpeechModelManagementMatcher.matches("de", model: english, provider: nil))
        XCTAssertFalse(SpeechModelManagementMatcher.supports(.german, model: english))
        XCTAssertTrue(SpeechModelManagementMatcher.supports(.german, model: multilingual))
        XCTAssertTrue(SpeechModelManagementMatcher.supports(.german, model: parakeet))
        XCTAssertFalse(SpeechModelManagementMatcher.supports(.chinese, model: parakeet))
        XCTAssertFalse(SpeechModelManagementMatcher.supports(.auto, model: english))
    }
}
#endif
