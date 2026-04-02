#if canImport(XCTest)
import Foundation
import XCTest
@testable import AIProcessingCore

private struct StubProvider: AITextProcessingProviding {
    let providerKind: AIProviderKind
    let descriptors: [AIModelDescriptor]
    let handler: @Sendable (AIProcessingRequest, AIModelDescriptor) async throws -> String

    func models() -> [AIModelDescriptor] {
        descriptors
    }

    func process(_ request: AIProcessingRequest, model: AIModelDescriptor) async throws -> String {
        try await handler(request, model)
    }
}

final class AIProcessingServiceTests: XCTestCase {
    func testQuickSettingsFilterReturnsOnlyAvailableOperationalModels() {
        let catalog = AIModelCatalog(descriptors: [
            AIModelDescriptor(id: "a", displayName: "A", providerKind: .appleFoundation, availability: .available, quickSettingsEligible: true),
            AIModelDescriptor(id: "b", displayName: "B", providerKind: .remoteAPI, availability: .unavailable(reason: "Missing key"), quickSettingsEligible: true),
            AIModelDescriptor(id: "c", displayName: "C", providerKind: .localDownloaded, availability: .available, quickSettingsEligible: false)
        ])

        XCTAssertEqual(catalog.quickSettingsModels.map(\.id), ["a"])
    }

    func testDisabledConfigurationBypassesProviderCall() async {
        let provider = StubProvider(
            providerKind: .appleFoundation,
            descriptors: [AIModelDescriptor(id: "apple.ondevice", displayName: "Apple", providerKind: .appleFoundation, availability: .available, quickSettingsEligible: true)]
        ) { _, _ in
            XCTFail("Provider should not be called when AI processing is disabled.")
            return ""
        }
        let service = AIProcessingService(providers: [.appleFoundation: provider])

        let outcome = await service.process(
            AIProcessingRequest(
                text: "Hallo Welt",
                stage: .final,
                locale: Locale(identifier: "de_DE"),
                configuration: AIProcessingConfiguration(enabled: false, selectedModelID: "apple.ondevice")
            )
        )

        XCTAssertEqual(outcome.text, "Hallo Welt")
        if case let .bypassed(_, reason) = outcome {
            XCTAssertTrue(reason.contains("disabled"))
        } else {
            XCTFail("Expected bypassed outcome.")
        }
    }

    func testFinalOnlyScopeSkipsLiveProcessing() async {
        let provider = StubProvider(
            providerKind: .appleFoundation,
            descriptors: [AIModelDescriptor(id: "apple.ondevice", displayName: "Apple", providerKind: .appleFoundation, availability: .available, quickSettingsEligible: true)]
        ) { _, _ in
            XCTFail("Provider should not be called for live processing when scope is finalOnly.")
            return ""
        }
        let service = AIProcessingService(providers: [.appleFoundation: provider])

        let outcome = await service.process(
            AIProcessingRequest(
                text: "draft",
                stage: .live,
                locale: Locale(identifier: "en_US"),
                configuration: AIProcessingConfiguration(enabled: true, selectedModelID: "apple.ondevice", scope: .finalOnly)
            )
        )

        XCTAssertEqual(outcome.text, "draft")
    }

    func testProviderFailureFallsBackToOriginalText() async {
        let provider = StubProvider(
            providerKind: .appleFoundation,
            descriptors: [AIModelDescriptor(id: "apple.ondevice", displayName: "Apple", providerKind: .appleFoundation, availability: .available, quickSettingsEligible: true)]
        ) { _, _ in
            struct DummyError: LocalizedError {
                var errorDescription: String? { "boom" }
            }
            throw DummyError()
        }
        let service = AIProcessingService(providers: [.appleFoundation: provider])

        let outcome = await service.process(
            AIProcessingRequest(
                text: "raw text",
                stage: .final,
                locale: Locale(identifier: "en_US"),
                configuration: AIProcessingConfiguration(enabled: true, selectedModelID: "apple.ondevice", scope: .liveAndFinal)
            )
        )

        XCTAssertEqual(outcome.text, "raw text")
        if case let .failedFallback(_, modelID, reason) = outcome {
            XCTAssertEqual(modelID, "apple.ondevice")
            XCTAssertTrue(reason.contains("boom"))
        } else {
            XCTFail("Expected failed fallback outcome.")
        }
    }

    func testSuccessfulProcessingReturnsProcessedText() async {
        let provider = StubProvider(
            providerKind: .appleFoundation,
            descriptors: [AIModelDescriptor(id: "apple.ondevice", displayName: "Apple", providerKind: .appleFoundation, availability: .available, quickSettingsEligible: true)]
        ) { request, _ in
            XCTAssertEqual(request.stage, .final)
            return "Polished"
        }
        let service = AIProcessingService(providers: [.appleFoundation: provider])

        let outcome = await service.process(
            AIProcessingRequest(
                text: "draft",
                stage: .final,
                locale: Locale(identifier: "en_US"),
                configuration: AIProcessingConfiguration(enabled: true, selectedModelID: "apple.ondevice", scope: .liveAndFinal)
            )
        )

        XCTAssertEqual(outcome, .processed(text: "Polished", modelID: "apple.ondevice"))
    }
}
#endif
