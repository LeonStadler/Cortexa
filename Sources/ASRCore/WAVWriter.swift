import Foundation

enum WAVWriter {
    static func writePCMFloat32Mono16k(_ samples: [Float], to url: URL, sampleRate: Int = 16_000) throws {
        let clamped = samples.map { sample -> Int16 in
            let scaled = max(-1.0, min(1.0, sample)) * Float(Int16.max)
            return Int16(scaled)
        }

        var data = Data(capacity: 44 + clamped.count * MemoryLayout<Int16>.size)

        // RIFF header
        data.append("RIFF".data(using: .ascii)!)
        let fileSizeMinus8 = UInt32(36 + clamped.count * MemoryLayout<Int16>.size)
        data.append(fileSizeMinus8.littleEndianData)
        data.append("WAVE".data(using: .ascii)!)

        // fmt chunk
        data.append("fmt ".data(using: .ascii)!)
        data.append(UInt32(16).littleEndianData) // PCM chunk size
        data.append(UInt16(1).littleEndianData) // PCM
        data.append(UInt16(1).littleEndianData) // mono
        data.append(UInt32(sampleRate).littleEndianData)
        let byteRate = UInt32(sampleRate * 2)
        data.append(byteRate.littleEndianData)
        data.append(UInt16(2).littleEndianData) // block align
        data.append(UInt16(16).littleEndianData) // bits per sample

        // data chunk
        data.append("data".data(using: .ascii)!)
        data.append(UInt32(clamped.count * 2).littleEndianData)

        for sample in clamped {
            data.append(sample.littleEndianData)
        }

        try data.write(to: url, options: [.atomic])
    }
}

private extension FixedWidthInteger {
    var littleEndianData: Data {
        var value = self.littleEndian
        return Data(bytes: &value, count: MemoryLayout<Self>.size)
    }
}
