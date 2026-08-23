import Foundation

public enum LocalSharingPeerRole: String, Equatable, Sendable {
    case viewer
    case `operator`
}

public struct LocalSharingPeer: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let role: LocalSharingPeerRole

    public init(id: String, name: String, role: LocalSharingPeerRole) {
        self.id = id
        self.name = name
        self.role = role
    }
}

public struct LocalSharingInvitation: Equatable, Sendable {
    public let role: LocalSharingPeerRole
    public let url: URL
    public let expiresAt: Date

    public init(role: LocalSharingPeerRole, url: URL, expiresAt: Date) {
        self.role = role
        self.url = url
        self.expiresAt = expiresAt
    }
}

public enum LocalSharingViewState: Equatable, Sendable {
    case off
    case starting
    case localNetworkPermissionDenied
    case on(
        endpoint: URL,
        connectionCount: Int,
        invitation: LocalSharingInvitation?,
        peers: [LocalSharingPeer]
    )
    case failed(message: String)
}
