import Foundation
@preconcurrency import Network

actor NWRemoteConnectionHandler {
    let id: UUID
    let connection: NWConnection
    let peer: RemotePeerAddress
    let components: RemoteServerComponents
    let limits: RemoteTransportLimits
    private let queue: DispatchQueue
    private let onClosed: @Sendable (UUID) -> Void
    var mode = RemoteConnectionMode.http
    var buffer = Data()
    var pumpTask: Task<Void, Never>?
    var handshakeTimeoutTask: Task<Void, Never>?
    var closed = false

    init(
        id: UUID,
        connection: NWConnection,
        peer: RemotePeerAddress,
        components: RemoteServerComponents,
        limits: RemoteTransportLimits,
        onClosed: @escaping @Sendable (UUID) -> Void
    ) {
        self.id = id
        self.connection = connection
        self.peer = peer
        self.components = components
        self.limits = limits
        self.onClosed = onClosed
        queue = DispatchQueue(label: "org.churchtranslation.remote.connection.\(id.uuidString)")
    }

    func start() {
        connection.stateUpdateHandler = { [weak self] state in
            guard case .failed = state else {
                if case .cancelled = state { Task { [weak self] in await self?.close() } }
                return
            }
            Task { [weak self] in await self?.close() }
        }
        connection.start(queue: queue)
        startHTTPHandshakeDeadline()
        receiveNext()
    }

    func close() async {
        guard !closed else { return }
        closed = true
        pumpTask?.cancel()
        pumpTask = nil
        cancelHTTPHandshakeDeadline()
        if case .webSocket(let session) = mode { await session.close() }
        connection.cancel()
        onClosed(id)
    }

    func receiveNext() {
        guard !closed else { return }
        connection.receive(
            minimumIncompleteLength: 1,
            maximumLength: 16_384
        ) { [weak self] content, _, isComplete, error in
            Task { [weak self] in
                await self?.received(content, isComplete: isComplete, error: error)
            }
        }
    }

    private func received(_ content: Data?, isComplete: Bool, error: NWError?) async {
        guard !closed else { return }
        if let content { buffer.append(content) }
        if error != nil || isComplete {
            await close()
            return
        }
        switch mode {
        case .http:
            await processHTTP()
        case .webSocket(let session):
            await processWebSocket(session)
        }
    }

}

enum RemoteConnectionMode {
    case http
    case webSocket(RemoteSocketSession)
}
