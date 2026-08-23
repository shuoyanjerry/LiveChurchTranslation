import Foundation

public enum FileAudioCaptureError: Error, Equatable, LocalizedError, Sendable {
    case invalidURL
    case unreadableFile(String)
    case unsupportedFormat(String)
    case decodingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            "所选音频不是本地文件。"
        case .unreadableFile(let name):
            "无法打开音频文件：\(name)"
        case .unsupportedFormat(let detail):
            "暂不支持此音频格式：\(detail)"
        case .decodingFailed(let detail):
            "无法解码音频文件：\(detail)"
        }
    }
}
