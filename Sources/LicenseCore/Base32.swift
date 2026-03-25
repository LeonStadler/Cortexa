import Foundation

public enum Base32 {
    private static let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")
    private static let decodeMap: [Character: UInt8] = {
        var map: [Character: UInt8] = [:]
        for (index, char) in alphabet.enumerated() {
            map[char] = UInt8(index)
        }
        return map
    }()

    public static func encode(_ data: Data) -> String {
        guard !data.isEmpty else { return "" }

        var result = ""
        var buffer: UInt16 = 0
        var bitsLeft: UInt8 = 0

        for byte in data {
            buffer = (buffer << 8) | UInt16(byte)
            bitsLeft += 8

            while bitsLeft >= 5 {
                let index = Int((buffer >> (bitsLeft - 5)) & 0x1F)
                result.append(alphabet[index])
                bitsLeft -= 5
            }
        }

        if bitsLeft > 0 {
            let index = Int((buffer << (5 - bitsLeft)) & 0x1F)
            result.append(alphabet[index])
        }

        return result
    }

    public static func decode(_ input: String) -> Data? {
        let cleaned = input.uppercased().filter { $0 != "=" && !$0.isWhitespace }
        guard !cleaned.isEmpty else { return Data() }

        var buffer: UInt32 = 0
        var bitsLeft: UInt8 = 0
        var output = Data()

        for character in cleaned {
            guard let value = decodeMap[character] else { return nil }

            buffer = (buffer << 5) | UInt32(value)
            bitsLeft += 5

            if bitsLeft >= 8 {
                let byte = UInt8((buffer >> (bitsLeft - 8)) & 0xFF)
                output.append(byte)
                bitsLeft -= 8
            }
        }

        return output
    }
}
