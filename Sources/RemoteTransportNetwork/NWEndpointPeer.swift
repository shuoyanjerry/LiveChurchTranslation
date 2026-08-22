@preconcurrency import Network

enum NWEndpointPeer {
    static func address(for connection: NWConnection) -> RemotePeerAddress? {
        guard case .hostPort(let host, _) = connection.endpoint else { return nil }
        return RemotePeerAddress(host: String(describing: host))
    }
}
