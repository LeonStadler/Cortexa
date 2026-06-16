import Foundation

enum VoiceModelDownloadError: Error {
    case missingDestination
    case missingTemporaryDownloadLocation
}

final class VoiceModelDownloadClient: NSObject, @unchecked Sendable {
    private let fileManager: FileManager
    private var progressHandler: (@Sendable (VoiceModelInstallProgress) -> Void)?
    private var downloadContinuation: CheckedContinuation<Void, Error>?
    private var destinationURL: URL?
    private var hasFinished = false
    private lazy var session: URLSession = {
        URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil)
    }()

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func download(
        from sourceURL: URL,
        to destinationURL: URL,
        progressHandler: @escaping @Sendable (VoiceModelInstallProgress) -> Void
    ) async throws {
        hasFinished = false
        self.progressHandler = progressHandler
        self.destinationURL = destinationURL

        progressHandler(
            VoiceModelInstallProgress(phase: .preparing, fractionCompleted: 0)
        )

        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in
            downloadContinuation = continuation
            session.downloadTask(with: sourceURL).resume()
        }
    }

    private func finish(with result: Result<Void, Error>) {
        guard !hasFinished else { return }
        hasFinished = true

        switch result {
        case .success:
            downloadContinuation?.resume()
        case .failure(let error):
            downloadContinuation?.resume(throwing: error)
        }
        downloadContinuation = nil
    }
}

extension VoiceModelDownloadClient: URLSessionDownloadDelegate {
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let expectedTotal =
            totalBytesExpectedToWrite > 0
            ? totalBytesExpectedToWrite
            : downloadTask.countOfBytesExpectedToReceive
        let fraction: Double
        if expectedTotal > 0 {
            fraction = min(Double(totalBytesWritten) / Double(expectedTotal), 0.95)
        } else {
            fraction = 0
        }

        progressHandler?(
            VoiceModelInstallProgress(
                phase: .downloading,
                fractionCompleted: fraction,
                receivedBytes: totalBytesWritten,
                totalBytes: expectedTotal > 0 ? expectedTotal : nil
            )
        )
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let destinationURL else {
            finish(with: .failure(VoiceModelDownloadError.missingDestination))
            return
        }

        do {
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.moveItem(at: location, to: destinationURL)
            progressHandler?(
                VoiceModelInstallProgress(phase: .finalizing, fractionCompleted: 0.98)
            )
            finish(with: .success(()))
        } catch {
            finish(with: .failure(error))
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?)
    {
        guard let error else { return }
        finish(with: .failure(error))
    }
}
