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

    func receive(_ event: RemoteTransportEvent) async {
        switch event {
        case .connectionCountChanged(let count):
            connectionCount = count
            publishOnState()
        case .statusChanged(let status):
            await receive(status)
        }
    }

    private func receive(_ status: RemoteTransportStatus) async {
        switch status {
        case .stopped:
            guard endpoint != nil || invitation != nil || isStopping else { return }
            await sharing.setEnabled(false)
            guard !isStopping else {
                setState(.off)
                return
            }
            suspendLocalEndpoint()
            setState(.failed(message: "局域网共享已中断，请重试"))
        case .starting:
            setState(.starting)
        case .running(let activeEndpoint):
            if sessionPort == nil { sessionPort = activeEndpoint.port }
            endpoint = activeEndpoint
            publishOnState()
        case .localNetworkPermissionDenied:
            await sharing.setEnabled(false)
            suspendLocalEndpoint()
            setState(.localNetworkPermissionDenied)
        case .failed(let message):
            await sharing.setEnabled(false)
            suspendLocalEndpoint()
            setState(.failed(message: String(message.prefix(180))))
        }
    }

    private func refreshPeersFromEvent() async {
        await refreshPeers()
    }
}
