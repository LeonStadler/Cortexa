#if canImport(XCTest)
import Foundation
import XCTest
@testable import AIProcessingCore

final class AppleFoundationPromptBuilderTests: XCTestCase {
    func testInstructionsIncludeSelectedStyleAndFormalSalutation() {
        let configuration = AIProcessingConfiguration(
            enabled: true,
            selectedModelID: "apple.ondevice",
            applyDuringLiveInsertion: true,
            applyToFinalResult: true,
            style: .business,
            salutation: .formal
        )

        let instructions = AppleFoundationPromptBuilder.instructions(for: configuration)

        XCTAssertTrue(instructions.contains("Rewrite in a businesslike, professional style."))
        XCTAssertTrue(instructions.contains("Use a formal form of address."))
    }

    func testInstructionsIncludeFriendlyConfidentStyleAndInformalSalutation() {
        let configuration = AIProcessingConfiguration(
            enabled: true,
            selectedModelID: "apple.ondevice",
            applyDuringLiveInsertion: true,
            applyToFinalResult: true,
            style: .friendlyConfident,
            salutation: .informal
        )

        let instructions = AppleFoundationPromptBuilder.instructions(for: configuration)

        XCTAssertTrue(instructions.contains("Rewrite in a friendly and confident style."))
        XCTAssertTrue(instructions.contains("Use an informal form of address."))
    }

    func testPromptIncludesLocaleLanguageHintAndLiveInstruction() {
        let request = AIProcessingRequest(
            text: "Ich geh morgen klettern.",
            stage: .live,
            locale: Locale(identifier: "de_DE"),
            configuration: AIProcessingConfiguration(enabled: true, selectedModelID: "apple.ondevice")
        )

        let prompt = AppleFoundationPromptBuilder.prompt(for: request)

        XCTAssertTrue(prompt.contains("This is a live dictation tail."))
        XCTAssertTrue(prompt.contains("The text language is German."))
        XCTAssertTrue(prompt.contains("Ich geh morgen klettern."))
    }
}
#endif
