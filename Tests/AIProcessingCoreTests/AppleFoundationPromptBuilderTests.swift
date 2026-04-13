#if canImport(XCTest)
import Foundation
import XCTest
@testable import AIProcessingCore

final class AppleFoundationPromptBuilderTests: XCTestCase {
    func testPromptIncludesContextForAllowedStage() {
        let builder = AppleFoundationPromptBuilder()
        let request = AIProcessingRequest(
            text: "dictated text",
            stage: .final,
            locale: Locale(identifier: "en_US"),
            configuration: AIProcessingConfiguration(
                enabled: true,
                selectedModelID: "apple.ondevice",
                contextAwarenessMode: .finalOnly
            ),
            appContextText: "Project Apollo, attendee: Max Mustermann",
            dictionaryTerms: []
        )

        let prompt = builder.prompt(for: request)

        XCTAssertTrue(prompt.contains("Relevant app context for spelling and disambiguation"))
        XCTAssertTrue(prompt.contains("Project Apollo, attendee: Max Mustermann"))
    }

    func testPromptSkipsContextWhenModeDisallowsStage() {
        let builder = AppleFoundationPromptBuilder()
        let request = AIProcessingRequest(
            text: "dictated text",
            stage: .live,
            locale: Locale(identifier: "en_US"),
            configuration: AIProcessingConfiguration(
                enabled: true,
                selectedModelID: "apple.ondevice",
                contextAwarenessMode: .finalOnly
            ),
            appContextText: "Do not include this context",
            dictionaryTerms: []
        )

        let prompt = builder.prompt(for: request)

        XCTAssertFalse(prompt.contains("Relevant app context for spelling and disambiguation"))
        XCTAssertFalse(prompt.contains("Do not include this context"))
    }

    func testPromptIncludesDictionaryPreservationInstruction() {
        let builder = AppleFoundationPromptBuilder()
        let request = AIProcessingRequest(
            text: "dictated text",
            stage: .final,
            locale: Locale(identifier: "en_US"),
            configuration: AIProcessingConfiguration(
                enabled: true,
                selectedModelID: "apple.ondevice",
                contextAwarenessMode: .finalOnly
            ),
            appContextText: nil,
            dictionaryTerms: ["AcmeCorp", "Dr. Müller", "acmecorp", "  "]
        )

        let prompt = builder.prompt(for: request)

        XCTAssertTrue(prompt.contains("Preserve and spell these preferred terms exactly when applicable"))
        XCTAssertTrue(prompt.contains("AcmeCorp"))
        XCTAssertTrue(prompt.contains("Dr. Müller"))
        XCTAssertFalse(prompt.contains("acmecorp,"))
    }

    func testPromptBoundsContextLength() {
        let builder = AppleFoundationPromptBuilder()
        let longContext = String(repeating: "a", count: 750)
        let request = AIProcessingRequest(
            text: "dictated text",
            stage: .final,
            locale: Locale(identifier: "en_US"),
            configuration: AIProcessingConfiguration(
                enabled: true,
                selectedModelID: "apple.ondevice",
                contextAwarenessMode: .finalOnly
            ),
            appContextText: longContext,
            dictionaryTerms: []
        )

        let prompt = builder.prompt(for: request)

        XCTAssertFalse(prompt.contains(String(repeating: "a", count: 650)))
        XCTAssertTrue(prompt.contains(String(repeating: "a", count: 600)))
    }
}
#endif
