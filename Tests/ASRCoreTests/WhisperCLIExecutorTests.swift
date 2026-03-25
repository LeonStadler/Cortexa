#if canImport(XCTest)
import Foundation
import XCTest
@testable import ASRCore

final class WhisperCLIExecutorTests: XCTestCase {
    func testBuildArgumentsUseBeamSizeFlag() {
        let arguments = WhisperCLIExecutor.buildArguments(
            modelPath: URL(fileURLWithPath: "/tmp/model.bin"),
            inputWav: URL(fileURLWithPath: "/tmp/input.wav"),
            languageHint: "de",
            threads: 4,
            beamSize: 5,
            outputBase: URL(fileURLWithPath: "/tmp/result")
        )

        XCTAssertTrue(arguments.contains("-bs"))
        XCTAssertFalse(arguments.contains("-b"))
        XCTAssertTrue(arguments.contains("de"))
    }
}
#endif
