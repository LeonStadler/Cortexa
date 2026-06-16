#if canImport(XCTest)
import Foundation
import XCTest
@testable import ASRCore

final class VoiceModelDownloadProgressMathTests: XCTestCase {
    func testIndeterminateWhenNoTotalKnown() {
        let result = VoiceModelDownloadProgressMath.computeProgress(
            receivedBytes: 1_000_000,
            httpTotalBytes: 0,
            fallbackTotalBytes: nil,
            previousFraction: 0
        )

        XCTAssertTrue(result.isIndeterminate)
        XCTAssertNil(result.totalBytes)
        XCTAssertEqual(result.fractionCompleted, 0)
    }

    func testUsesCatalogFallbackUntilHttpTotalKnown() {
        let result = VoiceModelDownloadProgressMath.computeProgress(
            receivedBytes: 50_000_000,
            httpTotalBytes: 0,
            fallbackTotalBytes: LocalVoiceModelCatalog.proModelExpectedBytes,
            previousFraction: 0
        )

        XCTAssertFalse(result.isIndeterminate)
        XCTAssertEqual(result.totalBytes, LocalVoiceModelCatalog.proModelExpectedBytes)
        XCTAssertGreaterThan(result.fractionCompleted, 0)
    }

    func testProgressIsMonotonicWhenHttpTotalArrivesLater() {
        let fallback = VoiceModelDownloadProgressMath.computeProgress(
            receivedBytes: 200_000_000,
            httpTotalBytes: 0,
            fallbackTotalBytes: 500_000_000,
            previousFraction: 0
        )
        let corrected = VoiceModelDownloadProgressMath.computeProgress(
            receivedBytes: 200_000_000,
            httpTotalBytes: 400_000_000,
            fallbackTotalBytes: 500_000_000,
            previousFraction: fallback.fractionCompleted
        )

        XCTAssertGreaterThanOrEqual(
            corrected.fractionCompleted,
            fallback.fractionCompleted
        )
    }
}
#endif
