import Foundation
import RemoteSharingAPI

public enum RemoteSessionCommand: String, Codable, Sendable {
    case start
    case stop
}

public struct RemoteControlRequest: Equatable, Codable, Sendable {
    public let requestID: UUID
    public let command: RemoteSessionCommand
    public let expectedRevision: UInt64

    public init(
        requestID: UUID = UUID(),
        command: RemoteSessionCommand,
        expectedRevision: UInt64
    ) {
        self.requestID = requestID
        self.command = command
        self.expectedRevision = expectedRevision
    }
}

public enum RemoteControlRejection: String, Error, Codable, Sendable {
    case unauthorized
    case viewerIsReadOnly
    case staleRevision
    case sharingDisabled
    case unavailable
}

public struct RemoteControlResult: Equatable, Codable, Sendable {
    public let requestID: UUID
    public let accepted: Bool
    public let authoritativeRevision: UInt64
    public let rejection: RemoteControlRejection?

    public init(
        requestID: UUID,
        accepted: Bool,
        authoritativeRevision: UInt64,
        rejection: RemoteControlRejection? = nil
    ) {
        self.requestID = requestID
        self.accepted = accepted
        self.authoritativeRevision = authoritativeRevision
        self.rejection = rejection
    }
}

public struct RemoteControlAuthorization: Equatable, Sendable {
    public let peerID: RemotePeerID
    public let grantID: RemoteGrantID
    public let role: RemoteRole

    public init(peerID: RemotePeerID, grantID: RemoteGrantID, role: RemoteRole) {
        self.peerID = peerID
        self.grantID = grantID
        self.role = role
    }
}
