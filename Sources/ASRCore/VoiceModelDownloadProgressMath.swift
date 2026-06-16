import Foundation

enum VoiceModelDownloadProgressMath {
    struct Result: Equatable {
        let fractionCompleted: Double
        let totalBytes: Int64?
        let isIndeterminate: Bool
    }

    static func computeProgress(
        receivedBytes: Int64,
        httpTotalBytes: Int64,
        fallbackTotalBytes: Int64?,
        previousFraction: Double
    ) -> Result {
        let resolvedTotal: Int64?
        if httpTotalBytes > 0 {
            resolvedTotal = httpTotalBytes
        } else if let fallbackTotalBytes, fallbackTotalBytes > 0 {
            resolvedTotal = fallbackTotalBytes
        } else {
            resolvedTotal = nil
        }

        guard let resolvedTotal, resolvedTotal > 0 else {
            return Result(
                fractionCompleted: max(previousFraction, 0),
                totalBytes: nil,
                isIndeterminate: true
            )
        }

        let rawFraction = min(Double(receivedBytes) / Double(resolvedTotal), 0.95)
        let fractionCompleted = max(previousFraction, rawFraction)
        return Result(
            fractionCompleted: fractionCompleted,
            totalBytes: resolvedTotal,
            isIndeterminate: false
        )
    }
}
