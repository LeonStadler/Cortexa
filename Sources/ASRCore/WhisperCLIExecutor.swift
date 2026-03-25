import Foundation

enum WhisperCLIExecutor {
    static func resolveCLIPath(explicitPath: URL?, modelPath: URL) -> URL? {
        #if os(macOS)
        if let explicitPath, FileManager.default.isExecutableFile(atPath: explicitPath.path) {
            return explicitPath
        }

        let environment = ProcessInfo.processInfo.environment
        if let envPath = environment["WHISPER_CLI_PATH"], FileManager.default.isExecutableFile(atPath: envPath) {
            return URL(fileURLWithPath: envPath)
        }

        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let installedRuntimeCLI = (try? BundledWhisperRuntimeInstaller.defaultInstallDirectory())?.appendingPathComponent("whisper-cli")
        let bundledRuntimeCLI = BundledWhisperRuntimeInstaller.bundledRuntimeDirectory()?.appendingPathComponent("whisper-cli")

        let candidates: [URL] = [
            cwd.appendingPathComponent("third_party/whisper.cpp/build/bin/whisper-cli"),
            cwd.appendingPathComponent("artifacts/whisper/whisper-cli"),
            URL(fileURLWithPath: "/usr/local/bin/whisper-cli"),
            URL(fileURLWithPath: "/opt/homebrew/bin/whisper-cli"),
            modelPath.deletingLastPathComponent().appendingPathComponent("whisper-cli")
        ] + [installedRuntimeCLI, bundledRuntimeCLI].compactMap { $0 }

        return candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0.path) })
        #else
        _ = explicitPath
        _ = modelPath
        return nil
        #endif
    }

    static func run(
        cliPath: URL,
        modelPath: URL,
        inputWav: URL,
        languageHint: String?,
        threads: Int,
        beamSize: Int,
        outputBase: URL
    ) throws -> URL {
        #if os(macOS)
        let process = Process()
        process.executableURL = cliPath
        process.arguments = buildArguments(
            modelPath: modelPath,
            inputWav: inputWav,
            languageHint: languageHint,
            threads: threads,
            beamSize: beamSize,
            outputBase: outputBase
        )

        let stderrPipe = Pipe()
        process.standardError = stderrPipe
        process.standardOutput = Pipe()

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errorData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let errorText = String(data: errorData, encoding: .utf8) ?? "Unknown whisper-cli error"
            throw NSError(
                domain: "WhisperCLIExecutor",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: "whisper-cli failed: \(errorText)"]
            )
        }

        return outputBase.appendingPathExtension("json")
        #else
        _ = cliPath
        _ = modelPath
        _ = inputWav
        _ = languageHint
        _ = threads
        _ = beamSize
        _ = outputBase
        throw NSError(domain: "WhisperCLIExecutor", code: 9001, userInfo: [NSLocalizedDescriptionKey: "whisper-cli execution is only available on macOS"]) 
        #endif
    }

    static func buildArguments(
        modelPath: URL,
        inputWav: URL,
        languageHint: String?,
        threads: Int,
        beamSize: Int,
        outputBase: URL
    ) -> [String] {
        var arguments: [String] = [
            "-m", modelPath.path,
            "-f", inputWav.path,
            "-oj",
            "-of", outputBase.path,
            "-t", String(max(1, threads)),
            "-bs", String(max(1, beamSize)),
            "-nt"
        ]

        if let languageHint, !languageHint.isEmpty {
            arguments += ["-l", languageHint]
        }

        return arguments
    }
}
