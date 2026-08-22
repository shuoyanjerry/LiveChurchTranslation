import Foundation
import RemoteSharingAPI

public struct PairingAuditRecord: Equatable, Codable, Sendable {
    public enum Action: String, Codable, Sendable {
        case invitationIssued
        case paired
        case authorizationDenied
        case revoked
        case expired
        case allRevoked
    }

    public let timestamp: Date
    public let action: Action
    public let role: RemoteRole?
    public let peerID: RemotePeerID?
    public let grantID: RemoteGrantID?

    public init(
        timestamp: Date,
        action: Action,
        role: RemoteRole? = nil,
        peerID: RemotePeerID? = nil,
        grantID: RemoteGrantID? = nil
    ) {
        self.timestamp = timestamp
        self.action = action
        self.role = role
        self.peerID = peerID
        self.grantID = grantID
    }
}
