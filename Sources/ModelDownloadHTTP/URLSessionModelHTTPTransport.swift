import Foundation

/// Ephemeral URLSession transport with download-task progress and no response cache.
public struct URLSessionModelHTTPTransport: ModelHTTPTransport, Sendable {
    private let session: URLSession

    public init(session: URLSession = URLSessionModelHTTPTransport.makeSession()) {
        self.session = session
    }

    public func download(
        from remoteURL: URL,
        to localURL: URL,
        maximumBytes: Int64,
        progress: @escaping ModelHTTPProgress
    ) async throws -> ModelHTTPTransferResult {
        let delegate = DownloadProgressDelegate(
            maximumBytes: maximumBytes,
            progress: progress
        )
        let (temporaryURL, response) = try await performDownload(
            request: Self.request(for: remoteURL),
            delegate: delegate
        )
        defer { try? FileManager.default.removeItem(at: temporaryURL) }

        try Task.checkCancellation()
        if let failure = delegate.failure { throw failure }
        let result = try ModelHTTPResponseValidator.validate(
            response: response,
            downloadedFile: temporaryURL,
            maximumBytes: maximumBytes
        )
        try Self.publish(temporaryURL, to: localURL)
        return result
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

    private func performDownload(
        request: URLRequest,
        delegate: DownloadProgressDelegate
    ) async throws -> (URL, URLResponse) {
        do {
            return try await session.download(for: request, delegate: delegate)
        } catch {
            if let failure = delegate.failure { throw failure }
            throw error
        }
    }

    private static func request(for remoteURL: URL) -> URLRequest {
        var request = URLRequest(url: remoteURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 300
        request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")
        return request
    }

    private static func publish(_ temporaryURL: URL, to localURL: URL) throws {
        let fileManager = FileManager.default
        guard !fileManager.fileExists(atPath: localURL.path) else {
            throw ModelHTTPTransportError.destinationExists
        }
        try fileManager.moveItem(at: temporaryURL, to: localURL)
    }
}
