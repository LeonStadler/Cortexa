#if canImport(XCTest)
import Foundation
import XCTest
@testable import AppShellSupport

@MainActor
final class MacAppStateLifecycleAndContextFacadeTests: XCTestCase {
    func testUpdaterStateSnapshotReflectsConfiguredUpdater() {
        let configuration = MacAppConfiguration(
            licensePublicKeyBase64: nil,
            sparkleFeedURL: URL(string: "https://example.com/appcast.xml"),
            sparklePublicEDKey: "public-ed-key",
            isLicenseUIEnabledForDevelopment: false
        )
        let facade = MacAppStateLifecyclePolicyFacade(
            appConfiguration: configuration,
            appendDiagnostic: { _ in },
            currentOpenSettingsHandler: { nil },
            currentDockPolicySettingsReopenWorkItem: { nil },
            setDockPolicySettingsReopenWorkItem: { _ in }
        )

        let snapshot = facade.updaterStateSnapshot()

        XCTAssertTrue(snapshot.configured)
        XCTAssertEqual(snapshot.feedURLText, "https://example.com/appcast.xml")
        XCTAssertEqual(snapshot.statusText, "Updater konfiguriert")
    }

    func testBuildDictionaryHintPromptFiltersTermsForSelectedLanguage() {
        let german = DictionaryTerm(
            term: "WisprLocal",
            category: .companyJargon,
            source: .manual,
            languageCode: "de"
        )
        let english = DictionaryTerm(
            term: "Prompt",
            category: .custom,
            source: .manual,
            languageCode: "en"
        )

        let prompt = MacAppStateContextSuggestionFacade.buildDictionaryHintPrompt(
            selectedLanguage: .german,
            dictionaryTerms: [german, english]
        )

        XCTAssertEqual(prompt, "Preferred terms: WisprLocal")
    }
}
#endif
