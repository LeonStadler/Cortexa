import Foundation

enum VoiceModelDownloadError: Error {
    case missingDestination
    case missingTemporaryDownloadLocation
    case invalidHTTPResponse(Int)
}

final class VoiceModelDownloadClient: NSObject, @unchecked Sendable {
    private let fileManager: FileManager
    private var progressHandler: (@Sendable (VoiceModelInstallProgress) -> Void)?
    private var downloadContinuation: CheckedContinuation<Void, Error>?
    private var activeDownloadTask: URLSessionDownloadTask?
    private var destinationURL: URL?
    private var hasFinished = false
    private var lastReportedFraction: Double = 0
    private var fallbackTotalBytes: Int64?
    private lazy var session: URLSession = {
        URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil)
    }()

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func download(
        from sourceURL: URL,
        to destinationURL: URL,
        expectedDownloadBytes: Int64? = nil,
        progressHandler: @escaping @Sendable (VoiceModelInstallProgress) -> Void
    ) async throws {
        hasFinished = false
        lastReportedFraction = 0
        fallbackTotalBytes = expectedDownloadBytes
        self.progressHandler = progressHandler
        self.destinationURL = destinationURL

        progressHandler(
            VoiceModelInstallProgress(phase: .preparing, fractionCompleted: 0)
        )

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<Void, Error>) in
                guard !Task.isCancelled else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                downloadContinuation = continuation
                let task = session.downloadTask(with: sourceURL)
                activeDownloadTask = task
                if Task.isCancelled {
                    task.cancel()
                } else {
                    task.resume()
                }
            }
        } onCancel: {
            self.activeDownloadTask?.cancel()
        }
    }

    private func finish(with result: Result<Void, Error>) {
        guard !hasFinished else { return }
        hasFinished = true
        activeDownloadTask = nil

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
        let httpTotal =
            totalBytesExpectedToWrite > 0
            ? totalBytesExpectedToWrite
            : downloadTask.countOfBytesExpectedToReceive
        let computed = VoiceModelDownloadProgressMath.computeProgress(
            receivedBytes: totalBytesWritten,
            httpTotalBytes: httpTotal,
            fallbackTotalBytes: fallbackTotalBytes,
            previousFraction: lastReportedFraction
        )
        lastReportedFraction = computed.fractionCompleted

        progressHandler?(
            VoiceModelInstallProgress(
                phase: .downloading,
                fractionCompleted: computed.fractionCompleted,
                receivedBytes: totalBytesWritten,
                totalBytes: computed.totalBytes,
                isIndeterminate: computed.isIndeterminate
            )
        )
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        if let response = downloadTask.response as? HTTPURLResponse,
            !(200...299).contains(response.statusCode) {
            finish(with: .failure(VoiceModelDownloadError.invalidHTTPResponse(response.statusCode)))
            return
        }
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
