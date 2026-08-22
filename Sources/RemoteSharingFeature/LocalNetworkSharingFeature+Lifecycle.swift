import Foundation
import RemoteSharingFeatureAPI

extension LocalNetworkSharingFeature {
    func toggle() async {
        operationRevision += 1
        let revision = operationRevision
        switch currentState {
        case .off, .failed:
            await enable(revision: revision)
        case .starting, .on:
            await disable(revision: revision)
        }
    }

    private func enable(revision: Int) async {
        setState(.starting)
        await sharing.setEnabled(true)
        do {
            let started = try await transport.start(configuration: configuration)
            guard revision == operationRevision else {
                await transport.stop()
                return
            }
            endpoint = started
            await refreshPeers()
        } catch {
            await sharing.setEnabled(false)
            setState(.failed(message: bounded(error)))
        }
    }

    private func disable(revision: Int) async {
        await sharing.setEnabled(false)
        await transport.stop()
        guard revision == operationRevision else { return }
        endpoint = nil
        invitation = nil
        peers = []
        connectionCount = 0
        setState(.off)
    }
}
