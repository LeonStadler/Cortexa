#if canImport(XCTest)
import XCTest
@testable import AudioCore

final class AudioPreprocessorTests: XCTestCase {
    func testSilenceRemovalSuppressesQuietBuffers() {
        var preprocessor = AudioPreprocessor()

        let result = preprocessor.process(
            Array(repeating: 0.0005, count: 128),
            configuration: AudioProcessingConfiguration(
                inputLevelCompensationEnabled: false,
                silenceRemovalEnabled: true,
                dynamicNormalizationEnabled: false
            )
        )

        XCTAssertNotNil(result)
        XCTAssertTrue(result?.wasSilenceSuppressed ?? false)
        XCTAssertEqual(result?.samples, [])
    }

    func testInputLevelCompensationBoostsLowAmplitudeSamples() {
        var preprocessor = AudioPreprocessor()

        let result = preprocessor.process(
            [0.1, -0.1, 0.05, -0.05],
            configuration: AudioProcessingConfiguration(
                inputLevelCompensationEnabled: true,
                silenceRemovalEnabled: false,
                dynamicNormalizationEnabled: false
            )
        )

        XCTAssertNotNil(result)
        XCTAssertGreaterThan(result?.samples.first ?? 0, 0.1)
        XCTAssertGreaterThan(result?.appliedGain ?? 0, 1)
    }

    func testDynamicNormalizationAppliesStableGainAcrossBuffers() {
        var preprocessor = AudioPreprocessor()
        let configuration = AudioProcessingConfiguration(
            inputLevelCompensationEnabled: false,
            silenceRemovalEnabled: false,
            dynamicNormalizationEnabled: true
        )

        let first = preprocessor.process(Array(repeating: 0.01, count: 64), configuration: configuration)
        let second = preprocessor.process(Array(repeating: 0.01, count: 64), configuration: configuration)

        XCTAssertNotNil(first)
        XCTAssertNotNil(second)
        XCTAssertGreaterThan(first?.appliedGain ?? 0, 1)
        XCTAssertGreaterThan(second?.appliedGain ?? 0, first?.appliedGain ?? 0)
    }
}
#endif
