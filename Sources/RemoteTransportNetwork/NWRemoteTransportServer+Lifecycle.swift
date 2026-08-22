import Foundation
@preconcurrency import Network
import RemoteTransportAPI

extension NWRemoteTransportServer {
    func installHandlers(on listener: NWListener) {
        listener.stateUpdateHandler = { [weak self] state in
            Task { await self?.listenerStateChanged(state) }
        }
        listener.newConnectionHandler = { [weak self] connection in
            Task { await self?.accept(connection) }
        }
    }

    func listenerStateChanged(_ state: NWListener.State) async {
        switch state {
        case .ready:
            becomeReady()
        case .failed(let error):
            if startContinuation != nil {
                failStart(error.localizedDescription)
            } else {
                await failRunningServer(error.localizedDescription)
            }
        case .cancelled:
            if listener != nil { setStatus(.stopped) }
        default:
            break
        }
    }

    func failRunningServer(_ message: String) async {
        let bounded = String(message.prefix(240))
        heartbeatTask?.cancel()
        heartbeatTask = nil
        listener?.cancel()
        listener = nil
        let openConnections = connections.values
        connections.removeAll()
        for connection in openConnections { await connection.close() }
        components = nil
        await pairingManager.revokeAll(now: Date())
        setStatus(.failed(message: bounded))
        emit(.connectionCountChanged(0))
    }

    func becomeReady() {
        guard
            let listener,
            let port = listener.port?.rawValue,
            let configuration = activeConfiguration
        else {
            failStart("Listener did not provide a port")
            return
        }
        components = makeServerComponents(configuration: configuration, port: port)
        guard let url = URL(string: "http://\(configuration.advertisedHostName):\(port)") else {
            failStart("Invalid advertised URL")
            return
        }
        let endpoint = RemoteEndpoint(baseURL: url, port: port)
        startContinuation?.resume(returning: endpoint)
        startContinuation = nil
        setStatus(.running(endpoint))
        startHeartbeat()
    }

    func failStart(_ message: String) {
        let bounded = String(message.prefix(240))
        listener?.cancel()
        listener = nil
        startContinuation?.resume(
            throwing: RemoteTransportLifecycleError.listenerFailed(bounded)
        )
        startContinuation = nil
        setStatus(.failed(message: bounded))
    }

    func accept(_ connection: NWConnection) {
        guard let configuration = activeConfiguration,
            connections.count < configuration.maximumConnections,
            let components,
            let peer = NWEndpointPeer.address(for: connection),
            peer.isPrivateLinkLocalOrLoopback
        else {
            connection.cancel()
            return
        }
        let id = UUID()
        let handler = NWRemoteConnectionHandler(
            id: id,
            connection: connection,
            peer: peer,
            components: components,
            limits: limits
        ) { [weak self] closedID in
            Task { await self?.removeConnection(closedID) }
        }
        connections[id] = handler
        emit(.connectionCountChanged(connections.count))
        Task { await handler.start() }
    }

    func removeConnection(_ id: UUID) {
        connections.removeValue(forKey: id)
        emit(.connectionCountChanged(connections.count))
    }

    func startHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = Task { [projection] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                if !Task.isCancelled { await projection.heartbeat() }
            }
        }
    }

    func setStatus(_ status: RemoteTransportStatus) {
        currentStatus = status
        emit(.statusChanged(status))
    }

    func emit(_ event: RemoteTransportEvent) {
        for continuation in eventContinuations.values { continuation.yield(event) }
    }

    func removeEventContinuation(_ id: UUID) {
        eventContinuations.removeValue(forKey: id)
    }

    func isValid(_ configuration: RemoteTransportConfiguration) -> Bool {
        let host = configuration.advertisedHostName
        return !host.isEmpty && !host.contains("://") && !host.contains("/")
            && !host.contains("@") && !host.contains(where: { $0.isWhitespace || $0.isNewline })
            && !configuration.bonjour.name.isEmpty && configuration.bonjour.name.count <= 63
            && configuration.bonjour.type == "_churchtranslate._tcp"
            && configuration.bonjour.textRecord.count <= 1_300
    }
}
