import Foundation
import RemotePairingAPI
import RemoteSharingAPI

public actor RemoteSocketSession {
    public let peerID: RemotePeerID
    private let grantID: RemoteGrantID
    private let bearerCredential: String
    private let pairing: any RemotePairingServing
    private let projection: any RemoteProjectionProviding
    private var isClosed = false
    private var didDisconnect = false

    public init(
        peerID: RemotePeerID,
        grantID: RemoteGrantID,
        bearerCredential: String,
        pairing: any RemotePairingServing,
        projection: any RemoteProjectionProviding
    ) {
        self.peerID = peerID
        self.grantID = grantID
        self.bearerCredential = bearerCredential
        self.pairing = pairing
        self.projection = projection
    }

    public func outgoing(limit: Int = 64) async throws -> [RemoteProjectionEnvelope] {
        guard !isClosed else { return [] }
        try await reauthorize()
        return await projection.drain(peerID: peerID, limit: min(max(limit, 1), 256))
    }

    public func receive(_ frame: WebSocketFrame) async throws -> WebSocketFrame? {
        guard !isClosed else { return nil }
        try await reauthorize()
        switch frame.opcode {
        case .ping:
            return WebSocketFrame(opcode: .pong, payload: frame.payload)
        case .pong:
            return nil
        case .close:
            isClosed = true
            await disconnectIfNeeded()
            return WebSocketFrame(opcode: .close, payload: frame.payload)
        case .text:
            guard frame.text == #"{"type":"ping"}"# else {
                throw RemoteTransportError.invalidWebSocketFrame
            }
            return WebSocketFrame(opcode: .pong, payload: Data())
        }
    }

    func validateAuthorization() async throws {
        guard !isClosed else { throw RemoteTransportError.unauthorized }
        try await reauthorize()
    }

    public func close() async {
        isClosed = true
        await disconnectIfNeeded()
    }

    private func disconnectIfNeeded() async {
        guard !didDisconnect else { return }
        didDisconnect = true
        await projection.disconnect(peerID: peerID)
    }

    private func reauthorize() async throws {
        let authorization: RemotePairingAuthorization
        do {
            authorization = try await pairing.authorize(
                bearerCredential: bearerCredential,
                requiresMutation: false,
                now: Date()
            )
        } catch {
            await failClosed()
            throw RemoteTransportError.unauthorized
        }
        guard authorization.peerID == peerID, authorization.grantID == grantID else {
            await failClosed()
            throw RemoteTransportError.unauthorized
        }
    }

    private func failClosed() async {
        isClosed = true
        await disconnectIfNeeded()
    }
}
