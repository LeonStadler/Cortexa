#if canImport(XCTest)
import Foundation
import XCTest
@testable import LicenseCore

final class Base32Tests: XCTestCase {
    func testEncodeDecodeRoundTrip() {
        let original = Data([0x01, 0x02, 0xFF, 0x10])
        let encoded = Base32.encode(original)
        let decoded = Base32.decode(encoded)

        XCTAssertEqual(decoded, original)
    }

    func testDecodeReturnsNilForInvalidCharacters() {
        XCTAssertNil(Base32.decode("INVALID!"))
    }

    func testEmptyValuesTranslateToEmptyOutputs() {
        XCTAssertEqual(Base32.encode(Data()), "")
        XCTAssertEqual(Base32.decode(""), Data())
    }
}
#endif
