import Foundation

enum WhisperCLIParser {
    static func parseResult(at jsonURL: URL) throws -> FinalTranscript {
        let data = try Data(contentsOf: jsonURL)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "WhisperCLIParser", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON root"]) 
        }

        let language = ((root["result"] as? [String: Any])?["language"] as? String)
        let rawSegments = (root["transcription"] as? [[String: Any]]) ?? (root["segments"] as? [[String: Any]]) ?? []

        let segments: [FinalSegment] = rawSegments.compactMap { segment in
            let text = (segment["text"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if text.isEmpty { return nil }

            let timesFromOffsets = parseTimesFromOffsets(segment)
            let timesFromTimestamps = parseTimesFromTimestamps(segment)
            let times = timesFromOffsets ?? timesFromTimestamps ?? (0.0, 0.0)

            return FinalSegment(text: text, startTime: times.0, endTime: times.1)
        }

        let combinedText = segments.map(\.text).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return FinalTranscript(text: combinedText, segments: segments, language: language)
    }

    private static func parseTimesFromOffsets(_ segment: [String: Any]) -> (TimeInterval, TimeInterval)? {
        guard let offsets = segment["offsets"] as? [String: Any] else { return nil }
        guard let fromMS = offsets["from"] as? NSNumber,
              let toMS = offsets["to"] as? NSNumber else {
            return nil
        }

        return (fromMS.doubleValue / 1000.0, toMS.doubleValue / 1000.0)
    }

    private static func parseTimesFromTimestamps(_ segment: [String: Any]) -> (TimeInterval, TimeInterval)? {
        guard let timestamps = segment["timestamps"] as? [String: Any] else { return nil }
        guard let from = timestamps["from"] as? String,
              let to = timestamps["to"] as? String else {
            return nil
        }

        guard let start = parseClockTimestamp(from),
              let end = parseClockTimestamp(to) else {
            return nil
        }

        return (start, end)
    }

    private static func parseClockTimestamp(_ raw: String) -> TimeInterval? {
        let parts = raw.split(separator: ":")
        guard parts.count == 3 else { return nil }

        guard let hours = Double(parts[0]),
              let minutes = Double(parts[1]) else {
            return nil
        }

        let secParts = parts[2].split(separator: ".")
        guard let seconds = Double(secParts[0]) else { return nil }
        let millis = secParts.count > 1 ? (Double(secParts[1]) ?? 0.0) : 0.0

        return hours * 3600 + minutes * 60 + seconds + millis / 1000.0
    }
}
