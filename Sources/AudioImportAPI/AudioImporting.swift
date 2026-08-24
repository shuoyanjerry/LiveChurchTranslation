import Foundation
import SettingsAPI

public protocol AudioImporting: Sendable {
    func importAudio(from url: URL, mode: TranslationMode) async throws
    func cancelImport() async
}

public enum AudioImportError: LocalizedError, Equatable, Sendable {
    case cancelled
    case liveSessionRunning
    case transcriptionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .cancelled:
            nil
        case .liveSessionRunning:
            "请先停止实时翻译，再导入音频文件。"
        case .transcriptionFailed(let message):
            "音频听抄失败：\(message)"
        }
    }
}
