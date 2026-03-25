import Foundation

public enum QualityOverride: String, Codable, Sendable {
    case auto
    case fast
    case balanced
    case accurate
}

public struct CapabilityProfile: Codable, Sendable, Equatable {
    public let processorCount: Int
    public let activeProcessorCount: Int
    public let physicalMemoryBytes: UInt64
    public let thermalState: String
    public let benchmarkScore: Double

    public init(
        processorCount: Int,
        activeProcessorCount: Int,
        physicalMemoryBytes: UInt64,
        thermalState: String,
        benchmarkScore: Double
    ) {
        self.processorCount = processorCount
        self.activeProcessorCount = activeProcessorCount
        self.physicalMemoryBytes = physicalMemoryBytes
        self.thermalState = thermalState
        self.benchmarkScore = benchmarkScore
    }
}

public struct EnginePreset: Codable, Sendable, Equatable {
    public let modelID: String
    public let threadCount: Int
    public let beamSize: Int
    public let chunkMilliseconds: Int

    public init(modelID: String, threadCount: Int, beamSize: Int, chunkMilliseconds: Int) {
        self.modelID = modelID
        self.threadCount = threadCount
        self.beamSize = beamSize
        self.chunkMilliseconds = chunkMilliseconds
    }
}

public final class CapabilityProfiler {
    public init() {}

    public func profile() -> CapabilityProfile {
        let processInfo = ProcessInfo.processInfo
        let score = runQuickBenchmark()

        return CapabilityProfile(
            processorCount: processInfo.processorCount,
            activeProcessorCount: processInfo.activeProcessorCount,
            physicalMemoryBytes: processInfo.physicalMemory,
            thermalState: thermalStateLabel(processInfo.thermalState),
            benchmarkScore: score
        )
    }

    public func streamingPreset(for profile: CapabilityProfile, override: QualityOverride = .auto) -> EnginePreset {
        if override == .fast {
            return EnginePreset(modelID: "base-q5", threadCount: max(2, profile.activeProcessorCount / 2), beamSize: 1, chunkMilliseconds: 240)
        }
        if override == .balanced {
            return EnginePreset(modelID: "small-q8", threadCount: max(2, profile.activeProcessorCount - 1), beamSize: 3, chunkMilliseconds: 360)
        }
        if override == .accurate {
            return EnginePreset(modelID: "small-q8", threadCount: max(2, profile.activeProcessorCount - 1), beamSize: 5, chunkMilliseconds: 420)
        }

        if profile.physicalMemoryBytes < 8 * 1024 * 1024 * 1024 {
            return EnginePreset(modelID: "base-q5", threadCount: max(2, profile.activeProcessorCount / 2), beamSize: 1, chunkMilliseconds: 220)
        }

        return EnginePreset(modelID: "small-q8", threadCount: max(2, profile.activeProcessorCount - 1), beamSize: 2, chunkMilliseconds: 280)
    }

    public func qualityPreset(for profile: CapabilityProfile, override: QualityOverride = .auto) -> EnginePreset {
        if override == .fast {
            return EnginePreset(modelID: "base-q5", threadCount: max(2, profile.activeProcessorCount / 2), beamSize: 2, chunkMilliseconds: 450)
        }
        if override == .balanced {
            return EnginePreset(modelID: "small-q8", threadCount: max(2, profile.activeProcessorCount - 1), beamSize: 4, chunkMilliseconds: 560)
        }
        if override == .accurate {
            return EnginePreset(modelID: "medium-q8", threadCount: max(2, profile.activeProcessorCount - 1), beamSize: 6, chunkMilliseconds: 650)
        }

        if profile.physicalMemoryBytes >= 16 * 1024 * 1024 * 1024, profile.thermalState != "serious", profile.thermalState != "critical" {
            return EnginePreset(modelID: "medium-q8", threadCount: max(2, profile.activeProcessorCount - 1), beamSize: 5, chunkMilliseconds: 600)
        }

        return EnginePreset(modelID: "small-q8", threadCount: max(2, profile.activeProcessorCount / 2), beamSize: 3, chunkMilliseconds: 500)
    }

    public func fallbackPreset(for profile: CapabilityProfile) -> EnginePreset {
        if profile.thermalState == "critical" || profile.thermalState == "serious" {
            return EnginePreset(modelID: "base-q5", threadCount: max(1, profile.activeProcessorCount / 3), beamSize: 1, chunkMilliseconds: 220)
        }
        return streamingPreset(for: profile)
    }

    private func runQuickBenchmark(iterations: Int = 100_000) -> Double {
        let start = CFAbsoluteTimeGetCurrent()
        var total = 0.0
        for value in 1...iterations {
            total += sqrt(Double(value))
        }
        _ = total
        let elapsed = max(0.001, CFAbsoluteTimeGetCurrent() - start)
        return Double(iterations) / elapsed
    }

    private func thermalStateLabel(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: return "nominal"
        case .fair: return "fair"
        case .serious: return "serious"
        case .critical: return "critical"
        @unknown default: return "unknown"
        }
    }
}
