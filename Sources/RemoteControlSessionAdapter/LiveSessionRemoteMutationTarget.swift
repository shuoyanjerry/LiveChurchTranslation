import AudioCaptureAPI
import Foundation
import RemoteControlAPI
import SessionManagementAPI
import SettingsAPI

public struct LiveSessionRemoteMutationTarget: RemoteSessionMutationTarget {
    private let controller: any LiveSessionController

    public init(controller: any LiveSessionController, settings _: any SettingsStore) {
        self.controller = controller
    }

    public func startRemoteSession() async throws {
        throw LiveSessionRemoteMutationError.localRecordingAuthorizationRequired
    }

    public func stopRemoteSession() async throws {
        guard await controller.currentSnapshot().sessionID != nil else {
            throw LiveSessionRemoteMutationError.noActiveSession
        }
        await controller.stop()
    }
}

public enum LiveSessionRemoteMutationError: LocalizedError, Equatable, Sendable {
    case localRecordingAuthorizationRequired
    case noActiveSession

    public var errorDescription: String? {
        switch self {
        case .localRecordingAuthorizationRequired:
            "请在 Mac 上确认录音提示后开始会议。"
        case .noActiveSession:
            "当前没有正在进行的会议。"
        }
    }
}
