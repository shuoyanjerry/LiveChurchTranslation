public struct RequestAuditMetadata: Equatable, Sendable {
    public let method: String
    public let path: String
    public let peerHost: String
    public let bodyBytes: Int

    public init(request: RemoteHTTPRequest, peer: RemotePeerAddress) {
        method = request.method
        path = request.path
        peerHost = peer.host
        bodyBytes = request.body.count
    }
}
