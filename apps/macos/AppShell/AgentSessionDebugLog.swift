import Foundation

// #region agent log
/// Temporäre NDJSON-Zeilen für Debug-Session `9ba0d5` (Textfeld-Fokus / AX).
enum AgentSessionDebugLog {
    private static let sessionId = "9ba0d5"
    private static let logURL: URL = {
        let fileManager = FileManager.default
        let baseDirectory =
            fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return baseDirectory
            .appendingPathComponent("WisprLocal", isDirectory: true)
            .appendingPathComponent("debug-\(sessionId).log", isDirectory: false)
    }()

    static func append(
        hypothesisId: String,
        location: String,
        message: String,
        data: [String: String] = [:],
        runId: String = "pre-fix"
    ) {
        let payload: [String: Any] = [
            "sessionId": sessionId,
            "timestamp": Int(Date().timeIntervalSince1970 * 1000),
            "hypothesisId": hypothesisId,
            "location": location,
            "message": message,
            "data": data,
            "runId": runId,
        ]
        guard JSONSerialization.isValidJSONObject(payload),
            let json = try? JSONSerialization.data(withJSONObject: payload),
            var line = String(data: json, encoding: .utf8)
        else { return }
        line += "\n"
        let fileManager = FileManager.default
        let directoryURL = logURL.deletingLastPathComponent()
        try? fileManager.createDirectory(
            at: directoryURL, withIntermediateDirectories: true)
        if !fileManager.fileExists(atPath: logURL.path) {
            fileManager.createFile(atPath: logURL.path, contents: nil)
        }
        guard let handle = try? FileHandle(forWritingTo: logURL) else { return }
        defer { try? handle.close() }
        do {
            try handle.seekToEnd()
            try handle.write(contentsOf: Data(line.utf8))
        } catch {}
    }
}
// #endregion
