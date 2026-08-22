import Foundation
import RemoteSharingAPI

public enum PairingError: String, Error, Equatable, Sendable {
    case invitationExpired
    case invitationAlreadyUsed
    case invalidInvitation
    case grantExpired
    case grantRevoked
    case invalidGrant
    case capacityReached
    case viewerIsReadOnly
}

public struct PairingInvitation: Equatable, Codable, Sendable, CustomStringConvertible {
    public let id: UUID
    public let role: RemoteRole
    public let fragmentCredential: String
    public let expiresAt: Date

    public var description: String {
        "PairingInvitation(id: \(id), role: \(role), credential: <redacted>)"
    }

    public init(id: UUID, role: RemoteRole, fragmentCredential: String, expiresAt: Date) {
        self.id = id
        self.role = role
        self.fragmentCredential = fragmentCredential
        self.expiresAt = expiresAt
    }

    public func fragmentURL(baseURL: URL) -> URL? {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.query = nil
        components?.fragment = "invite=\(id.uuidString).\(fragmentCredential)"
        return components?.url
    }
}

public struct RemotePairingSnapshot: Equatable, Sendable {
    public let activePeers: [RemotePeer]
    public let pendingInvitationCount: Int

    public init(activePeers: [RemotePeer], pendingInvitationCount: Int) {
        self.activePeers = activePeers
        self.pendingInvitationCount = pendingInvitationCount
    }
}

public enum RemotePairingEvent: Equatable, Sendable {
    case snapshotChanged(RemotePairingSnapshot)
    case audit(PairingAuditRecord)
}

public struct PairingRedemption: Equatable, Codable, Sendable {
    public let invitationID: UUID
    public let fragmentCredential: String
    public let peerMetadata: RemotePeerMetadata

    public init(
        invitationID: UUID,
        fragmentCredential: String,
        peerMetadata: RemotePeerMetadata
    ) {
        self.invitationID = invitationID
        self.fragmentCredential = fragmentCredential
        self.peerMetadata = peerMetadata
    }
}

public struct PairingGrant: Equatable, Sendable, CustomStringConvertible {
    public let peer: RemotePeer
    public let bearerCredential: String

    public var description: String {
        "PairingGrant(peer: \(peer.id.rawValue), credential: <redacted>)"
    }

    public init(peer: RemotePeer, bearerCredential: String) {
        self.peer = peer
        self.bearerCredential = bearerCredential
    }
}

public struct RemotePairingAuthorization: Equatable, Sendable {
    public let peerID: RemotePeerID
    public let grantID: RemoteGrantID
    public let role: RemoteRole

    public init(peerID: RemotePeerID, grantID: RemoteGrantID, role: RemoteRole) {
        self.peerID = peerID
        self.grantID = grantID
        self.role = role
    }
}
