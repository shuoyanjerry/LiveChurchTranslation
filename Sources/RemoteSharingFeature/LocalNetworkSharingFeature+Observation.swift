import Foundation
import RemotePairingAPI
import RemoteSharingFeatureAPI
import RemoteTransportAPI

extension LocalNetworkSharingFeature {
    func startObservingIfNeeded() {
        guard observationTasks.isEmpty else { return }
        observationTasks = [
            Task { [weak self, pairing] in
                for await event in await pairing.events() {
                    await self?.receive(event)
                }
            },
            Task { [weak self, transport] in
                for await event in await transport.events() {
                    await self?.receive(event)
                }
            },
        ]
    }

    func receive(_ event: RemotePairingEvent) async {
        switch event {
        case .snapshotChanged:
            await refreshPeersFromEvent()
        case .audit:
            break
        }
    }

    func receive(_ event: RemoteTransportEvent) {
        switch event {
        case .connectionCountChanged(let count):
            connectionCount = count
            publishOnState()
        case .statusChanged(let status):
            receive(status)
        }
    }

    private func receive(_ status: RemoteTransportStatus) {
        switch status {
        case .stopped:
            break
        case .starting:
            setState(.starting)
        case .running(let activeEndpoint):
            endpoint = activeEndpoint
            publishOnState()
        case .localNetworkPermissionDenied:
            endpoint = nil
            invitation = nil
            setState(.localNetworkPermissionDenied)
        case .failed(let message):
            endpoint = nil
            invitation = nil
            setState(.failed(message: String(message.prefix(180))))
        }
    }

    private func refreshPeersFromEvent() async {
        await refreshPeers()
    }
}
