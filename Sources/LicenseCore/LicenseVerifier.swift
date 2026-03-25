import CryptoKit
import Foundation

public struct EmbeddedLicenseKeys {
    // Replace with production Ed25519 public key before shipping.
    public static let defaultPublicKeyBase64 = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
    public static let placeholderPublicKeyBase64 = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
    public static var isPlaceholderConfigured: Bool {
        defaultPublicKeyBase64 == placeholderPublicKeyBase64
    }
}

public final class LicenseVerifier {
    private let publicKey: Curve25519.Signing.PublicKey
    private let decoder: JSONDecoder

    public init(publicKeyRawRepresentation: Data) throws {
        self.publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: publicKeyRawRepresentation)
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    public convenience init(defaultEmbeddedKeyBase64: String = EmbeddedLicenseKeys.defaultPublicKeyBase64) throws {
        guard let data = Data(base64Encoded: defaultEmbeddedKeyBase64) else {
            throw LicenseError.invalidPayload
        }
        try self.init(publicKeyRawRepresentation: data)
    }

    public func parse(_ licenseKey: String) throws -> ParsedLicense {
        let decoded = try LicenseKeyCodec.decode(licenseKey)
        let payload = try decoder.decode(LicensePayload.self, from: decoded.payloadData)
        return ParsedLicense(payloadData: decoded.payloadData, signatureData: decoded.signatureData, payload: payload)
    }

    public func verify(_ licenseKey: String, now: Date = Date()) -> LicenseStatus {
        do {
            let parsed = try parse(licenseKey)
            guard publicKey.isValidSignature(parsed.signatureData, for: parsed.payloadData) else {
                return .invalid(reason: .invalidSignature)
            }

            if let expiry = parsed.payload.expiryDate, expiry < now {
                return .invalid(reason: .expired)
            }

            return .valid(payload: parsed.payload)
        } catch let error as LicenseError {
            return .invalid(reason: error)
        } catch {
            return .invalid(reason: .invalidPayload)
        }
    }

    public static func encodePayload(_ payload: LicensePayload) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(payload)
    }
}
