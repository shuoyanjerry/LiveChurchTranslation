import Foundation

enum AudioImportTerminalState {
    case saved
    case cancelled
    case savedIncomplete(sessionID: UUID?)
    case failed

    var savedSessionID: UUID? {
        guard case .savedIncomplete(let sessionID) = self else { return nil }
        return sessionID
    }

    var infersUniqueSession: Bool {
        switch self {
        case .saved, .savedIncomplete: true
        case .cancelled, .failed: false
        }
    }

    func message(libraryRefreshed: Bool) -> String? {
        switch (self, libraryRefreshed) {
        case (.saved, true), (.cancelled, true): nil
        case (.saved, false): "录音已保存，资料库暂未更新，请重试。"
        case (.cancelled, false): "资料库暂未更新，请重试。"
        case (.savedIncomplete, true): "录音已保存，听抄未完整。"
        case (.savedIncomplete, false):
            "录音已保存，听抄未完整。资料库暂未更新，请重试。"
        case (.failed, true): "媒体听抄未完成。请确认文件包含可播放的音轨后重试。"
        case (.failed, false): "媒体听抄未完成，资料库暂未更新。请确认文件包含可播放的音轨后重试。"
        }
    }
}
