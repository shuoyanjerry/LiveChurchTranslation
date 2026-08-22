import Foundation

/// A least-privilege role granted to a paired remote device.
public enum RemoteRole: String, Codable, CaseIterable, Sendable {
    /// Can read the current projection and receive future transcript updates.
    case viewer

    /// Can read the projection and request Start or Stop after Mac approval.
    case `operator`
}

public struct RemotePeerID: Hashable, Codable, Sendable {
    public let rawValue: UUID

    public init(rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}

public struct RemoteGrantID: Hashable, Codable, Sendable {
    public let rawValue: UUID

    public init(rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}
