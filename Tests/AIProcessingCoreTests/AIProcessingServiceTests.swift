#if canImport(XCTest)
    import Foundation
    import XCTest
    @testable import AIProcessingCore

    private struct StubProvider: AITextProcessingProviding {
        let providerID: String
        let providerKind: AIProviderKind
        let descriptors: [AIModelDescriptor]
        let handler: @Sendable (AIProcessingRequest, AIModelDescriptor) async throws -> String

        func models() -> [AIModelDescriptor] {
            descriptors
        }

        func process(_ request: AIProcessingRequest, model: AIModelDescriptor) async throws
            -> String
        {
            try await handler(request, model)
        }
    }

    private actor ProcessingInvocationRecorder {
        private var stages: [AIProcessingStage] = []

        func record(_ stage: AIProcessingStage) {
            stages.append(stage)
        }

        func recordedStages() -> [AIProcessingStage] {
            stages
        }
    }

    final class AIProcessingServiceTests: XCTestCase {
        func testLiveAndFinalProcessingToggleMatrixOnlyInvokesEnabledStages() async {
            for processingEnabled in [false, true] {
                for liveEnabled in [false, true] {
                    for finalEnabled in [false, true] {
                        let recorder = ProcessingInvocationRecorder()
                        let provider = StubProvider(
                            providerID: "apple.foundation",
                            providerKind: .appleFoundation,
                            descriptors: [
                                AIModelDescriptor(
                                    id: "apple.ondevice",
                                    providerID: "apple.foundation",
                                    requestModelID: "apple.ondevice",
                                    displayName: "Apple",
                                    providerKind: .appleFoundation,
                                    availability: .available,
                                    quickSettingsEligible: true
                                )
                            ]
                        ) { request, _ in
                            await recorder.record(request.stage)
                            return request.text + " revised"
                        }
                        let service = AIProcessingService(providers: [provider])
                        let configuration = AIProcessingConfiguration(
                            enabled: processingEnabled,
                            selectedModelID: "apple.ondevice",
                            applyDuringLiveInsertion: liveEnabled,
                            applyToFinalResult: finalEnabled,
                            cleanupEnabled: true,
                            cleanupIntensity: 0.5
                        )

                        let liveOutcome = await service.process(
                            AIProcessingRequest(
                                text: "live draft",
                                stage: .live,
                                locale: Locale(identifier: "de_DE"),
                                configuration: configuration
                            )
                        )
                        let finalOutcome = await service.process(
                            AIProcessingRequest(
                                text: "final draft",
                                stage: .final,
                                locale: Locale(identifier: "de_DE"),
                                configuration: configuration
                            )
                        )

                        let shouldProcessLive = processingEnabled && liveEnabled
                        let shouldProcessFinal = processingEnabled && finalEnabled
                        XCTAssertEqual(
                            liveOutcome.text,
                            shouldProcessLive ? "live draft revised" : "live draft"
                        )
                        XCTAssertEqual(
                            finalOutcome.text,
                            shouldProcessFinal ? "final draft revised" : "final draft"
                        )
                        let expectedStages: [AIProcessingStage] =
                            (shouldProcessLive ? [.live] : [])
                            + (shouldProcessFinal ? [.final] : [])
                        let recordedStages = await recorder.recordedStages()
                        XCTAssertEqual(recordedStages, expectedStages)
                    }
                }
            }
        }

        func testQuickSettingsFilterReturnsOnlyAvailableOperationalModels() {
            let catalog = AIModelCatalog(descriptors: [
                AIModelDescriptor(
                    id: "a", displayName: "A", providerKind: .appleFoundation,
                    availability: .available, quickSettingsEligible: true),
                AIModelDescriptor(
                    id: "b", displayName: "B", providerKind: .remoteAPI,
                    availability: .unavailable(reason: "Missing key"), quickSettingsEligible: true),
                AIModelDescriptor(
                    id: "c", displayName: "C", providerKind: .localDownloaded,
                    availability: .available, quickSettingsEligible: false),
            ])

            XCTAssertEqual(catalog.quickSettingsModels.map(\.id), ["a"])
        }

        func testAvailableModelsReturnAllAvailableEntries() {
            let catalog = AIModelCatalog(descriptors: [
                AIModelDescriptor(
                    id: "stable", displayName: "Stable", providerKind: .appleFoundation,
                    availability: .available, quickSettingsEligible: true),
                AIModelDescriptor(
                    id: "remote", displayName: "Remote", providerKind: .remoteAPI,
                    availability: .available, quickSettingsEligible: true),
            ])

            XCTAssertEqual(catalog.availableModels.map(\.id), ["remote", "stable"])
            XCTAssertEqual(catalog.quickSettingsModels.map(\.id), ["remote", "stable"])
        }

        func testNeutralTasksBypassProviderCall() async {
            let provider = StubProvider(
                providerID: "apple.foundation",
                providerKind: .appleFoundation,
                descriptors: [
                    AIModelDescriptor(
                        id: "apple.ondevice", providerID: "apple.foundation",
                        requestModelID: "apple.ondevice", displayName: "Apple",
                        providerKind: .appleFoundation, availability: .available,
                        quickSettingsEligible: true)
                ]
            ) { _, _ in
                XCTFail(
                    "Provider should not run when every task is neutral (no substantive revision).")
                return ""
            }
            let service = AIProcessingService(providers: [provider])

            let outcome = await service.process(
                AIProcessingRequest(
                    text: "Hallo",
                    stage: .final,
                    locale: Locale(identifier: "de_DE"),
                    configuration: AIProcessingConfiguration(
                        enabled: true,
                        selectedModelID: "apple.ondevice",
                        applyDuringLiveInsertion: true,
                        applyToFinalResult: true,
                        formattingMode: .asSpoken,
                        style: .none,
                        salutation: .none,
                        cleanupEnabled: true,
                        cleanupIntensity: 0,
                        toneAdjustmentEnabled: false,
                        salutationAdjustmentEnabled: false,
                        formatAdaptationEnabled: true
                    )
                )
            )

            XCTAssertEqual(outcome.text, "Hallo")
            if case .bypassed(_, let reason) = outcome {
                XCTAssertTrue(reason.contains("no substantive"))
            } else {
                XCTFail("Expected bypassed outcome.")
            }
        }

        func testDisabledConfigurationBypassesProviderCall() async {
            let provider = StubProvider(
                providerID: "apple.foundation",
                providerKind: .appleFoundation,
                descriptors: [
                    AIModelDescriptor(
                        id: "apple.ondevice", providerID: "apple.foundation",
                        requestModelID: "apple.ondevice", displayName: "Apple",
                        providerKind: .appleFoundation, availability: .available,
                        quickSettingsEligible: true)
                ]
            ) { _, _ in
                XCTFail("Provider should not be called when AI processing is disabled.")
                return ""
            }
            let service = AIProcessingService(providers: [provider])

            let outcome = await service.process(
                AIProcessingRequest(
                    text: "Hallo Welt",
                    stage: .final,
                    locale: Locale(identifier: "de_DE"),
                    configuration: AIProcessingConfiguration(
                        enabled: false, selectedModelID: "apple.ondevice")
                )
            )

            XCTAssertEqual(outcome.text, "Hallo Welt")
            if case .bypassed(_, let reason) = outcome {
                XCTAssertTrue(reason.contains("disabled"))
            } else {
                XCTFail("Expected bypassed outcome.")
            }
        }

        func testLiveProcessingToggleSkipsLiveProcessingWhenDisabled() async {
            let provider = StubProvider(
                providerID: "apple.foundation",
                providerKind: .appleFoundation,
                descriptors: [
                    AIModelDescriptor(
                        id: "apple.ondevice", providerID: "apple.foundation",
                        requestModelID: "apple.ondevice", displayName: "Apple",
                        providerKind: .appleFoundation, availability: .available,
                        quickSettingsEligible: true)
                ]
            ) { _, _ in
                XCTFail(
                    "Provider should not be called for live processing when live application is disabled."
                )
                return ""
            }
            let service = AIProcessingService(providers: [provider])

            let outcome = await service.process(
                AIProcessingRequest(
                    text: "draft",
                    stage: .live,
                    locale: Locale(identifier: "en_US"),
                    configuration: AIProcessingConfiguration(
                        enabled: true, selectedModelID: "apple.ondevice",
                        applyDuringLiveInsertion: false, applyToFinalResult: true)
                )
            )

            XCTAssertEqual(outcome.text, "draft")
        }

        func testLiveProcessingToggleProcessesLiveRequestsWhenEnabled() async {
            let provider = StubProvider(
                providerID: "apple.foundation",
                providerKind: .appleFoundation,
                descriptors: [
                    AIModelDescriptor(
                        id: "apple.ondevice", providerID: "apple.foundation",
                        requestModelID: "apple.ondevice", displayName: "Apple",
                        providerKind: .appleFoundation, availability: .available,
                        quickSettingsEligible: true)
                ]
            ) { request, model in
                XCTAssertEqual(request.stage, .live)
                XCTAssertEqual(model.id, "apple.ondevice")
                return "Live polished"
            }
            let service = AIProcessingService(providers: [provider])

            let outcome = await service.process(
                AIProcessingRequest(
                    text: "draft",
                    stage: .live,
                    locale: Locale(identifier: "en_US"),
                    configuration: AIProcessingConfiguration(
                        enabled: true, selectedModelID: "apple.ondevice",
                        applyDuringLiveInsertion: true, applyToFinalResult: true)
                )
            )

            XCTAssertEqual(outcome, .processed(text: "Live polished", modelID: "apple.ondevice"))
        }

        func testFinalProcessingToggleSkipsFinalProcessingWhenDisabled() async {
            let provider = StubProvider(
                providerID: "apple.foundation",
                providerKind: .appleFoundation,
                descriptors: [
                    AIModelDescriptor(
                        id: "apple.ondevice", providerID: "apple.foundation",
                        requestModelID: "apple.ondevice", displayName: "Apple",
                        providerKind: .appleFoundation, availability: .available,
                        quickSettingsEligible: true)
                ]
            ) { _, _ in
                XCTFail(
                    "Provider should not be called for final processing when final application is disabled."
                )
                return ""
            }
            let service = AIProcessingService(providers: [provider])

            let outcome = await service.process(
                AIProcessingRequest(
                    text: "final draft",
                    stage: .final,
                    locale: Locale(identifier: "en_US"),
                    configuration: AIProcessingConfiguration(
                        enabled: true,
                        selectedModelID: "apple.ondevice",
                        applyDuringLiveInsertion: true,
                        applyToFinalResult: false)
                )
            )

            XCTAssertEqual(outcome.text, "final draft")
            if case .bypassed(_, let reason) = outcome {
                XCTAssertTrue(reason.contains("disabled for final results"))
            } else {
                XCTFail("Expected bypassed outcome.")
            }
        }

        func testFinalProcessingPassesFinalStageRequestToProvider() async {
            let provider = StubProvider(
                providerID: "apple.foundation",
                providerKind: .appleFoundation,
                descriptors: [
                    AIModelDescriptor(
                        id: "apple.ondevice", providerID: "apple.foundation",
                        requestModelID: "apple.ondevice", displayName: "Apple",
                        providerKind: .appleFoundation, availability: .available,
                        quickSettingsEligible: true)
                ]
            ) { request, model in
                XCTAssertEqual(request.stage, .final)
                XCTAssertEqual(model.id, "apple.ondevice")
                XCTAssertTrue(request.configuration.applyToFinalResult)
                return "Final polished"
            }
            let service = AIProcessingService(providers: [provider])

            let outcome = await service.process(
                AIProcessingRequest(
                    text: "final draft",
                    stage: .final,
                    locale: Locale(identifier: "en_US"),
                    configuration: AIProcessingConfiguration(
                        enabled: true,
                        selectedModelID: "apple.ondevice",
                        applyDuringLiveInsertion: false,
                        applyToFinalResult: true,
                        cleanupEnabled: true,
                        cleanupIntensity: 0.5)
                )
            )

            XCTAssertEqual(outcome, .processed(text: "Final polished", modelID: "apple.ondevice"))
        }

        func testUnavailableModelBypassesProviderCall() async {
            let provider = StubProvider(
                providerID: "apple.foundation",
                providerKind: .appleFoundation,
                descriptors: [
                    AIModelDescriptor(
                        id: "apple.ondevice",
                        providerID: "apple.foundation",
                        requestModelID: "apple.ondevice",
                        displayName: "Apple",
                        providerKind: .appleFoundation,
                        availability: .unavailable(
                            reason: "Foundation Models runtime not available"),
                        quickSettingsEligible: true
                    )
                ]
            ) { _, _ in
                XCTFail("Provider should not be called when the selected model is unavailable.")
                return ""
            }
            let service = AIProcessingService(providers: [provider])

            let outcome = await service.process(
                AIProcessingRequest(
                    text: "raw text",
                    stage: .final,
                    locale: Locale(identifier: "en_US"),
                    configuration: AIProcessingConfiguration(
                        enabled: true, selectedModelID: "apple.ondevice",
                        applyDuringLiveInsertion: true, applyToFinalResult: true)
                )
            )

            XCTAssertEqual(outcome.text, "raw text")
            if case .bypassed(_, let reason) = outcome {
                XCTAssertTrue(reason.contains("Foundation Models runtime not available"))
            } else {
                XCTFail("Expected bypassed outcome.")
            }
        }

        func testMissingModelSelectionBypassesProviderCall() async {
            let provider = StubProvider(
                providerID: "apple.foundation",
                providerKind: .appleFoundation,
                descriptors: [
                    AIModelDescriptor(
                        id: "apple.ondevice", providerID: "apple.foundation",
                        requestModelID: "apple.ondevice", displayName: "Apple",
                        providerKind: .appleFoundation, availability: .available,
                        quickSettingsEligible: true)
                ]
            ) { _, _ in
                XCTFail("Provider should not be called when no model is selected.")
                return ""
            }
            let service = AIProcessingService(providers: [provider])

            let outcome = await service.process(
                AIProcessingRequest(
                    text: "raw text",
                    stage: .final,
                    locale: Locale(identifier: "en_US"),
                    configuration: AIProcessingConfiguration(
                        enabled: true, selectedModelID: nil, applyDuringLiveInsertion: true,
                        applyToFinalResult: true)
                )
            )

            XCTAssertEqual(outcome.text, "raw text")
            if case .bypassed(_, let reason) = outcome {
                XCTAssertTrue(reason.contains("no usable model is selected"))
            } else {
                XCTFail("Expected bypassed outcome.")
            }
        }

        func testProviderFailureFallsBackToOriginalText() async {
            let provider = StubProvider(
                providerID: "apple.foundation",
                providerKind: .appleFoundation,
                descriptors: [
                    AIModelDescriptor(
                        id: "apple.ondevice", providerID: "apple.foundation",
                        requestModelID: "apple.ondevice", displayName: "Apple",
                        providerKind: .appleFoundation, availability: .available,
                        quickSettingsEligible: true)
                ]
            ) { _, _ in
                struct DummyError: LocalizedError {
                    var errorDescription: String? { "boom" }
                }
                throw DummyError()
            }
            let service = AIProcessingService(providers: [provider])

            let outcome = await service.process(
                AIProcessingRequest(
                    text: "raw text",
                    stage: .final,
                    locale: Locale(identifier: "en_US"),
                    configuration: AIProcessingConfiguration(
                        enabled: true, selectedModelID: "apple.ondevice",
                        applyDuringLiveInsertion: true, applyToFinalResult: true)
                )
            )

            XCTAssertEqual(outcome.text, "raw text")
            if case .failedFallback(_, let modelID, let reason) = outcome {
                XCTAssertEqual(modelID, "apple.ondevice")
                XCTAssertTrue(reason.contains("boom"))
            } else {
                XCTFail("Expected failed fallback outcome.")
            }
        }

        func testSuccessfulProcessingReturnsProcessedText() async {
            let provider = StubProvider(
                providerID: "apple.foundation",
                providerKind: .appleFoundation,
                descriptors: [
                    AIModelDescriptor(
                        id: "apple.ondevice", providerID: "apple.foundation",
                        requestModelID: "apple.ondevice", displayName: "Apple",
                        providerKind: .appleFoundation, availability: .available,
                        quickSettingsEligible: true)
                ]
            ) { request, _ in
                XCTAssertEqual(request.stage, .final)
                return "Polished"
            }
            let service = AIProcessingService(providers: [provider])

            let outcome = await service.process(
                AIProcessingRequest(
                    text: "draft",
                    stage: .final,
                    locale: Locale(identifier: "en_US"),
                    configuration: AIProcessingConfiguration(
                        enabled: true, selectedModelID: "apple.ondevice",
                        applyDuringLiveInsertion: true, applyToFinalResult: true)
                )
            )

            XCTAssertEqual(outcome, .processed(text: "Polished", modelID: "apple.ondevice"))
        }

        func testLanguageMismatchFallsBackToOriginalText() async {
            let provider = StubProvider(
                providerID: "apple.foundation",
                providerKind: .appleFoundation,
                descriptors: [
                    AIModelDescriptor(
                        id: "apple.ondevice", providerID: "apple.foundation",
                        requestModelID: "apple.ondevice", displayName: "Apple",
                        providerKind: .appleFoundation, availability: .available,
                        quickSettingsEligible: true)
                ]
            ) { _, _ in
                "Wczoraj sie podrozowalem i jutro podrozuje."
            }
            let service = AIProcessingService(providers: [provider])

            let outcome = await service.process(
                AIProcessingRequest(
                    text: "Ich geh morgen klettern.",
                    stage: .final,
                    locale: Locale(identifier: "de_DE"),
                    configuration: AIProcessingConfiguration(
                        enabled: true, selectedModelID: "apple.ondevice",
                        applyDuringLiveInsertion: true, applyToFinalResult: true)
                )
            )

            XCTAssertEqual(outcome.text, "Ich geh morgen klettern.")
            if case .failedFallback(_, let modelID, let reason) = outcome {
                XCTAssertEqual(modelID, "apple.ondevice")
                XCTAssertTrue(reason.contains("dominant language"))
            } else {
                XCTFail("Expected failed fallback outcome.")
            }
        }
    }
#endif
