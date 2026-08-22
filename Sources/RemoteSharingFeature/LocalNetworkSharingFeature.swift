import Foundation
import RemotePairingAPI
import RemoteSharingAPI
import RemoteSharingFeatureAPI
import RemoteTransportAPI

public actor LocalNetworkSharingFeature: LocalSharingFeature {
    let sharing: any RemoteSharingControlling
    let pairing: any RemotePairingManaging
    let transport: any RemoteTransportServing
    let configuration: RemoteTransportConfiguration
    var currentState = LocalSharingViewState.off
    var endpoint: RemoteEndpoint?
    var connectionCount = 0
    var invitation: LocalSharingInvitation?
    var peers: [LocalSharingPeer] = []
    var continuations: [UUID: AsyncStream<LocalSharingViewState>.Continuation] = [:]
    var observationTasks: [Task<Void, Never>] = []
    var operationRevision = 0

    public init(
        sharing: any RemoteSharingControlling,
        pairing: any RemotePairingManaging,
        transport: any RemoteTransportServing,
        configuration: RemoteTransportConfiguration
    ) {
        self.sharing = sharing
        self.pairing = pairing
        self.transport = transport
        self.configuration = configuration
    }

    public func state() -> LocalSharingViewState { currentState }

    public func events() -> AsyncStream<LocalSharingViewState> {
        startObservingIfNeeded()
        let id = UUID()
        return AsyncStream { continuation in
            continuations[id] = continuation
            continuation.yield(currentState)
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeContinuation(id) }
            }
        }
    }

    public func send(_ intent: LocalSharingIntent) async {
        startObservingIfNeeded()
        switch intent {
        case .toggle:
            await toggle()
        case .createInvitation(let role):
            await createInvitation(role)
        case .revoke(let peerID):
            await revoke(peerID)
        case .revokeAll:
            await pairing.revokeAll(now: Date())
            await refreshPeers()
        }
    }

    func removeContinuation(_ id: UUID) {
        continuations.removeValue(forKey: id)
    }
}
