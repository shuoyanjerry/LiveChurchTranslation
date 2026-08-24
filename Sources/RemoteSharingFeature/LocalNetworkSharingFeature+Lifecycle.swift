import Foundation
import RemoteSharingFeatureAPI
import RemoteTransportAPI

extension LocalNetworkSharingFeature {
    func toggle() async {
        guard !isStopping else { return }
        operationRevision += 1
        let revision = operationRevision
        switch currentState {
        case .off, .localNetworkPermissionDenied, .failed:
            await enable(revision: revision)
        case .starting, .on:
            await disable(revision: revision)
        }
    }

    private func enable(revision: Int) async {
        setState(.starting)
        await sharing.setEnabled(true)
        do {
            let started = try await transport.start(configuration: sessionConfiguration())
            guard revision == operationRevision else {
                await transport.stop()
                await pairing.revokeAll(now: Date())
                return
            }
            sessionPort = started.port
            endpoint = started
            await refreshPeers()
        } catch RemoteTransportLifecycleError.localNetworkPermissionDenied {
            guard revision == operationRevision else { return }
            await sharing.setEnabled(false)
            guard revision == operationRevision else { return }
            suspendLocalEndpoint()
            setState(.localNetworkPermissionDenied)
        } catch {
            guard revision == operationRevision else { return }
            await sharing.setEnabled(false)
            guard revision == operationRevision else { return }
            suspendLocalEndpoint()
            setState(.failed(message: bounded(error)))
        }
    }

    private func disable(revision: Int) async {
        isStopping = true
        invalidateLocalSession()
        setState(.off)
        await sharing.setEnabled(false)
        await pairing.revokeAll(now: Date())
        await transport.stop()
        isStopping = false
        guard revision == operationRevision else { return }
        setState(.off)
    }

    func invalidateLocalSession() {
        invitationRevision += 1
        endpoint = nil
        sessionPort = nil
        invitation = nil
        peers = []
        connectionCount = 0
    }

    func suspendLocalEndpoint() {
        endpoint = nil
        connectionCount = 0
    }

    private func sessionConfiguration() -> RemoteTransportConfiguration {
        guard let sessionPort else { return configuration }
        return RemoteTransportConfiguration(
            advertisedHostName: configuration.advertisedHostName,
            preferredPort: sessionPort,
            maximumConnections: configuration.maximumConnections,
            maximumConnectionsPerPeer: configuration.maximumConnectionsPerPeer,
            bonjour: configuration.bonjour
        )
    }
}
