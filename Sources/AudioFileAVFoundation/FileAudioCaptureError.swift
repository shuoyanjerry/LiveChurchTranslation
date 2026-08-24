import Foundation

public enum FileAudioCaptureError: Error, Equatable, LocalizedError, Sendable {
    case invalidURL
    case unreadableFile(String)
    case unsupportedFormat(String)
    case decodingFailed(String)
    case insufficientStorage(requiredBytes: UInt64, availableBytes: UInt64)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            "所选媒体不是本地文件。"
        case .unreadableFile(let name):
            "无法打开媒体文件：\(name)"
        case .unsupportedFormat(let detail):
            "暂不支持此媒体格式或音轨：\(detail)"
        case .decodingFailed(let detail):
            "无法解码媒体音轨：\(detail)"
        case .insufficientStorage(let required, let available):
            "存储空间不足：完成导入至少需要 \(Self.bytes(required))，当前可用 \(Self.bytes(available))。"
        }
    }

    private static func bytes(_ value: UInt64) -> String {
        ByteCountFormatter.string(
            fromByteCount: Int64(clamping: value),
            countStyle: .file
        )
    }
}
