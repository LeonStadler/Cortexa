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
                salutation: .formal,
                toneAdjustmentEnabled: true,
                salutationAdjustmentEnabled: true,
                formatAdaptationEnabled: true
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
                salutation: .informal,
                toneAdjustmentEnabled: true,
                salutationAdjustmentEnabled: true,
                formatAdaptationEnabled: true
            )

            let instructions = AppleFoundationPromptBuilder.instructions(for: configuration)

            XCTAssertTrue(
                instructions.contains(
                    "Format the output as a concise personal or professional message."))
            XCTAssertTrue(instructions.contains("Use a friendly and confident style."))
            XCTAssertTrue(instructions.contains("Use an informal form of address."))
        }

        func testCleanupUsesIntensityTier() {
            let configuration = AIProcessingConfiguration(
                enabled: true,
                selectedModelID: "apple.ondevice",
                cleanupIntensity: 0.5
            )

            let instructions = AppleFoundationPromptBuilder.instructions(for: configuration)

            XCTAssertTrue(instructions.contains("Clean up moderately"))
            XCTAssertTrue(
                instructions.contains(
                    "Keep the natural tone that best fits the requested task and format."))
        }

        func testScientificModeSuppressesUnsupportedSalutationAndCasualStyle() {
            let configuration = AIProcessingConfiguration(
                enabled: true,
                selectedModelID: "apple.ondevice",
                revisionGoal: .adaptFormat,
                formattingMode: .scientificPaper,
                style: .casual,
                salutation: .informal,
                toneAdjustmentEnabled: true,
                salutationAdjustmentEnabled: true,
                formatAdaptationEnabled: true
            )

            let instructions = AppleFoundationPromptBuilder.instructions(for: configuration)

            XCTAssertTrue(instructions.contains("Format the output as scientific prose"))
            XCTAssertFalse(instructions.contains("Use a casual, natural style."))
            XCTAssertFalse(instructions.contains("Use an informal form of address."))
        }

        func testAsSpokenSkipsStructuralFormatGoalWhenFormatTaskEnabled() {
            let configuration = AIProcessingConfiguration(
                enabled: true,
                selectedModelID: "apple.ondevice",
                formattingMode: .asSpoken,
                formatAdaptationEnabled: true
            )

            let instructions = AppleFoundationPromptBuilder.instructions(for: configuration)

            XCTAssertFalse(
                instructions.contains("Adapt the dictated text to the requested output format"))
            XCTAssertTrue(instructions.contains("Preserve dictated wording and layout"))
        }

        func testAutomaticFormattingModeIncludesListGuidance() {
            let configuration = AIProcessingConfiguration(
                enabled: true,
                selectedModelID: "apple.ondevice",
                formattingMode: .automaticFromContent,
                formatAdaptationEnabled: true
            )

            let instructions = AppleFoundationPromptBuilder.instructions(for: configuration)

            XCTAssertTrue(instructions.contains("Infer structure from the spoken content"))
            XCTAssertTrue(instructions.contains("bullet or numbered lists"))
        }

        func testCleanupIntensityZeroOmitsCleanupLine() {
            let configuration = AIProcessingConfiguration(
                enabled: true,
                selectedModelID: "apple.ondevice",
                cleanupEnabled: true,
                cleanupIntensity: 0,
                toneAdjustmentEnabled: false,
                salutationAdjustmentEnabled: false,
                formatAdaptationEnabled: false
            )

            let instructions = AppleFoundationPromptBuilder.instructions(for: configuration)

            XCTAssertFalse(instructions.contains("Clean up lightly"))
            XCTAssertFalse(instructions.contains("Clean up moderately"))
            XCTAssertFalse(instructions.contains("Clean up thoroughly"))
        }

        func testPromptIncludesLocaleLanguageHintAndLiveInstruction() {
            let request = AIProcessingRequest(
                text: "Ich geh morgen klettern.",
                stage: .live,
                locale: Locale(identifier: "de_DE"),
                configuration: AIProcessingConfiguration(
                    enabled: true, selectedModelID: "apple.ondevice")
            )

            let prompt = AppleFoundationPromptBuilder.prompt(for: request)

            XCTAssertTrue(prompt.contains("This is a live dictation tail."))
            XCTAssertTrue(prompt.contains("The text language is German."))
            XCTAssertTrue(prompt.contains("Ich geh morgen klettern."))
        }
    }
#endif
