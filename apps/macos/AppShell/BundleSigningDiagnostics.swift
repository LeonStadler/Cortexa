import Foundation

enum BundleSigningDiagnostics {
    static func logStartupIdentityIfDebug(bundle: Bundle = .main) {
        #if DEBUG
        DispatchQueue.global(qos: .utility).async {
            let snapshot = capture(bundle: bundle)
            AgentSessionDebugLog.append(
                hypothesisId: "build-identity",
                location: "BundleSigningDiagnostics.logStartupIdentityIfDebug",
                message: snapshot.message,
                data: snapshot.logData,
                runId: snapshot.bundleIdentifier
            )
        }
        #endif
    }

    private static func capture(bundle: Bundle) -> Snapshot {
        let bundleURL = bundle.bundleURL
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["-dvvv", "-r-", bundleURL.path]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        let output: String
        let exitStatus: Int32
        do {
            try process.run()
            output = String(
                data: pipe.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8
            ) ?? ""
            process.waitUntilExit()
            exitStatus = process.terminationStatus
        } catch {
            return Snapshot(
                bundleIdentifier: bundle.bundleIdentifier ?? "unknown",
                bundleVersion: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
                bundleURL: bundleURL.path,
                executableURL: bundle.executableURL?.path,
                codesignExitStatus: -1,
                codesignIdentifier: nil,
                teamIdentifier: nil,
                designatedRequirement: nil
            )
        }

        let lines = output.split(whereSeparator: \.isNewline).map(String.init)
        return Snapshot(
            bundleIdentifier: bundle.bundleIdentifier ?? "unknown",
            bundleVersion: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
            bundleURL: bundleURL.path,
            executableURL: bundle.executableURL?.path,
            codesignExitStatus: exitStatus,
            codesignIdentifier: Self.firstValue(
                from: lines, prefix: "Identifier="),
            teamIdentifier: Self.firstValue(
                from: lines, prefix: "TeamIdentifier="),
            designatedRequirement: Self.designatedRequirement(from: lines)
        )
    }

    private static func firstValue(from lines: [String], prefix: String) -> String? {
        lines.first(where: { $0.hasPrefix(prefix) })?
            .dropFirst(prefix.count)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
    }

    private static func designatedRequirement(from lines: [String]) -> String? {
        var captured: [String] = []
        var isCapturing = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed.hasPrefix("designated =>") {
                isCapturing = true
                let requirement = trimmed
                    .dropFirst("designated =>".count)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !requirement.isEmpty {
                    captured.append(requirement)
                }
                continue
            }

            if trimmed.hasPrefix("Designated Requirement:") {
                isCapturing = true
                continue
            }

            guard isCapturing else { continue }

            if line.hasPrefix(" ") || line.hasPrefix("\t") {
                if !trimmed.isEmpty {
                    captured.append(trimmed)
                }
                continue
            }

            break
        }

        return captured.isEmpty ? nil : captured.joined(separator: " ")
    }

    private struct Snapshot {
        let bundleIdentifier: String
        let bundleVersion: String?
        let bundleURL: String
        let executableURL: String?
        let codesignExitStatus: Int32
        let codesignIdentifier: String?
        let teamIdentifier: String?
        let designatedRequirement: String?

        var message: String {
            if codesignExitStatus == 0 {
                return "Captured bundle signing identity"
            }
            return "Captured bundle signing identity with codesign status \(codesignExitStatus)"
        }

        var logData: [String: String] {
            var data: [String: String] = [
                "bundleIdentifier": bundleIdentifier,
                "bundleURL": bundleURL,
                "codesignExitStatus": String(codesignExitStatus),
            ]
            if let bundleVersion {
                data["bundleVersion"] = bundleVersion
            }
            if let executableURL {
                data["executableURL"] = executableURL
            }
            if let codesignIdentifier {
                data["codesignIdentifier"] = codesignIdentifier
            }
            if let teamIdentifier {
                data["teamIdentifier"] = teamIdentifier
            }
            if let designatedRequirement {
                data["designatedRequirement"] = designatedRequirement
            }
            return data
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
