import Foundation

/// Ephemeral URLSession transport with download-task progress and no response cache.
public struct URLSessionModelHTTPTransport: ModelHTTPTransport, @unchecked Sendable {
    private let session: URLSession

    public init(session: URLSession = URLSessionModelHTTPTransport.makeSession()) {
        self.session = session
    }

    public func download(
        from remoteURL: URL,
        to localURL: URL,
        progress: @escaping ModelHTTPProgress
    ) async throws -> ModelHTTPTransferResult {
        var request = URLRequest(url: remoteURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 300
        request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")

        let delegate = DownloadProgressDelegate(progress: progress)
        let (temporaryURL, response) = try await session.download(
            for: request,
            delegate: delegate
        )
        try Task.checkCancellation()
        guard let response = response as? HTTPURLResponse else {
            throw ModelHTTPTransportError.nonHTTPResponse
        }
        guard (200...299).contains(response.statusCode) else {
            throw ModelHTTPTransportError.rejectedStatus(response.statusCode)
        }

        let fileManager = FileManager.default
        guard !fileManager.fileExists(atPath: localURL.path) else {
            throw ModelHTTPTransportError.destinationExists
        }
        try fileManager.moveItem(at: temporaryURL, to: localURL)
        let length =
            response.expectedContentLength > 0
            ? response.expectedContentLength
            : nil
        return ModelHTTPTransferResult(
            statusCode: response.statusCode,
            contentLength: length
        )
    }

    /// Creates the bounded production session used by the default initializer.
    public static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 300
        configuration.timeoutIntervalForResource = 7_200
        configuration.waitsForConnectivity = true
        configuration.httpMaximumConnectionsPerHost = 2
        return URLSession(configuration: configuration)
    }
}

private final class DownloadProgressDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let progress: ModelHTTPProgress

    init(progress: @escaping ModelHTTPProgress) {
        self.progress = progress
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let expected =
            totalBytesExpectedToWrite > 0
            ? totalBytesExpectedToWrite
            : nil
        progress(totalBytesWritten, expected)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {}
}
