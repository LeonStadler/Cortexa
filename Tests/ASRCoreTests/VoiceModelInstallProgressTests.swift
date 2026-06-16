#if canImport(XCTest)
    import Foundation
    import XCTest
    @testable import ASRCore

    final class VoiceModelInstallProgressTests: XCTestCase {
        func testPercentCompleteClampsFraction() {
            let progress = VoiceModelInstallProgress(phase: .downloading, fractionCompleted: 1.2)
            XCTAssertEqual(progress.percentComplete, 100)
            XCTAssertEqual(progress.fractionCompleted, 1)
        }

        func testOperationKindEquatable() {
            let installing = VoiceModelOperationKind.installing(
                VoiceModelInstallProgress(phase: .downloading, fractionCompleted: 0.5)
            )
            XCTAssertEqual(installing, installing)
            XCTAssertNotEqual(installing, .removing)
        }
    }
#endif
