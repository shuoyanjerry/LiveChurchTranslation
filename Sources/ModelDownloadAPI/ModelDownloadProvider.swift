import Foundation
import ModelRuntimeAPI

public protocol ModelDownloadProvider: Sendable {
    func ensureAvailable(_ descriptor: ModelDescriptor) async throws -> URL
    func cancelDownload(for modelID: ModelID) async
}

public enum ModelDownloadError: LocalizedError, Equatable, Sendable {
    case downloadFailed(String)
    case insufficientDiskSpace(requiredBytes: Int64, availableBytes: Int64)
    case invalidArtifact
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .downloadFailed(let message): "Model download failed: \(message)"
        case .insufficientDiskSpace(let requiredBytes, let availableBytes):
            "Model preparation requires \(requiredBytes) bytes, but only "
                + "\(availableBytes) bytes are available."
        case .invalidArtifact: "The downloaded model is incomplete or invalid."
        case .cancelled: "Model download was cancelled."
        }
    }
}
