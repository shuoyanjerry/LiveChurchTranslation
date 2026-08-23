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
        case .idle: "等待 Mac 开始"
        case .requestingPermission: "请在 Mac 上允许麦克风"
        case .preparingModel: "正在准备本机模型"
        case .listening: "正在聆听"
        case .recognizing: "正在识别语音"
        case .translating: "正在翻译"
        case .stopping: "正在完成当前语句"
        case .failed: "请在 Mac 上检查"
        }
    }
}
