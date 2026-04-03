import Foundation
#if os(macOS)
import Darwin
#endif

enum WhisperCLIExecutor {
    static func resolveCLIPath(explicitPath: URL?, modelPath: URL) -> URL? {
        #if os(macOS)
        if let explicitPath, FileManager.default.isExecutableFile(atPath: explicitPath.path) {
            return explicitPath
        }

        let installedRuntimeCLI = (try? BundledWhisperRuntimeInstaller.defaultInstallDirectory())?.appendingPathComponent("whisper-cli")
        let bundledRuntimeCLI = BundledWhisperRuntimeInstaller.bundledRuntimeDirectory()?.appendingPathComponent("whisper-cli")
        var candidates: [URL] = [installedRuntimeCLI, bundledRuntimeCLI].compactMap { $0 }

        #if DEBUG
        let environment = ProcessInfo.processInfo.environment
        if let envPath = environment["WHISPER_CLI_PATH"], FileManager.default.isExecutableFile(atPath: envPath) {
            return URL(fileURLWithPath: envPath)
        }

        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        candidates.insert(contentsOf: [
            cwd.appendingPathComponent("third_party/whisper.cpp/build/bin/whisper-cli"),
            cwd.appendingPathComponent("artifacts/whisper/whisper-cli"),
            URL(fileURLWithPath: "/usr/local/bin/whisper-cli"),
            URL(fileURLWithPath: "/opt/homebrew/bin/whisper-cli"),
            modelPath.deletingLastPathComponent().appendingPathComponent("whisper-cli")
        ], at: 0)
        #endif

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
        translationMode: ASRTranslationMode,
        threads: Int,
        beamSize: Int,
        outputBase: URL,
        timeout: TimeInterval = 90,
        debugLog: ((String) -> Void)? = nil
    ) throws -> URL {
        #if os(macOS)
        let process = Process()
        process.executableURL = cliPath
        process.arguments = buildArguments(
            modelPath: modelPath,
            inputWav: inputWav,
            languageHint: languageHint,
            translationMode: translationMode,
            threads: threads,
            beamSize: beamSize,
            outputBase: outputBase
        )

        let stderrPipe = Pipe()
        let stdoutPipe = Pipe()
        process.standardError = stderrPipe
        process.standardOutput = stdoutPipe

        let startedAt = Date()
        let terminationSemaphore = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in
            terminationSemaphore.signal()
        }

        try process.run()
        debugLog?(
            "whisper-cli.start pid=\(process.processIdentifier) cli=\(cliPath.lastPathComponent) model=\(modelPath.lastPathComponent) threads=\(threads) beam=\(beamSize) translation=\(translationMode.rawValue) timeout=\(Int(timeout))s"
        )

        if terminationSemaphore.wait(timeout: .now() + timeout) == .timedOut {
            debugLog?("whisper-cli.timeout pid=\(process.processIdentifier) after=\(Int(Date().timeIntervalSince(startedAt)))s")
            process.interrupt()

            if terminationSemaphore.wait(timeout: .now() + 2) == .timedOut {
                process.terminate()
            }

            if process.isRunning {
                kill(process.processIdentifier, SIGKILL)
                _ = terminationSemaphore.wait(timeout: .now() + 1)
            }

            throw NSError(
                domain: "WhisperCLIExecutor",
                code: 408,
                userInfo: [NSLocalizedDescriptionKey: "whisper-cli timed out after \(Int(timeout)) seconds"]
            )
        }

        let duration = String(format: "%.2f", Date().timeIntervalSince(startedAt))
        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let stdoutText = String(data: stdoutData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let stderrText = String(data: stderrData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if process.terminationStatus != 0 {
            debugLog?(
                "whisper-cli.exit pid=\(process.processIdentifier) status=\(process.terminationStatus) duration=\(duration)s stderr=\(truncate(stderrText))"
            )
            let errorText = stderrText.isEmpty ? "Unknown whisper-cli error" : stderrText
            throw NSError(
                domain: "WhisperCLIExecutor",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: "whisper-cli failed: \(errorText)"]
            )
        }

        if !stderrText.isEmpty {
            debugLog?("whisper-cli.stderr pid=\(process.processIdentifier) text=\(truncate(stderrText))")
        }
        if !stdoutText.isEmpty {
            debugLog?("whisper-cli.stdout pid=\(process.processIdentifier) text=\(truncate(stdoutText))")
        }
        debugLog?(
            "whisper-cli.exit pid=\(process.processIdentifier) status=0 duration=\(duration)s output=\(outputBase.lastPathComponent).json"
        )

        return outputBase.appendingPathExtension("json")
        #else
        _ = cliPath
        _ = modelPath
        _ = inputWav
        _ = languageHint
        _ = translationMode
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
        translationMode: ASRTranslationMode,
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

        if translationMode == .toEnglish {
            arguments.append("-tr")
        }

        return arguments
    }

    private static func truncate(_ text: String, limit: Int = 500) -> String {
        guard text.count > limit else { return text }
        return "\(text.prefix(limit))…"
    }
}
