#if canImport(XCTest)
import Foundation
import XCTest
@testable import ASRCore

final class WhisperSupportTests: XCTestCase {
    func testWAVWriterProducesRIFFHeader() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("wav_writer_test_\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: tmp) }

        try WAVWriter.writePCMFloat32Mono16k([0.0, 0.5, -0.5, 1.0], to: tmp)
        let data = try Data(contentsOf: tmp)

        XCTAssertGreaterThanOrEqual(data.count, 44)
        XCTAssertEqual(String(data: data.prefix(4), encoding: .ascii), "RIFF")
        XCTAssertEqual(String(data: data.subdata(in: 8..<12), encoding: .ascii), "WAVE")
    }

    func testWhisperJSONParserParsesSegments() throws {
        let json = """
        {
          \"result\": { \"language\": \"de\" },
          \"transcription\": [
            {
              \"text\": \"Hallo\",
              \"offsets\": { \"from\": 0, \"to\": 1000 }
            },
            {
              \"text\": \"Welt\",
              \"offsets\": { \"from\": 1000, \"to\": 2000 }
            }
          ]
        }
        """

        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("whisper_json_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tmp) }

        try Data(json.utf8).write(to: tmp)
        let parsed = try WhisperCLIParser.parseResult(at: tmp)

        XCTAssertEqual(parsed.language, "de")
        XCTAssertEqual(parsed.text, "Hallo Welt")
        XCTAssertEqual(parsed.segments.count, 2)
        XCTAssertEqual(parsed.segments[0].startTime, 0.0, accuracy: 0.001)
        XCTAssertEqual(parsed.segments[0].endTime, 1.0, accuracy: 0.001)
    }
}
#endif
