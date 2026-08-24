import Foundation
import SettingsAPI

public protocol AudioImporting: Sendable {
    func importAudio(
        from url: URL,
        mode: TranslationMode,
        sessionTitle: String?
    ) async throws
    func cancelImport() async
}

extension AudioImporting {
    public func importAudio(from url: URL, mode: TranslationMode) async throws {
        try await importAudio(from: url, mode: mode, sessionTitle: nil)
    }
}

public enum AudioImportError: LocalizedError, Equatable, Sendable {
    case cancelled
    case liveSessionRunning
    case savedWithIncompleteTranscript(sessionID: UUID?)
    case transcriptionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .cancelled:
            nil
        case .liveSessionRunning:
            "请先停止当前现场会话，再导入并听抄音频文件。"
        case .savedWithIncompleteTranscript:
            "录音已保存，听抄未完整。"
        case .transcriptionFailed(let message):
            "音频听抄失败：\(message)"
        }
    }

    public var description: String {
        errorDescription ?? "音频听抄已取消。"
    }

    public var debugDescription: String { description }
}

extension AudioImportError: CustomStringConvertible, CustomDebugStringConvertible {}
