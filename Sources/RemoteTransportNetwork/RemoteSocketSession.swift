import Foundation
import RemoteSharingAPI

public actor RemoteSocketSession {
    public let peerID: RemotePeerID
    private let projection: any RemoteProjectionProviding
    private var isClosed = false
    private var didDisconnect = false

    public init(peerID: RemotePeerID, projection: any RemoteProjectionProviding) {
        self.peerID = peerID
        self.projection = projection
    }

    public func outgoing(limit: Int = 64) async -> [RemoteProjectionEnvelope] {
        guard !isClosed else { return [] }
        return await projection.drain(peerID: peerID, limit: min(max(limit, 1), 256))
    }

    public func receive(_ frame: WebSocketFrame) async throws -> WebSocketFrame? {
        guard !isClosed else { return nil }
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

    public func close() async {
        isClosed = true
        await disconnectIfNeeded()
    }

    private func disconnectIfNeeded() async {
        guard !didDisconnect else { return }
        didDisconnect = true
        await projection.disconnect(peerID: peerID)
    }
}
