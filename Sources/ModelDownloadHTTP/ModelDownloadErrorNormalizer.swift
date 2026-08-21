import Foundation
import ModelDownloadAPI

enum ModelDownloadErrorNormalizer {
    static func normalize(_ error: Error) -> ModelDownloadError {
        if error is CancellationError || Task.isCancelled {
            return .cancelled
        }
        if let downloadError = error as? ModelDownloadError {
            return downloadError
        }
        return .downloadFailed(error.localizedDescription)
    }
}
