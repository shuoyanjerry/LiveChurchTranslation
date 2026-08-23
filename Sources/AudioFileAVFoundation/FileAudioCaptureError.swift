import Foundation

public enum FileAudioCaptureError: Error, Equatable, LocalizedError, Sendable {
    case invalidURL
    case unreadableFile(String)
    case unsupportedFormat(String)
    case decodingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            "The selected audio source is not a local file."
        case .unreadableFile(let name):
            "The audio file could not be opened: \(name)"
        case .unsupportedFormat(let detail):
            "The audio format is unsupported: \(detail)"
        case .decodingFailed(let detail):
            "The audio file could not be decoded: \(detail)"
        }
    }
}
