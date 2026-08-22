import Foundation

public struct RequestSecurityConfiguration: Equatable, Sendable {
    public let allowedHosts: Set<String>
    public let allowedOrigins: Set<String>

    public init(allowedHosts: Set<String>, allowedOrigins: Set<String>) {
        self.allowedHosts = Set(allowedHosts.map { $0.lowercased() })
        self.allowedOrigins = Set(allowedOrigins.map { $0.lowercased() })
    }
}

public struct RequestSecurityPolicy: Sendable {
    private let configuration: RequestSecurityConfiguration

    public init(configuration: RequestSecurityConfiguration) {
        self.configuration = configuration
    }

    public func validateBase(_ request: RemoteHTTPRequest, peer: RemotePeerAddress) throws {
        guard peer.isPrivateLinkLocalOrLoopback else { throw RemoteTransportError.nonLocalPeer }
        guard request.query == nil else { throw RemoteTransportError.credentialsInURL }
        guard let host = request.singleHeader("host")?.lowercased(),
            isSafeHost(host), configuration.allowedHosts.contains(host)
        else {
            throw RemoteTransportError.invalidHost
        }
    }

    public func validateMutation(_ request: RemoteHTTPRequest, peer: RemotePeerAddress) throws {
        try validateBase(request, peer: peer)
        guard let origin = request.singleHeader("origin")?.lowercased(),
            configuration.allowedOrigins.contains(origin)
        else {
            throw RemoteTransportError.invalidOrigin
        }
    }

    public func validateWebSocket(_ request: RemoteHTTPRequest, peer: RemotePeerAddress) throws {
        try validateMutation(request, peer: peer)
        guard request.method == "GET", request.path == "/ws" else {
            throw RemoteTransportError.invalidWebSocketHandshake
        }
    }

    private func isSafeHost(_ host: String) -> Bool {
        !host.isEmpty && !host.contains("@") && !host.contains("/")
            && !host.contains("\\") && !host.contains(where: { $0.isWhitespace || $0.isNewline })
    }
}
