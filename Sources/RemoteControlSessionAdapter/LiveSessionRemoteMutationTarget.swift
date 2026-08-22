import AudioCaptureAPI
import RemoteControlAPI
import SessionManagementAPI
import SettingsAPI

public struct LiveSessionRemoteMutationTarget: RemoteSessionMutationTarget {
    private let controller: any LiveSessionController
    private let settings: any SettingsStore

    public init(controller: any LiveSessionController, settings: any SettingsStore) {
        self.controller = controller
        self.settings = settings
    }

    public func startRemoteSession() async throws {
        guard await controller.currentSnapshot().sessionID == nil else {
            throw LiveSessionRemoteMutationError.sessionAlreadyActive
        }
        let selectedID = try await settings.load().selectedAudioDeviceID
        let inputID = selectedID.map(AudioInputID.init(rawValue:))
        await controller.start(inputDeviceID: inputID)
        guard await controller.currentSnapshot().sessionID != nil else {
            throw LiveSessionRemoteMutationError.startRejected
        }
    }

    public func stopRemoteSession() async throws {
        guard await controller.currentSnapshot().sessionID != nil else {
            throw LiveSessionRemoteMutationError.noActiveSession
        }
        await controller.stop()
    }
}

public enum LiveSessionRemoteMutationError: Error, Equatable, Sendable {
    case sessionAlreadyActive
    case startRejected
    case noActiveSession
}
