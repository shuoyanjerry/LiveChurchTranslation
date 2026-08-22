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
        case .idle: "Ready"
        case .requestingPermission: "Waiting for microphone permission on the Mac"
        case .preparingModel: "Preparing local models"
        case .listening: "Listening"
        case .recognizing: "Recognizing Mandarin"
        case .translating: "Translating"
        case .stopping: "Finishing the current sentence"
        case .failed: "Needs attention on the Mac"
        }
    }
}
