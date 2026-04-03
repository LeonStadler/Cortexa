import Foundation

public struct AudioProcessingConfiguration: Codable, Equatable, Sendable {
    public var inputLevelCompensationEnabled: Bool
    public var silenceRemovalEnabled: Bool
    public var dynamicNormalizationEnabled: Bool

    public init(
        inputLevelCompensationEnabled: Bool = false,
        silenceRemovalEnabled: Bool = false,
        dynamicNormalizationEnabled: Bool = false
    ) {
        self.inputLevelCompensationEnabled = inputLevelCompensationEnabled
        self.silenceRemovalEnabled = silenceRemovalEnabled
        self.dynamicNormalizationEnabled = dynamicNormalizationEnabled
    }
}

public struct AudioProcessingResult: Equatable, Sendable {
    public let samples: [Float]
    public let rms: Float
    public let peak: Float
    public let appliedGain: Float
    public let wasSilenceSuppressed: Bool

    public init(
        samples: [Float],
        rms: Float,
        peak: Float,
        appliedGain: Float,
        wasSilenceSuppressed: Bool
    ) {
        self.samples = samples
        self.rms = rms
        self.peak = peak
        self.appliedGain = appliedGain
        self.wasSilenceSuppressed = wasSilenceSuppressed
    }
}

public struct AudioPreprocessor: Sendable {
    private var normalizationGain: Float = 1

    public init() {}

    public mutating func reset() {
        normalizationGain = 1
    }

    public mutating func process(
        _ samples: [Float],
        configuration: AudioProcessingConfiguration
    ) -> AudioProcessingResult? {
        guard !samples.isEmpty else {
            return nil
        }

        let (rms, peak) = Self.measure(samples)
        if configuration.silenceRemovalEnabled,
           Self.shouldSuppressSilence(rms: rms, peak: peak) {
            normalizationGain = max(1, normalizationGain * 0.92)
            return AudioProcessingResult(
                samples: [],
                rms: rms,
                peak: peak,
                appliedGain: 0,
                wasSilenceSuppressed: true
            )
        }

        var appliedGain: Float = 1

        if configuration.inputLevelCompensationEnabled {
            appliedGain *= 1.25
        }

        if configuration.dynamicNormalizationEnabled {
            let desiredGain = Self.desiredNormalizationGain(for: rms)
            normalizationGain = Self.smoothedGain(previous: normalizationGain, target: desiredGain)
            appliedGain *= normalizationGain
        } else {
            normalizationGain = 1
        }

        let processed = samples.map { Self.clamp($0 * appliedGain, lower: -0.95, upper: 0.95) }
        return AudioProcessingResult(
            samples: processed,
            rms: rms,
            peak: peak,
            appliedGain: appliedGain,
            wasSilenceSuppressed: false
        )
    }

    private static func measure(_ samples: [Float]) -> (rms: Float, peak: Float) {
        var sumSquares: Float = 0
        var peak: Float = 0

        for sample in samples {
            let absolute = abs(sample)
            peak = max(peak, absolute)
            sumSquares += sample * sample
        }

        let rms = sqrt(sumSquares / Float(samples.count))
        return (rms, peak)
    }

    private static func shouldSuppressSilence(rms: Float, peak: Float) -> Bool {
        rms < 0.0035 && peak < 0.012
    }

    private static func desiredNormalizationGain(for rms: Float) -> Float {
        guard rms > 0.0001 else {
            return 1
        }

        let targetRMS: Float = 0.07
        return clamp(targetRMS / rms, lower: 0.85, upper: 3.25)
    }

    private static func smoothedGain(previous: Float, target: Float) -> Float {
        clamp(previous * 0.7 + target * 0.3, lower: 0.8, upper: 3.5)
    }

    private static func clamp(_ value: Float, lower: Float, upper: Float) -> Float {
        min(max(value, lower), upper)
    }
}
