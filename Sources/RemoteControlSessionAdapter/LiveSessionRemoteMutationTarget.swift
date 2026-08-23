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
            "Recording can only be started from the Mac after the local notice is accepted."
        case .noActiveSession:
            "There is no active session to stop."
        }
    }
}
