import Foundation

public struct LicensePayload: Codable, Equatable, Sendable {
    public let productTier: String
    public let issueDate: Date
    public let expiryDate: Date?
    public let featureFlags: [String]

    public init(productTier: String, issueDate: Date, expiryDate: Date?, featureFlags: [String]) {
        self.productTier = productTier
        self.issueDate = issueDate
        self.expiryDate = expiryDate
        self.featureFlags = featureFlags
    }
}

public struct ParsedLicense: Equatable, Sendable {
    public let payloadData: Data
    public let signatureData: Data
    public let payload: LicensePayload

    public init(payloadData: Data, signatureData: Data, payload: LicensePayload) {
        self.payloadData = payloadData
        self.signatureData = signatureData
        self.payload = payload
    }
}

public enum LicenseError: Error, LocalizedError {
    case invalidFormat
    case invalidEncoding
    case invalidPayload
    case invalidSignature
    case expired

    public var errorDescription: String? {
        switch self {
        case .invalidFormat: return "License key format is invalid."
        case .invalidEncoding: return "License key encoding is invalid."
        case .invalidPayload: return "License payload is invalid."
        case .invalidSignature: return "License signature is invalid."
        case .expired: return "License has expired."
        }
    }
}

public enum LicenseStatus: Equatable, Sendable {
    case valid(payload: LicensePayload)
    case invalid(reason: LicenseError)
}

public enum LicenseKeyCodec {
    public static func encode(payloadData: Data, signatureData: Data) -> String {
        let payload = Base32.encode(payloadData)
        let signature = Base32.encode(signatureData)
        return "WISPR1-\(payload)-\(signature)"
    }

    public static func decode(_ key: String) throws -> (payloadData: Data, signatureData: Data) {
        let parts = key.split(separator: "-")
        guard parts.count == 3 else { throw LicenseError.invalidFormat }
        guard parts[0] == "WISPR1" else { throw LicenseError.invalidFormat }

        guard let payloadData = Base32.decode(String(parts[1])),
              let signatureData = Base32.decode(String(parts[2])) else {
            throw LicenseError.invalidEncoding
        }

        return (payloadData, signatureData)
    }
}
