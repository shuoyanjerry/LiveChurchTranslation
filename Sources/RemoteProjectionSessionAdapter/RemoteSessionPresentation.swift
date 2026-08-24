import RemoteSharingAPI
import SessionManagementAPI

enum RemoteSessionPresentation {
    static func phase(_ value: LiveSessionPhase) -> RemoteSessionPhase {
        switch value {
        case .idle: .idle
        case .requestingPermission, .preparingModel: .preparing
        case .listening: .listening
        case .recognizing: .recognizing
        case .translating: .translating
        case .stopping: .stopping
        case .failed: .failed
        }
    }

    static func message(_ value: LiveSessionPhase) -> String {
        switch value {
        case .idle: "等待开始"
        case .requestingPermission, .preparingModel: "准备中"
        case .listening, .recognizing, .translating: "直播中"
        case .stopping: "即将结束"
        case .failed: "已暂停"
        }
    }
}
