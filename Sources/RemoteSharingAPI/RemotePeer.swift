import Foundation

public struct RemotePeerMetadata: Equatable, Codable, Sendable {
    public let displayName: String
    public let userAgentSummary: String

    public init(displayName: String, userAgentSummary: String) {
        self.displayName = displayName
        self.userAgentSummary = userAgentSummary
    }
}

public struct RemotePeer: Identifiable, Equatable, Codable, Sendable {
    public let id: RemotePeerID
    public let grantID: RemoteGrantID
    public let metadata: RemotePeerMetadata
    public let role: RemoteRole
    public let pairedAt: Date
    public let expiresAt: Date

    public init(
        id: RemotePeerID,
        grantID: RemoteGrantID,
        metadata: RemotePeerMetadata,
        role: RemoteRole,
        pairedAt: Date,
        expiresAt: Date
    ) {
        self.id = id
        self.grantID = grantID
        self.metadata = metadata
        self.role = role
        self.pairedAt = pairedAt
        self.expiresAt = expiresAt
    }
}
