import Foundation
import Synchronization

final class DownloadProgressDelegate: NSObject, URLSessionDownloadDelegate, Sendable {
    private let maximumBytes: Int64
    private let progress: ModelHTTPProgress
    private let storedFailure = Mutex<ModelHTTPTransportError?>(nil)

    init(maximumBytes: Int64, progress: @escaping ModelHTTPProgress) {
        self.maximumBytes = maximumBytes
        self.progress = progress
    }

    var failure: ModelHTTPTransportError? {
        storedFailure.withLock { $0 }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let declaredBytes = downloadTask.response?.expectedContentLength ?? -1
        guard declaredBytes <= maximumBytes,
            totalBytesExpectedToWrite <= 0 || totalBytesExpectedToWrite <= maximumBytes,
            totalBytesWritten <= maximumBytes
        else {
            rejectOversized(downloadTask)
            return
        }
        progress(
            totalBytesWritten,
            totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : nil
        )
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        guard let redirectedURL = request.url,
            ModelHTTPRedirectPolicy.permits(redirectedURL)
        else {
            storedFailure.withLock { $0 = .rejectedRedirect }
            completionHandler(nil)
            return
        }
        completionHandler(request)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {}

    private func rejectOversized(_ task: URLSessionTask) {
        storedFailure.withLock {
            $0 = .responseTooLarge(maximumBytes: maximumBytes)
        }
        task.cancel()
    }
}

enum ModelHTTPRedirectPolicy {
    static func permits(_ destination: URL) -> Bool {
        guard destination.scheme?.lowercased() == "https",
            destination.host?.isEmpty == false,
            destination.port == nil || destination.port == 443,
            destination.user == nil,
            destination.password == nil,
            destination.fragment == nil
        else { return false }
        return true
    }
}
