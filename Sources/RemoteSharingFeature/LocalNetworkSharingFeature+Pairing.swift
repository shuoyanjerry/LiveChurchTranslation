import Foundation
import RemotePairingAPI
import RemoteSharingAPI
import RemoteSharingFeatureAPI

extension LocalNetworkSharingFeature {
    func createInvitation(_ role: LocalSharingInvitationRole) async {
        guard let endpoint else { return }
        guard role == .viewer else { return }
        if invitation?.role == .viewer {
            publishOnState()
            return
        }
        guard !invitationRequestInFlight else { return }
        invitationRequestInFlight = true
        defer { invitationRequestInFlight = false }
        let requestRevision = invitationRevision
        do {
            let issued = try await pairing.issueMacApprovedInvitation(
                role: .viewer,
                now: Date()
            )
            guard requestRevision == invitationRevision, self.endpoint == endpoint else {
                await pairing.revokeInvitation(id: issued.id, now: Date())
                return
            }
            guard let url = issued.fragmentURL(baseURL: endpoint.baseURL) else {
                await pairing.revokeInvitation(id: issued.id, now: Date())
                return
            }
            invitation = LocalSharingInvitation(
                role: .viewer,
                url: url
            )
            publishOnState()
        } catch {
            setState(.failed(message: bounded(error)))
        }
    }

    func revoke(_ peerID: String) async {
        guard let peer = peers.first(where: { $0.id == peerID }),
            let rawID = UUID(uuidString: peer.id)
        else { return }
        await pairing.revoke(grantID: RemoteGrantID(rawValue: rawID), now: Date())
        await refreshPeers()
    }

    func refreshPeers() async {
        let snapshot = await pairing.snapshot(now: Date())
        peers = snapshot.activePeers.map {
            LocalSharingPeer(
                id: $0.grantID.rawValue.uuidString,
                name: String($0.metadata.displayName.prefix(80)),
                role: map($0.role)
            )
        }
        publishOnState()
    }

    func publishOnState() {
        guard let endpoint else { return }
        setState(
            .on(
                endpoint: endpoint.baseURL,
                connectionCount: connectionCount,
                invitation: invitation,
                peers: peers
            )
        )
    }

    func setState(_ state: LocalSharingViewState) {
        currentState = state
        continuations.values.forEach { $0.yield(state) }
    }

    private func map(_ role: RemoteRole) -> LocalSharingPeerRole {
        role == .viewer ? .viewer : .operator
    }

    func bounded(_ error: any Error) -> String {
        String(String(describing: error).prefix(180))
    }
}
