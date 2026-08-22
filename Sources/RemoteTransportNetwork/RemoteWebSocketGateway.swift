import Foundation
import RemoteControlAPI
import RemotePairingAPI
import RemoteSharingAPI

public struct RemoteSocketOpenResult: Sendable {
    public let handshakeResponse: RemoteHTTPResponse
    public let authorization: RemoteControlAuthorization
    public let initialEnvelope: RemoteProjectionEnvelope
    public let session: RemoteSocketSession

    public init(
        handshakeResponse: RemoteHTTPResponse,
        authorization: RemoteControlAuthorization,
        initialEnvelope: RemoteProjectionEnvelope,
        session: RemoteSocketSession
    ) {
        self.handshakeResponse = handshakeResponse
        self.authorization = authorization
        self.initialEnvelope = initialEnvelope
        self.session = session
    }
}

public struct RemoteWebSocketGateway: Sendable {
    private let security: RequestSecurityPolicy
    private let sharing: any RemoteSharingControlling
    private let pairing: any RemotePairingServing
    private let projection: any RemoteProjectionProviding
    private let handshake = WebSocketHandshake()

    public init(
        security: RequestSecurityPolicy,
        sharing: any RemoteSharingControlling,
        pairing: any RemotePairingServing,
        projection: any RemoteProjectionProviding
    ) {
        self.security = security
        self.sharing = sharing
        self.pairing = pairing
        self.projection = projection
    }

    public func open(
        request: RemoteHTTPRequest,
        peer: RemotePeerAddress
    ) async throws -> RemoteSocketOpenResult {
        try security.validateWebSocket(request, peer: peer)
        guard await sharing.isEnabled() else { throw RemoteTransportError.unauthorized }
        let credential = try RemoteCredentialExtractor.credential(from: request)
        let pairedAuthorization: RemotePairingAuthorization
        do {
            pairedAuthorization = try await pairing.authorize(
                bearerCredential: credential,
                requiresMutation: false,
                now: Date()
            )
        } catch {
            throw RemoteTransportError.unauthorized
        }
        let authorization = RemoteControlAuthorization(
            peerID: pairedAuthorization.peerID,
            grantID: pairedAuthorization.grantID,
            role: pairedAuthorization.role
        )
        let response = try handshake.response(for: request)
        let connection = await projection.connect(peerID: authorization.peerID)
        let session = RemoteSocketSession(peerID: authorization.peerID, projection: projection)
        return RemoteSocketOpenResult(
            handshakeResponse: response,
            authorization: authorization,
            initialEnvelope: .init(payload: .snapshot(connection.snapshot)),
            session: session
        )
    }
}
