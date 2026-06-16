#if canImport(XCTest)
import Foundation
import XCTest
@testable import ASRCore

final class VoiceModelSuppressionStoreTests: XCTestCase {
    func testSuppressAndClearRoundTrip() {
        let defaults = UserDefaults(suiteName: "VoiceModelSuppressionStoreTests.\(UUID().uuidString)")!
        let store = VoiceModelSuppressionStore(defaults: defaults)

        XCTAssertTrue(store.suppressedFileNames().isEmpty)

        store.suppress("ggml-small.bin")
        XCTAssertEqual(store.suppressedFileNames(), ["ggml-small.bin"])

        store.clearSuppression(for: "ggml-small.bin")
        XCTAssertTrue(store.suppressedFileNames().isEmpty)
    }
}
#endif
