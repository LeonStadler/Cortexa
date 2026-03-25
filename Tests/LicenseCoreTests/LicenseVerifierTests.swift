#if canImport(XCTest)
import CryptoKit
import Foundation
import XCTest
@testable import LicenseCore

final class LicenseVerifierTests: XCTestCase {
    func testValidSignedKeyAccepted() throws {
        let privateKey = Curve25519.Signing.PrivateKey()
        let publicKeyData = privateKey.publicKey.rawRepresentation

        let payload = LicensePayload(
            productTier: "pro",
            issueDate: Date(timeIntervalSince1970: 1_700_000_000),
            expiryDate: nil,
            featureFlags: ["streaming", "snippets"]
        )

        let payloadData = try LicenseVerifier.encodePayload(payload)
        let signature = try privateKey.signature(for: payloadData)
        let key = LicenseKeyCodec.encode(payloadData: payloadData, signatureData: signature)

        let verifier = try LicenseVerifier(publicKeyRawRepresentation: publicKeyData)
        let status = verifier.verify(key)

        switch status {
        case let .valid(validPayload):
            XCTAssertEqual(validPayload.productTier, "pro")
            XCTAssertTrue(validPayload.featureFlags.contains("streaming"))
        case let .invalid(reason):
            XCTFail("Expected valid license, got \(reason)")
        }
    }

    func testExpiredLicenseRejected() throws {
        let privateKey = Curve25519.Signing.PrivateKey()
        let verifier = try LicenseVerifier(publicKeyRawRepresentation: privateKey.publicKey.rawRepresentation)

        let payload = LicensePayload(
            productTier: "pro",
            issueDate: Date(timeIntervalSince1970: 1_700_000_000),
            expiryDate: Date(timeIntervalSince1970: 1_700_000_100),
            featureFlags: []
        )

        let payloadData = try LicenseVerifier.encodePayload(payload)
        let signature = try privateKey.signature(for: payloadData)
        let key = LicenseKeyCodec.encode(payloadData: payloadData, signatureData: signature)

        let status = verifier.verify(key, now: Date(timeIntervalSince1970: 1_800_000_000))
        XCTAssertEqual(status, .invalid(reason: .expired))
    }

    func testEmbeddedKeysDetectPlaceholderDefaults() {
        XCTAssertTrue(EmbeddedLicenseKeys.isPlaceholderConfigured)
        XCTAssertEqual(EmbeddedLicenseKeys.defaultPublicKeyBase64, EmbeddedLicenseKeys.placeholderPublicKeyBase64)
    }

    func testConvenienceInitializerRejectsInvalidBase64() {
        XCTAssertThrowsError(try LicenseVerifier(defaultEmbeddedKeyBase64: "not-base64")) { error in
            XCTAssertEqual(error as? LicenseError, .invalidPayload)
        }
    }
}
#endif
