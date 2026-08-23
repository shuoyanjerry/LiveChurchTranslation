import Foundation
import ModelRuntimeAPI

public protocol ModelDownloadProvider: Sendable {
    func ensureAvailable(_ descriptor: ModelDescriptor) async throws -> URL
    func cancelDownload(for modelID: ModelID) async
}

public protocol ModelPreparationUserFacingError: Error, Sendable {
    var modelPreparationMessage: String { get }
}

public enum ModelDownloadError: LocalizedError, Equatable, Sendable {
    case downloadFailed(String)
    case insufficientDiskSpace(requiredBytes: Int64, availableBytes: Int64)
    case invalidArtifact
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .downloadFailed(let message): "模型修复下载失败：\(message)"
        case .insufficientDiskSpace(let requiredBytes, let availableBytes):
            "模型准备需要 \(requiredBytes) 字节空间，但当前只有 \(availableBytes) 字节可用。"
        case .invalidArtifact: "模型文件不完整或无效。"
        case .cancelled: "模型修复已取消。"
        }
    }
}
