import Foundation

public struct RemoteProjectionConnection: Sendable {
    public let peerID: RemotePeerID
    public let snapshot: RemoteProjectionSnapshot

    public init(peerID: RemotePeerID, snapshot: RemoteProjectionSnapshot) {
        self.peerID = peerID
        self.snapshot = snapshot
    }
}

public protocol RemoteProjectionProviding: Sendable {
    func connect(peerID: RemotePeerID) async -> RemoteProjectionConnection
    func disconnect(peerID: RemotePeerID) async
    func drain(peerID: RemotePeerID, limit: Int) async -> [RemoteProjectionEnvelope]
    func snapshot() async -> RemoteProjectionSnapshot
}

public protocol RemoteSharingControlling: Sendable {
    func isEnabled() async -> Bool
    func setEnabled(_ enabled: Bool) async
}
