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
            revisionGoal: .adaptFormat,
            formattingMode: .email,
            style: .business,
            salutation: .formal
        )

        let instructions = AppleFoundationPromptBuilder.instructions(for: configuration)

        XCTAssertTrue(instructions.contains("Format the output as an email"))
        XCTAssertTrue(instructions.contains("Use a businesslike, professional style."))
        XCTAssertTrue(instructions.contains("Use a formal form of address."))
    }

    func testInstructionsIncludeFriendlyConfidentStyleAndInformalSalutation() {
        let configuration = AIProcessingConfiguration(
            enabled: true,
            selectedModelID: "apple.ondevice",
            applyDuringLiveInsertion: true,
            applyToFinalResult: true,
            revisionGoal: .adaptFormat,
            formattingMode: .message,
            style: .friendlyConfident,
            salutation: .informal
        )

        let instructions = AppleFoundationPromptBuilder.instructions(for: configuration)

        XCTAssertTrue(instructions.contains("Format the output as a concise personal or professional message."))
        XCTAssertTrue(instructions.contains("Use a friendly and confident style."))
        XCTAssertTrue(instructions.contains("Use an informal form of address."))
    }

    func testCleanupIsTheDefaultGoal() {
        let configuration = AIProcessingConfiguration(
            enabled: true,
            selectedModelID: "apple.ondevice"
        )

        let instructions = AppleFoundationPromptBuilder.instructions(for: configuration)

        XCTAssertTrue(instructions.contains("Your default task is to clean up dictated text"))
        XCTAssertTrue(instructions.contains("Keep the natural tone that best fits the requested task and format."))
    }

    func testScientificModeSuppressesUnsupportedSalutationAndCasualStyle() {
        let configuration = AIProcessingConfiguration(
            enabled: true,
            selectedModelID: "apple.ondevice",
            revisionGoal: .adaptFormat,
            formattingMode: .scientificPaper,
            style: .casual,
            salutation: .informal
        )

        let instructions = AppleFoundationPromptBuilder.instructions(for: configuration)

        XCTAssertTrue(instructions.contains("Format the output as scientific prose"))
        XCTAssertFalse(instructions.contains("Use a casual, natural style."))
        XCTAssertFalse(instructions.contains("Use an informal form of address."))
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
