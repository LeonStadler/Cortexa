#if canImport(XCTest)
import Foundation
import XCTest
@testable import CapabilityCore

final class CapabilityProfilerTests: XCTestCase {
    func testLowMemoryPrefersSmallerStreamingModel() {
        let profiler = CapabilityProfiler()
        let profile = CapabilityProfile(
            processorCount: 8,
            activeProcessorCount: 8,
            physicalMemoryBytes: 4 * 1024 * 1024 * 1024,
            thermalState: "nominal",
            benchmarkScore: 1_000
        )

        let preset = profiler.streamingPreset(for: profile)
        XCTAssertEqual(preset.modelID, "base-q5")
        XCTAssertEqual(preset.beamSize, 1)
    }

    func testThermalFallbackLowersPressure() {
        let profiler = CapabilityProfiler()
        let profile = CapabilityProfile(
            processorCount: 12,
            activeProcessorCount: 10,
            physicalMemoryBytes: 32 * 1024 * 1024 * 1024,
            thermalState: "critical",
            benchmarkScore: 2_000
        )

        let preset = profiler.fallbackPreset(for: profile)
        XCTAssertEqual(preset.modelID, "base-q5")
        XCTAssertEqual(preset.beamSize, 1)
    }

    func testProfileCachesRepeatedCallsForSameFingerprint() {
        let profiler = CapabilityProfiler()

        let first = profiler.profile()
        let second = profiler.profile()

        XCTAssertEqual(first, second)
    }
}
#endif
