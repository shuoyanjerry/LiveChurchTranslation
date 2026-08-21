import Foundation
import ModelRuntimeAPI

public protocol ModelDownloadProvider: Sendable {
    func ensureAvailable(_ descriptor: ModelDescriptor) async throws -> URL
    func cancelDownload(for modelID: ModelID) async
}

public enum ModelDownloadError: LocalizedError, Sendable {
    case downloadFailed(String)
    case invalidArtifact
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .downloadFailed(let message): "Model download failed: \(message)"
        case .invalidArtifact: "The downloaded model is incomplete or invalid."
        case .cancelled: "Model download was cancelled."
        }
    }
}
