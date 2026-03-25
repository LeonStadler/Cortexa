#if canImport(XCTest)
import Foundation
import XCTest
@testable import LicenseCore

final class LicenseKeyCodecTests: XCTestCase {
    func testEncodeDecodeRoundTrip() throws {
        let payload = Data("payload".utf8)
        let signature = Data([0xDE, 0xAD, 0xBE, 0xEF])

        let encoded = LicenseKeyCodec.encode(payloadData: payload, signatureData: signature)
        let decoded = try LicenseKeyCodec.decode(encoded)

        XCTAssertEqual(decoded.payloadData, payload)
        XCTAssertEqual(decoded.signatureData, signature)
    }

    func testDecodeThrowsForInvalidFormat() {
        XCTAssertThrowsError(try LicenseKeyCodec.decode("WISPR1-SOMETHING")) { error in
            XCTAssertEqual(error as? LicenseError, .invalidFormat)
        }
    }
}
#endif
