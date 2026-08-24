import Foundation
@preconcurrency import Network
import RemotePairingAPI
import RemoteTransportAPI

extension NWRemoteTransportServer {
    func makeIPv4Listener(preferredPort: UInt16) throws -> NWListener {
        let parameters = NWParameters.tcp
        guard
            let internetProtocol = parameters.defaultProtocolStack.internetProtocol
                as? NWProtocolIP.Options
        else {
            throw RemoteTransportLifecycleError.invalidConfiguration
        }
        internetProtocol.version = .v4
        guard preferredPort != 0 else { return try NWListener(using: parameters) }
        guard let port = NWEndpoint.Port(rawValue: preferredPort) else {
            throw RemoteTransportLifecycleError.invalidConfiguration
        }
        return try NWListener(using: parameters, on: port)
    }

    func installHandlers(on listener: NWListener, listenerID: UUID) {
        listener.stateUpdateHandler = { [weak self] state in
            Task { [weak self] in
                await self?.listenerStateChanged(state, listenerID: listenerID)
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            Task { [weak self] in await self?.accept(connection, listenerID: listenerID) }
        }
    }

    func listenerStateChanged(_ state: NWListener.State, listenerID: UUID) async {
        guard activeListenerID == listenerID else { return }
        switch state {
        case .ready:
            becomeReady()
        case .waiting(let error):
            guard NWLocalNetworkPermissionDenial.matches(error) else { return }
            await handleLocalNetworkPermissionDenial()
        case .failed(let error):
            await handleListenerFailure(error)
        case .cancelled:
            await stop()
        default:
            break
        }
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

    func accept(_ connection: NWConnection, listenerID: UUID) {
        guard activeListenerID == listenerID,
            let configuration = activeConfiguration,
            connections.count < configuration.maximumConnections,
            let components,
            let peer = NWEndpointPeer.address(for: connection),
            peer.isPrivateLinkLocalOrLoopback,
            let clientBinding = peer.pairingClientBinding,
            connectionCount(for: clientBinding) < configuration.maximumConnectionsPerPeer
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
            Task { [weak self] in await self?.removeConnection(closedID) }
        }
        connections[id] = handler
        connectionBindings[id] = clientBinding
        emit(.connectionCountChanged(connections.count))
        Task { await handler.start() }
    }

    func removeConnection(_ id: UUID) {
        connections.removeValue(forKey: id)
        connectionBindings.removeValue(forKey: id)
        emit(.connectionCountChanged(connections.count))
    }

    func connectionCount(for clientBinding: RemotePairingClientBinding) -> Int {
        connectionBindings.values.lazy.filter { $0 == clientBinding }.count
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
